part of 'settings_cubit.dart';

final class SettingsState extends Equatable {
  const SettingsState({this.themeMode = ThemeMode.system, this.locale});

  final ThemeMode themeMode;

  /// `null` = follow the device language.
  final Locale? locale;

  SettingsState copyWith({ThemeMode? themeMode}) =>
      SettingsState(themeMode: themeMode ?? this.themeMode, locale: locale);

  @override
  List<Object?> get props => [themeMode, locale];
}
