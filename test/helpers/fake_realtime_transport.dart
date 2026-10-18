import 'dart:async';

import 'package:codebase_flutter/core/realtime/realtime_transport.dart';

/// Scriptable transport: each `connect` either fails (while [failNext] > 0)
/// or hands out a [FakeRealtimeConnection] the test can drive.
class FakeRealtimeTransport implements RealtimeTransport {
  int failNext = 0;
  final List<Map<String, String>> headers = [];
  final List<FakeRealtimeConnection> connections = [];

  int get connectCalls => headers.length;

  FakeRealtimeConnection get last => connections.last;

  @override
  Future<RealtimeConnection> connect(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    this.headers.add(headers);
    if (failNext > 0) {
      failNext--;
      throw const SocketException('refused');
    }
    final connection = FakeRealtimeConnection();
    connections.add(connection);
    return connection;
  }
}

class SocketException implements Exception {
  const SocketException(this.message);

  final String message;
}

class FakeRealtimeConnection implements RealtimeConnection {
  final StreamController<String> _incoming = StreamController<String>();
  final List<String> sent = [];
  bool closed = false;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String data) => sent.add(data);

  @override
  Future<void> close() async {
    closed = true;
    // Not awaited: a controller's close() only completes once a listener
    // receives the done event, and the client has already unsubscribed.
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }

  /// Server pushes a frame.
  void receive(String frame) => _incoming.add(frame);

  /// Server drops the connection.
  Future<void> drop() => _incoming.close();
}
