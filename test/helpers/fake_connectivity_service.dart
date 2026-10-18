import 'dart:async';

import 'package:codebase_flutter/core/connectivity/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({bool isOnline = true}) : _isOnline = isOnline;

  bool _isOnline;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onStatusChanged => _changes.stream;

  set isOnline(bool value) {
    _isOnline = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
