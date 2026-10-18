import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Platform-agnostic view of a push / local notification.
///
/// The backend puts navigation info in the FCM `data` map; the only key the
/// app relies on is [routeKey] (a GoRouter location such as `/orders/42`).
/// Everything else in [data] is passed through untouched for the feature
/// that handles the tap.
final class NotificationPayload extends Equatable {
  const NotificationPayload({
    this.id,
    this.title,
    this.body,
    this.data = const {},
  });

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      NotificationPayload(
        id: json['id'] as String?,
        title: json['title'] as String?,
        body: json['body'] as String?,
        data: (json['data'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );

  /// Decodes the string that [encode] produced. Returns null on garbage, so a
  /// malformed local-notification payload can never crash the tap handler.
  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return NotificationPayload.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static const String routeKey = 'route';

  /// FCM message id (or any unique id) used to de-duplicate on the device.
  final String? id;
  final String? title;
  final String? body;
  final Map<String, String> data;

  String? get route {
    final value = data[routeKey];
    return value == null || value.isEmpty ? null : value;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'data': data,
  };

  String encode() => jsonEncode(toJson());

  @override
  List<Object?> get props => [id, title, body, data];
}
