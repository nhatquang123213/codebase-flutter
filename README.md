# codebase_flutter

Flutter base codebase

## Getting started

```sh
make setup          # pub get, git hooks, l10n
make run-dev        # or run-staging / run-prod, or the VS Code launch configs
make check          # format + analyze + test (what CI runs)
make feature name=orders   # scaffold a new feature
```

Everything runs without a backend when `USE_MOCK_API=true` (default in `env/dev.json`;
sign in with `demo@example.com` / `123456`) and without a Firebase project until you run
`make firebase-<flavor>`.

Layout: `lib/core` (shared infrastructure: network, DI, events, config, …), `lib/features/<name>`
(one folder per feature: `data` / `domain` / `presentation` + `<name>_injection.dart`), `lib/app`
(root widget, router, bootstrap).

## Development workflow

* **Git hooks** (`make hooks`, included in `make setup`): `pre-commit` checks formatting of staged Dart files
  and runs the analyzer; `pre-push` runs the tests. Skip once with `git commit --no-verify`.
* **CI** (`.github/workflows/ci.yml`) on every PR and push to `main`: `make check` plus a check that
  generated code (`*.g.dart`, l10n) is committed, a scaffold smoke test, a dev debug APK (uploaded as
  an artifact) and an iOS dev build without codesigning. The iOS job runs on macOS runners, which are
  10× the price of Linux minutes on private repos — drop it or gate it on `main` if that matters.
* **Dependabot** opens weekly pub PRs (Firebase packages grouped) and monthly ones for GitHub Actions
  and Gradle.

## Adding a feature

```sh
make feature name=orders              # entity defaults to the singular: Order
make feature name=order_items entity=order_item
```

This creates `lib/features/orders/` with the full data / domain / presentation stack for a list screen
(entity, `json_serializable` model, remote + mock data sources, repository, use case, cubit, page,
injection) and two tests, then wires it in: `ApiEndpoints.orders`, `AppRoutes.orders`, a `GoRoute`,
`registerOrdersDependencies(getIt)` and an `ordersTitle` l10n key (translate it in `app_vi.arb`).
Finally it runs `make gen l10n`. The result passes `make check` as-is; CI re-verifies that on every
PR so the generator cannot rot.

The templates live in `tool/scaffold_feature.dart`. Change them when the conventions change.

## Remote config & feature flags

`RemoteConfigService` (`lib/core/config/remote_config.dart`) wraps Firebase Remote Config: defaults are
applied and last session's values activated synchronously at startup, then a fetch runs in the
background and realtime updates are activated as they arrive. `onUpdated` fires after each activation.
Without Firebase, `InMemoryRemoteConfigService` serves `RemoteConfigKeys.defaults` (it is also the test
double: `config.update({...})`).

Debug builds fetch on every launch; release builds use a 1 hour minimum interval.

Flags are read through `FeatureFlags` so call sites never spell raw keys:

```dart
if (getIt<FeatureFlags>().exampleFeature) ...
```

Add a key to `RemoteConfigKeys` (+ default), a getter to `FeatureFlags`, and the parameter in the
Firebase console.

## Force update

`features/app_update` compares the running version (`package_info_plus`) with two remote config keys:

| Key | Effect when the app is older |
|---|---|
| `min_supported_version` | **Blocks** the app with `ForceUpdatePage` |
| `latest_version` | Shows a dismissible "update available" strip |

`store_url_android` / `store_url_ios` feed the "Update now" button. `UpdateGate` is installed through
`MaterialApp.builder`, and `AppUpdateCubit` re-evaluates on every remote config update, so a bad
release can be blocked for running apps within minutes without a restart. Unknown or unparsable
versions never block.

## Analytics

`Analytics` (`lib/core/analytics/analytics.dart`) is the only thing features talk to;
`FirebaseAnalyticsService` implements it when Firebase is configured, `NoopAnalytics` logs to the
console otherwise. Collection is disabled in debug builds.

* `AnalyticsRouteObserver` logs a screen view per go_router page (named after the path). A
  `ShellRoute` has its own navigator and needs its own observer instance.
* The signed-in user id is set together with Crashlytics in `App`.
* `LoginCubit` logs `login` on success — copy that pattern: inject `Analytics`, call it where the
  business event happens, name events in `AnalyticsEvents`.

