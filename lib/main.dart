import 'app/app.dart';
import 'app/bootstrap.dart';

/// Run with an environment file, e.g.
/// `flutter run --dart-define-from-file=env/dev.json` (or `make run-dev`).
Future<void> main() => bootstrap(App.new);
