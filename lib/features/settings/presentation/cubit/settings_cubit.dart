import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_preferences.dart';

part 'settings_state.dart';

/// Theme & language. Purely local UI preferences, so no domain/data layer.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._prefs) : super(_initialState(_prefs));

  final AppPreferences _prefs;

  static SettingsState _initialState(AppPreferences prefs) {
    final languageCode = prefs.languageCode;
    return SettingsState(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.themeMode,
        orElse: () => ThemeMode.system,
      ),
      locale: languageCode == null ? null : Locale(languageCode),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    await _prefs.setThemeMode(mode.name);
  }

  /// Pass `null` to follow the device language.
  Future<void> setLocale(Locale? locale) async {
    emit(SettingsState(themeMode: state.themeMode, locale: locale));
    await _prefs.setLanguageCode(locale?.languageCode);
  }
}
