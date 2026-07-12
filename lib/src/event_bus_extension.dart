import 'package:event_bus_riverpod/src/bus_metadata.dart';
import 'package:event_bus_riverpod/src/event_bus_action.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';
import 'package:event_bus_riverpod/src/listener_disposable.dart';
import 'package:event_bus_riverpod/src/sub_event_action.dart';
import 'package:event_bus_riverpod/src/sub_event_identifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extends [Ref] with the [event] method to interact with the event bus.
///
/// ```dart
/// // Define an event identifier
/// final loginEvent = EventBusIdentifier<User>('userLogin');
///
/// // Inside a Riverpod provider
/// ref.event(loginEvent).listen((user) {
///   print('User logged in: ${user.name}');
/// });
///
/// // Inside an another Riverpod provider or consumer widget
/// ref.event(loginEvent).emit(User(name: 'Alice'));
/// ```
extension EventBusForRef on Ref {
  EventBusActionForRef<T> event<T>(EventBusIdentifier<T> event) =>
      EventBusActionForRef<T>(event: event, ref: this);

  SubEventActionForRef<T> subEvent<T>(SubEventIdentifier<T> id) =>
      SubEventActionForRef<T>(identifier: id, ref: this);

  /// Clears all event bus state: listeners, sticky caches, middlewares,
  /// and subEvents for every event.
  void clearAllEvents() => read(eventBusProvider).clearAll();

  /// Registers a global log callback that fires for every event emission
  /// before middlewares are applied.
  ///
  /// The callback receives a [LogEntry] with the event name, value, and
  /// metadata. The logger is automatically disposed via [ref.onDispose].
  ///
  /// ```dart
  /// ref.logEvents((entry) {
  ///   log('[${entry.eventName}] ${entry.value}');
  /// });
  /// ```
  ListenerDisposable logEvents(
    void Function(LogEntry<Object?> entry) callback,
  ) {
    final bus = read(eventBusProvider);
    bus.setLogCallback(callback);
    onDispose(() => bus.setLogCallback(null));
    return ListenerDisposable(() => bus.setLogCallback(null));
  }
}

/// Extends [WidgetRef] with the [event] method to interact with the event bus.
///
/// Note: [WidgetRef] does not expose `onDispose`, so auto-disposal is not
/// available. Use [EventBusActionForWidgetRef.listenManually] instead.
///
/// ```dart
/// // Define an event identifier
/// final logoutEvent = EventBusIdentifier<void>('userLogout');
///
/// // Inside a widget
/// final disposable = ref.event(logoutEvent).listenManually((_) {
///   print('User logged out');
/// });
///
/// // Dispose when no longer needed
/// disposable.dispose();
///
/// ref.event(logoutEvent).emit(null);
/// ```
extension EventBusForWidgetRef on WidgetRef {
  EventBusActionForWidgetRef<T> event<T>(EventBusIdentifier<T> event) =>
      EventBusActionForWidgetRef<T>(event: event, ref: this);

  SubEventActionForWidgetRef<T> subEvent<T>(SubEventIdentifier<T> id) =>
      SubEventActionForWidgetRef<T>(identifier: id, ref: this);

  /// Clears all event bus state: listeners, sticky caches, middlewares,
  /// and subEvents for every event.
  void clearAllEvents() => read(eventBusProvider).clearAll();

  /// Registers a global log callback that fires for every event emission
  /// before middlewares are applied.
  ///
  /// The callback receives a [LogEntry] with the event name, value, and
  /// metadata. Returns a [ListenerDisposable] to unregister the logger.
  ///
  /// ```dart
  /// final disposable = ref.logEvents((entry) {
  ///   log('[${entry.eventName}] ${entry.value}');
  /// });
  /// // later:
  /// disposable.dispose();
  /// ```
  ListenerDisposable logEvents(
    void Function(LogEntry<Object?> entry) callback,
  ) {
    final bus = read(eventBusProvider);
    bus.setLogCallback(callback);
    return ListenerDisposable(() => bus.setLogCallback(null));
  }
}
