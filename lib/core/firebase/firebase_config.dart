import 'package:firebase_core/firebase_core.dart';

import '../config/env.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'firebase_options_staging.dart' as staging;

/// Picks the Firebase project that matches the current [Env.flavor].
///
/// The three `firebase_options_<flavor>.dart` files are generated with
/// `make firebase-<flavor>` and start out as placeholders, so a fresh clone
/// runs without any Firebase project — see [isConfigured].
abstract final class FirebaseConfig {
  static const String _placeholder = 'REPLACE_ME';

  static FirebaseOptions get currentPlatform => switch (Env.flavor) {
    Flavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
    Flavor.staging => staging.DefaultFirebaseOptions.currentPlatform,
    Flavor.prod => prod.DefaultFirebaseOptions.currentPlatform,
  };

  /// False while the options file for this flavor is still the placeholder.
  static bool get isConfigured => currentPlatform.projectId != _placeholder;

  /// True once [Firebase.initializeApp] has run in this isolate.
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  /// Idempotent — safe to call from `bootstrap` and from background isolates.
  static Future<void> ensureInitialized() async {
    if (!isConfigured || isInitialized) return;
    await Firebase.initializeApp(options: currentPlatform);
  }
}
