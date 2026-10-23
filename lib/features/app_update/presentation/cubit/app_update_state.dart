part of 'app_update_cubit.dart';

final class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.requirement = UpdateRequirement.none,
    this.latestVersion,
    this.storeUrl,
    this.dismissed = false,
  });

  final UpdateRequirement requirement;
  final AppVersion? latestVersion;

  /// Store page for this platform; null when not configured.
  final Uri? storeUrl;
  final bool dismissed;

  bool get isBlocking => requirement == UpdateRequirement.required;

  bool get showsPrompt =>
      requirement == UpdateRequirement.optional && !dismissed;

  AppUpdateState copyWith({bool? dismissed}) => AppUpdateState(
    requirement: requirement,
    latestVersion: latestVersion,
    storeUrl: storeUrl,
    dismissed: dismissed ?? this.dismissed,
  );

  @override
  List<Object?> get props => [requirement, latestVersion, storeUrl, dismissed];
}
