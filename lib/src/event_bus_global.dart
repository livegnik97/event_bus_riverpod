import 'package:event_bus_riverpod/src/bus_metadata.dart';
import 'package:event_bus_riverpod/src/event_bus_action_for_global.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:event_bus_riverpod/src/event_bus_singleton.dart';
import 'package:event_bus_riverpod/src/listener_disposable.dart';
import 'package:event_bus_riverpod/src/sub_event_identifier.dart';

/// Static API to interact with the global event bus from anywhere,
/// without requiring a Riverpod [Ref] or [WidgetRef].
///
/// Internally uses [EventBusSingleton] so the bus is shared with
/// the Riverpod provider-based API.
///
/// ```dart
/// // Listen
/// final d = EventBusGlobal.event(onCounter).listenManually((v) => print(v));
///
/// // Emit
/// EventBusGlobal.event(onCounter).emit(42);
///
/// // SubEvent
/// EventBusGlobal.subEvent(onHighCount).listenManually((v) => print(v));
/// ```
class EventBusGlobal {
  EventBusGlobal._();

  /// Returns a typed action for the given [event].
  static EventBusActionForGlobal<T> event<T>(EventBusIdentifier<T> event) =>
      EventBusActionForGlobal<T>(event: event);

  /// Returns a typed subEvent action for the given [id].
  static SubEventActionForGlobal<T> subEvent<T>(SubEventIdentifier<T> id) =>
      SubEventActionForGlobal<T>(identifier: id);

  /// Clears all event bus state: listeners, sticky caches, middlewares,
  /// and subEvents for every event.
  static void clearAll() => EventBusSingleton.getInstance().core.clearAll();

  /// Registers a global log callback that fires for every event emission
  /// before middlewares are applied.
  ///
  /// The callback receives a [LogEntry] with the event name, value, and
  /// metadata. Returns a [ListenerDisposable] to unregister the logger.
  ///
  /// ```dart
  /// final disposable = EventBusGlobal.logEvents((entry) {
  ///   log('[${entry.eventName}] ${entry.value}');
  /// });
  /// // later:
  /// disposable.dispose();
  /// ```
  static ListenerDisposable logEvents(
    void Function(LogEntry<Object?> entry) callback,
  ) {
    final bus = EventBusSingleton.getInstance().core;
    bus.setLogCallback(callback);
    return ListenerDisposable(() => bus.removeLogCallback(callback));
  }
}