## Flavors

| Flavor | Android applicationId | iOS bundle id | App name | Dart config |
|---|---|---|---|---|
| dev | `com.codebase.codebase_flutter.dev` | `com.codebase.codebaseFlutter.dev` | Codebase Dev | `env/dev.json` |
| staging | `com.codebase.codebase_flutter.staging` | `com.codebase.codebaseFlutter.staging` | Codebase Staging | `env/staging.json` |
| prod | `com.codebase.codebase_flutter` | `com.codebase.codebaseFlutter` | Codebase Flutter | `env/prod.json` |

A flavor is two switches that must be flipped together: `--flavor <name>` (native app id, name, icon)
and `--dart-define-from-file=env/<name>.json` (`Env`). Use `make run-<flavor>` or the VS Code
launch configs; `bootstrap` asserts in debug that both agree.

* **Android**: `productFlavors` in `android/app/build.gradle.kts`. Per-flavor resources go in
  `android/app/src/<flavor>/res/` (e.g. a different launcher icon).
* **iOS**: build configurations `Debug|Profile|Release-<flavor>` and schemes `dev`, `staging`, `prod`.
  Per-flavor values live in `ios/Flutter/Flavors/<flavor>.xcconfig`; the plain `Runner` scheme
  behaves like dev. To add a setting that differs per flavor, add it to those three files and reference
  it from `Info.plist` as `$(NAME)`.
* **Adding a flavor**: add `env/<name>.json`, a `productFlavor`, a `Flavors/<name>.xcconfig`, three
  `ios/Flutter/<Config>-<name>.xcconfig` files, duplicate the build configurations + scheme in Xcode,
  add the configurations to `ios/Podfile`, and extend `Flavor` + `FirebaseConfig`.

## Crash reporting (Crashlytics)

`AppLogger.error` forwards to `AppLogger.reporter` (`CrashReporter`). With Firebase configured it is
`CrashlyticsReporter`, otherwise a no-op. Flutter framework errors and uncaught async errors are
recorded as fatal in `bootstrap`; the signed-in user id is attached in `App`. Collection is disabled
in debug builds.

Release builds are obfuscated, so upload Dart symbols after each build:

```sh
make apk-prod && make crashlytics-symbols-prod FIREBASE_ANDROID_APP_ID_PROD=1:…:android:… FIREBASE_IOS_APP_ID_PROD=1:…:ios:…
```

Native crash symbolication (NDK / dSYM) additionally needs the Crashlytics Gradle plugin and the Xcode
run script from the [Crashlytics docs](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter);
both require the `google-services.json` / `GoogleService-Info.plist` that `flutterfire configure` writes.

## Code generation

Data models use `json_serializable` (`build.yaml`: snake_case fields, `checked: true`). After editing a
model:

```sh
make gen      # one-off
make watch    # while developing
```

Generated `*.g.dart` files are committed and excluded from analysis. Entities and bloc states stay
hand-written `Equatable` classes; add `freezed` if unions / `copyWith` become common.

## Event bus

`AppEventBus` (`core/events`) is in-process pub/sub for facts that cross feature boundaries.
Core events: `SessionExpired` (fired by `AuthInterceptor`, handled by `AuthBloc`),
`ConnectivityChanged`, `RealtimeMessageReceived`. A feature declares its own events next to the
code that fires them:

```dart
final class OrderUpdated extends AppEvent { const OrderUpdated(this.id); final String id; }

eventBus.fire(OrderUpdated('42'));                       // producer
_sub = eventBus.on<OrderUpdated>().listen(...);          // consumer (cancel in close())
```

Rules of thumb: a bloc renders state, the bus announces facts, constructor injection expresses a
real dependency. Don't use the bus as a command channel.

## Connectivity

`ConnectivityService` (`core/connectivity`, backed by `connectivity_plus`) answers "is any network
interface up". It feeds three things:

* `ConnectivityInterceptor` — first interceptor on both Dio clients; fails fast with
  `NetworkFailure` instead of waiting for the connect timeout.
* `ConnectivityCubit` + `OfflineBanner` — the banner is installed once via `MaterialApp.builder`;
  pages can `context.watch<ConnectivityCubit>().state` to disable actions offline.
