// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Codebase Flutter';

  @override
  String get login => 'Log in';

  @override
  String get logout => 'Log out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get emailInvalid => 'Invalid email address';

  @override
  String passwordTooShort(int min) {
    return 'Password must be at least $min characters';
  }

  @override
  String get invalidCredentials => 'Incorrect email or password';

  @override
  String demoAccountHint(String email, String password) {
    return 'Demo account: $email / $password';
  }

  @override
  String welcome(String name) {
    return 'Hello, $name!';
  }

  @override
  String get settings => 'Settings';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get retry => 'Retry';

  @override
  String get errorNetwork => 'No internet connection. Please try again.';

  @override
  String get errorTimeout => 'The request timed out. Please try again.';

  @override
  String get errorServer => 'Something went wrong on the server.';

  @override
  String get errorUnauthorized =>
      'Your session has expired. Please log in again.';

  @override
  String get offlineBanner => 'No internet connection';

  @override
  String get errorUnknown => 'An unexpected error occurred.';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of the app is no longer supported. Please update to continue.';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableBody =>
      'A newer version with improvements is ready.';

  @override
  String get updateNow => 'Update now';

  @override
  String get later => 'Later';
}
