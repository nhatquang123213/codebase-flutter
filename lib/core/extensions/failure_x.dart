import '../../l10n/app_localizations.dart';
import '../error/failure.dart';

extension FailureMessageX on Failure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    ServerFailure() => l10n.errorServer,
    CacheFailure() || UnknownFailure() => l10n.errorUnknown,
  };
}
