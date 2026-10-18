import 'package:codebase_flutter/core/notifications/notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payload = NotificationPayload(
    id: 'm1',
    title: 'Hi',
    body: 'There',
    data: {'route': '/orders/42', 'orderId': '42'},
  );

  test('route comes from the data map', () {
    expect(payload.route, '/orders/42');
    expect(const NotificationPayload(data: {'route': ''}).route, isNull);
    expect(const NotificationPayload().route, isNull);
  });

  test('encode/decode round-trips', () {
    expect(NotificationPayload.decode(payload.encode()), payload);
  });

  test('decode tolerates garbage', () {
    expect(NotificationPayload.decode(null), isNull);
    expect(NotificationPayload.decode(''), isNull);
    expect(NotificationPayload.decode('not json'), isNull);
    expect(NotificationPayload.decode('[1,2]'), isNull);
  });

  test('fromJson stringifies non-string data values', () {
    final decoded = NotificationPayload.fromJson({
      'data': {'count': 3, 'flag': true},
    });
    expect(decoded.data, {'count': '3', 'flag': 'true'});
  });
}
