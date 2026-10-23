import 'app_version.dart';

enum UpdateRequirement {
  /// Up to date (or versions unknown — never block on missing data).
  none,

  /// A newer build exists; show a dismissible prompt.
  optional,

  /// Below the minimum supported version; block the app.
  required,
}

abstract final class UpdatePolicy {
  static UpdateRequirement evaluate({
    required AppVersion? current,
    required AppVersion? minSupported,
    required AppVersion? latest,
  }) {
    if (current == null) return UpdateRequirement.none;
    if (minSupported != null && current < minSupported) {
      return UpdateRequirement.required;
    }
    if (latest != null && current < latest) return UpdateRequirement.optional;
    return UpdateRequirement.none;
  }
}
