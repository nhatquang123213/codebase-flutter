enum Flavor { dev, staging, prod }

/// Compile-time configuration injected with `--dart-define-from-file=env/<flavor>.json`.
///
/// Values here are embedded in the app binary, so never put secrets in `env/*.json`.
abstract final class Env {
  static const String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://dev-api.example.com',
  );

  /// WebSocket endpoint for realtime messages (see `core/realtime`).
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://dev-api.example.com/ws',
  );

  /// When true, data sources return fake data so the app runs without a backend.
  static const bool useMockApi = bool.fromEnvironment('USE_MOCK_API');

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static Flavor get flavor => Flavor.values.firstWhere(
    (f) => f.name == _flavor,
    orElse: () => Flavor.dev,
  );

  static bool get isProd => flavor == Flavor.prod;

  /// `--flavor` (native app id / name) and `--dart-define-from-file`
  /// (this class) are two switches; make sure they were flipped together.
  static bool matchesNativeFlavor(String? nativeFlavor) =>
      nativeFlavor == null || nativeFlavor == flavor.name;
}
