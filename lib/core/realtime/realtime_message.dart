import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Wire format shared with the backend: `{"type": "order.updated", "data": {...}}`.
final class RealtimeMessage extends Equatable {
  const RealtimeMessage({required this.type, this.data = const {}});

  factory RealtimeMessage.fromJson(Map<String, dynamic> json) =>
      RealtimeMessage(
        type: json['type'] as String,
        data: json['data'] as Map<String, dynamic>? ?? const {},
      );

  /// Returns null for anything that is not a `{type: String, ...}` object,
  /// so a bad frame from the server can never take the connection down.
  static RealtimeMessage? decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['type'] is! String) {
        return null;
      }
      return RealtimeMessage.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  static const RealtimeMessage ping = RealtimeMessage(type: 'ping');
  static const String pongType = 'pong';

  final String type;
  final Map<String, dynamic> data;

  String encode() => jsonEncode({'type': type, 'data': data});

  @override
  List<Object?> get props => [type, data];
}