* `ConnectivityChanged` on the event bus — the realtime client uses it to reconnect immediately.

"Online" does not guarantee the backend is reachable; requests can still fail with `NetworkFailure`.

## Realtime (WebSocket)

`core/realtime` keeps one authenticated WebSocket open while the user is signed in.

| Piece | Role |
|---|---|
| `RealtimeTransport` / `WebSocketTransport` | Raw socket (`web_socket_channel`), swappable for tests |
| `WebSocketRealtimeClient` | Bearer token header, exponential backoff with jitter (1 s → 30 s), heartbeat ping every 30 s, reconnect after two silent intervals, `retryNow()` |
| `RealtimeSession` | Connects on login, disconnects on logout, retries on connectivity restored / app resumed |
| `RealtimeMessageReceived` | Every decoded frame, published on the event bus |

Wire format is `{"type": "order.updated", "data": {...}}`; the client answers nothing but `ping`,
the server should reply `{"type": "pong"}`. `WS_URL` comes from `env/<flavor>.json`; with
`USE_MOCK_API=true` a no-op client is used.

Features consume messages without touching the socket:

```dart
eventBus.on<RealtimeMessageReceived>()
    .where((e) => e.message.type == 'order.updated')
    .listen((e) => add(OrderRefreshed(e.message.data['id'] as String)));
```

Backend contract: accept `Authorization: Bearer <access token>` on the upgrade request and close the
socket when the token is no longer valid; the client reconnects with whatever token is currently
stored, so a refresh triggered by regular HTTP traffic is picked up automatically. If you need
rooms/acks/Socket.IO semantics, replace `WebSocketTransport`, the rest stays.

## Push notifications (Firebase Cloud Messaging)

The app boots without any Firebase project: the files in `lib/core/firebase/firebase_options_<flavor>.dart`
are placeholders, and while they are, `FirebaseConfig.isConfigured` is false and push is a no-op.

### One-time setup

1. `dart pub global activate flutterfire_cli && firebase login`
2. Create one Firebase project per flavor (dev / staging / prod) and run, for each:
   ```sh
   make firebase-dev FIREBASE_PROJECT_DEV=<project-id>
   make firebase-staging FIREBASE_PROJECT_STAGING=<project-id>
   make firebase-prod FIREBASE_PROJECT_PROD=<project-id>
   ```
   This regenerates the matching `firebase_options_<flavor>.dart`. `google-services.json` /
   `GoogleService-Info.plist` are git-ignored and **not needed** — options are passed explicitly
   in `FirebaseConfig.ensureInitialized()`. If the CLI adds the `com.google.gms.google-services`
   Gradle plugin, you can remove it again.
3. iOS: upload your APNs key in Firebase console → Project settings → Cloud Messaging, and make sure
   the *Push Notifications* capability is on for the Runner target (`ios/Runner/Runner.entitlements`).

### How it works

| Piece | Where | Role |
|---|---|---|
| `FirebaseConfig` | `core/firebase` | Picks options by `Env.flavor`, initialises Firebase once |
| `PushNotificationService` | `core/notifications` | FCM wrapper (permission, token, message streams) |
| `LocalNotificationService` | `core/notifications` | Shows foreground messages as system notifications, Android channel `high_importance` |
| `NotificationHandler` | `core/notifications` | Merges FCM + local taps into one `onTap` stream |
| `firebaseMessagingBackgroundHandler` | `core/notifications` | Background isolate entry point for data-only messages |
| `PushTokenSync` | `features/notifications` | Sends the token to `POST /devices/tokens` on login / refresh, deletes it on logout |
| `App` | `app/app.dart` | Starts the above and navigates on tap |

### Deep links

Put a GoRouter location in the FCM `data` map under the key `route`:

```json
{ "notification": { "title": "Order shipped", "body": "…" }, "data": { "route": "/orders/42" } }
```

`App._onNotificationTap` calls `router.go(route)` when the user is signed in. Any other `data` keys
are available on `NotificationPayload.data`.

### Backend contract

`POST /devices/tokens` with `{ "token": "<fcm token>", "platform": "android" | "ios" }`, authenticated.
Store one row per token; drop tokens when FCM reports them as `UNREGISTERED`. The app deletes its token
locally on logout, so the next login registers a fresh one.
