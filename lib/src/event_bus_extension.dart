import 'package:event_bus_riverpod/src/event_bus_action.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
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
}
