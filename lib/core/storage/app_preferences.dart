import 'package:shared_preferences/shared_preferences.dart';

/// Keys are enum values, so two settings can never share a key by accident.
enum _PrefKey { themeMode, languageCode }

/// Non-sensitive user preferences. Tokens belong in [TokenStorage].
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  String? get themeMode => _prefs.getString(_PrefKey.themeMode.name);

  Future<void> setThemeMode(String value) =>
      _prefs.setString(_PrefKey.themeMode.name, value);

  String? get languageCode => _prefs.getString(_PrefKey.languageCode.name);

  Future<void> setLanguageCode(String? value) => value == null
      ? _prefs.remove(_PrefKey.languageCode.name)
      : _prefs.setString(_PrefKey.languageCode.name, value);
}
