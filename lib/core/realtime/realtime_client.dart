import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

import '../events/app_events.dart';
import '../events/event_bus.dart';
import '../utils/app_logger.dart';
import 'realtime_message.dart';
import 'realtime_transport.dart';

enum RealtimeStatus { disconnected, connecting, connected, reconnecting }

/// Long-lived server → app channel. Features don't talk to it directly:
/// they listen for `RealtimeMessageReceived` on the event bus.
abstract interface class RealtimeClient {
  RealtimeStatus get status;

  Stream<RealtimeStatus> get onStatusChanged;

  /// Keep the connection up (with automatic reconnects) until [disconnect].
  Future<void> connect();

  Future<void> disconnect();

  /// Skip the current backoff delay (connectivity restored, app resumed).
  void retryNow();

  /// Dropped silently when not connected; realtime is not a reliable queue.
  void send(RealtimeMessage message);
}

class RealtimeBackoff {
  const RealtimeBackoff({
    this.initial = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.jitter = const Duration(milliseconds: 500),
  });

  final Duration initial;
  final Duration max;
  final Duration jitter;

  Duration delayFor(int attempt, Random random) {
    final exponential = initial * pow(2, attempt).toInt();
    final capped = exponential > max ? max : exponential;
    final jitterMs = jitter.inMilliseconds == 0
        ? 0
        : random.nextInt(jitter.inMilliseconds);
    return capped + Duration(milliseconds: jitterMs);
  }
}

class WebSocketRealtimeClient implements RealtimeClient {
  WebSocketRealtimeClient({
    required RealtimeTransport transport,
    required Uri uri,
    required Future<String?> Function() tokenProvider,
    required AppEventBus eventBus,
    this.backoff = const RealtimeBackoff(),
    this.heartbeatInterval = const Duration(seconds: 30),
    Random? random,
  }) : _transport = transport,
       _uri = uri,
       _tokenProvider = tokenProvider,
       _eventBus = eventBus,
       _random = random ?? Random();

  final RealtimeTransport _transport;
  final Uri _uri;
  final Future<String?> Function() _tokenProvider;
  final AppEventBus _eventBus;
  final RealtimeBackoff backoff;

  /// A ping is sent every interval; no inbound frame for two intervals
  /// means the socket is dead even if the OS hasn't noticed.
  final Duration heartbeatInterval;
  final Random _random;

  final StreamController<RealtimeStatus> _statusController =
      StreamController<RealtimeStatus>.broadcast();
  RealtimeStatus _status = RealtimeStatus.disconnected;
  bool _wantConnected = false;
  int _attempt = 0;
  RealtimeConnection? _connection;
  // ignore: cancel_subscriptions — cancelled in _teardown()
  StreamSubscription<String>? _messages;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  DateTime _lastInbound = clock.now();

  @override
  RealtimeStatus get status => _status;

  @override
  Stream<RealtimeStatus> get onStatusChanged => _statusController.stream;

  @override
  Future<void> connect() async {
    if (_wantConnected) return;
    _wantConnected = true;
    _attempt = 0;
    await _open();
  }

  @override
  Future<void> disconnect() async {
    _wantConnected = false;
    _reconnectTimer?.cancel();
    await _teardown();
    _setStatus(RealtimeStatus.disconnected);
  }

  @override
  void retryNow() {
    if (!_wantConnected || _reconnectTimer == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    unawaited(_open());
  }

  @override
  void send(RealtimeMessage message) => _connection?.send(message.encode());

  Future<void> _open() async {
    if (!_wantConnected || _connection != null) return;
    _setStatus(
      _attempt == 0 ? RealtimeStatus.connecting : RealtimeStatus.reconnecting,
    );
    try {
      final token = await _tokenProvider();
      final connection = await _transport.connect(
        _uri,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (!_wantConnected) {
        await connection.close();
        return;
      }
      _connection = connection;
      _attempt = 0;
      _lastInbound = clock.now();
      _messages = connection.messages.listen(
        _onFrame,
        onError: (Object e) => _onDropped('error: $e'),
        onDone: () => _onDropped('closed by server'),
      );
      _startHeartbeat();
      _setStatus(RealtimeStatus.connected);
    } catch (e) {
      AppLogger.warning('Realtime connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onFrame(String raw) {
    _lastInbound = clock.now();
    final message = RealtimeMessage.decode(raw);
    if (message == null) {
      AppLogger.warning('Realtime: dropped malformed frame');
      return;
    }
    if (message.type == RealtimeMessage.pongType) return;
    _eventBus.fire(RealtimeMessageReceived(message));
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      final silence = clock.now().difference(_lastInbound);
      if (silence > heartbeatInterval * 2) {
        _onDropped('heartbeat timeout');
        return;
      }
      send(RealtimeMessage.ping);
    });
  }

  void _onDropped(String reason) {
    if (_connection == null) return;
    AppLogger.info('Realtime disconnected ($reason)');
    unawaited(_teardown());
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wantConnected || _reconnectTimer != null) return;
    final delay = backoff.delayFor(_attempt, _random);
    _attempt++;
    _setStatus(RealtimeStatus.reconnecting);
    AppLogger.debug(
      'Realtime reconnect #$_attempt in ${delay.inMilliseconds}ms',
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_open());
    });
  }

  Future<void> _teardown() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final connection = _connection;
    final messages = _messages;
    _connection = null;
    _messages = null;
    // Not awaited: nothing depends on it and the future may never settle
    // under fake_async.
    unawaited(messages?.cancel());
    try {
      await connection?.close();
    } catch (_) {
      // Already closed by the peer.
    }
  }

  void _setStatus(RealtimeStatus value) {
    if (value == _status) return;
    _status = value;
    if (!_statusController.isClosed) _statusController.add(value);
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
  }
}

/// Used with `USE_MOCK_API=true`: reports "connected" and never emits.
class NoopRealtimeClient implements RealtimeClient {
  const NoopRealtimeClient();

  @override
  RealtimeStatus get status => RealtimeStatus.connected;

  @override
  Stream<RealtimeStatus> get onStatusChanged => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void retryNow() {}

  @override
  void send(RealtimeMessage message) {}
}
