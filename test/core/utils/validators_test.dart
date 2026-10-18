import 'package:codebase_flutter/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.isValidEmail', () {
    test('accepts valid emails', () {
      expect(Validators.isValidEmail('a@b.com'), isTrue);
      expect(Validators.isValidEmail(' user.name+tag@mail.co.vn '), isTrue);
    });

    test('rejects invalid emails', () {
      for (final email in ['', 'abc', 'a@', '@b.com', 'a@b', 'a b@c.com']) {
        expect(Validators.isValidEmail(email), isFalse, reason: email);
      }
    });
  });

  test('Validators.isValidPassword checks minimum length', () {
    expect(Validators.isValidPassword('12345'), isFalse);
    expect(Validators.isValidPassword('123456'), isTrue);
  });
}
