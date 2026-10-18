import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

/// The raw socket, kept behind an interface so [RealtimeClient]'s reconnect
/// logic is testable without a server.
abstract interface class RealtimeTransport {
  /// Resolves once the connection is open; throws if the handshake fails.
  Future<RealtimeConnection> connect(Uri uri, {Map<String, String> headers});
}

abstract interface class RealtimeConnection {
  /// Text frames. Closes (or errors) when the connection drops.
  Stream<String> get messages;

  void send(String data);

  Future<void> close();
}

class WebSocketTransport implements RealtimeTransport {
  const WebSocketTransport({this.connectTimeout = const Duration(seconds: 10)});

  final Duration connectTimeout;

  @override
  Future<RealtimeConnection> connect(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: headers,
      connectTimeout: connectTimeout,
    );
    await channel.ready;
    return _WebSocketConnection(channel);
  }
}

class _WebSocketConnection implements RealtimeConnection {
  _WebSocketConnection(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Stream<String> get messages => _channel.stream.map(
    (frame) => frame is String ? frame : utf8.decode(frame as List<int>),
  );

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  Future<void> close() => _channel.sink.close(status.normalClosure);
}
