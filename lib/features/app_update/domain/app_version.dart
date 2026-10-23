import 'package:equatable/equatable.dart';

/// `major.minor.patch` as found in pubspec `version:` and remote config.
/// Build metadata (`+42`) and pre-release tags (`-beta`) are ignored.
final class AppVersion extends Equatable implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final RegExp _pattern = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?');

  /// Returns null for anything that does not start with a number.
  static AppVersion? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    int part(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
    return AppVersion(part(1), part(2), part(3));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  List<Object?> get props => [major, minor, patch];

  @override
  String toString() => '$major.$minor.$patch';
}
