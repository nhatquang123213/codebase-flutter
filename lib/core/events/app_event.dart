/// Base type for everything that travels on [AppEventBus].
///
/// Events are facts ("session expired"), not commands ("log out"); the
/// listener decides what to do. Core events live in `app_events.dart`;
/// a feature declares its own events next to the code that fires them.
abstract class AppEvent {
  const AppEvent();

  @override
  String toString() => runtimeType.toString();
}
