import 'package:codebase_flutter/features/app_update/domain/app_version.dart';
import 'package:codebase_flutter/features/app_update/domain/update_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses pubspec-style versions and ignores build/pre-release', () {
      expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('1.2.3+45'), const AppVersion(1, 2, 3));
      expect(AppVersion.tryParse('2.0.0-beta.1'), const AppVersion(2, 0, 0));
      expect(AppVersion.tryParse('v1.4'), const AppVersion(1, 4, 0));
      expect(AppVersion.tryParse(' 3 '), const AppVersion(3, 0, 0));
    });

    test('returns null for garbage', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
    });
  });

  test('compares numerically, not lexically', () {
    expect(const AppVersion(1, 10, 0) < const AppVersion(1, 9, 0), isFalse);
    expect(const AppVersion(1, 9, 0) < const AppVersion(1, 10, 0), isTrue);
    expect(const AppVersion(2, 0, 0) >= const AppVersion(1, 99, 99), isTrue);
  });

  group('UpdatePolicy.evaluate', () {
    const current = AppVersion(1, 2, 0);

    test('required when below minimum', () {
      expect(
        UpdatePolicy.evaluate(
          current: current,
          minSupported: const AppVersion(1, 3, 0),
          latest: const AppVersion(1, 5, 0),
        ),
        UpdateRequirement.required,
      );
    });

    test('optional when below latest but at/above minimum', () {
      expect(
        UpdatePolicy.evaluate(
          current: current,
          minSupported: const AppVersion(1, 0, 0),
          latest: const AppVersion(1, 5, 0),
        ),
        UpdateRequirement.optional,
      );
    });

    test('none when up to date or when versions are unknown', () {
      expect(
        UpdatePolicy.evaluate(
          current: current,
          minSupported: const AppVersion(1, 0, 0),
          latest: current,
        ),
        UpdateRequirement.none,
      );
      expect(
        UpdatePolicy.evaluate(current: null, minSupported: null, latest: null),
        UpdateRequirement.none,
      );
      expect(
        UpdatePolicy.evaluate(
          current: current,
          minSupported: null,
          latest: null,
        ),
        UpdateRequirement.none,
      );
    });
  });
}
