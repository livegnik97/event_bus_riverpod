import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';
import 'package:event_bus_riverpod/src/listener_disposable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a typed interface to interact with an event bus for a specific event.
///
/// Obtain an instance via [Ref.event] or [WidgetRef.event].
abstract class EventBusAction<T> {
  final EventBusIdentifier<T> event;

  EventBusAction({required this.event});

  /// Subscribes to this event and returns a [ListenerDisposable].
  ///
  /// The subscription lives until [ListenerDisposable.dispose] is called.
  /// It is **not** tied to any Riverpod lifecycle.
  ///
  /// ```dart
  /// final disposable = ref.event(onCounter).listenManually((v) {
  ///   print(v);
  /// });
  /// disposable.dispose(); // unsubscribe
  /// ```
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
  });

  /// Fires the event, delivering [value] to all active listeners.
  ///
  /// ```dart
  /// ref.event(onCounter).emit(42);
  /// ```
  void emit(T value);

  /// Returns a [Stream] that emits every time this event fires.
  ///
  /// The stream is single-subscription. It is automatically cleaned up when
  /// the stream subscription is cancelled.
  ///
  /// ```dart
  /// ref.event(onCounter).stream().listen(print);
  /// ```
  Stream<T> stream({void Function(Object, StackTrace)? onError});

  /// Removes all listeners registered for this event.
  void clearListeners();

  /// Whether there is at least one active listener for this event.
  ///
  /// ```dart
  /// if (ref.event(onCounter).hasClients) {
  ///   ref.event(onCounter).emit(0);
  /// }
  /// ```
  bool get hasClients;
}

/// [EventBusAction] implementation tied to a [Ref] for automatic lifecycle
/// management via [listen].
class EventBusActionForRef<T> extends EventBusAction<T> {
  final Ref ref;

  EventBusActionForRef({required super.event, required this.ref});

  /// Subscribes to this event with **automatic disposal** tied to the [Ref].
  ///
  /// The listener is cleaned up when the provider that owns [ref] is
  /// invalidated or its container disposed. No manual unsubscribe needed.
  ///
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listen((msg) => print(msg));
  /// });
  /// ```
  void listen(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listen(ref, event.eventName, callback, onError: onError);
  }

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.on(event.eventName, callback, onError: onError);
  }

  @override
  Stream<T> stream({void Function(Object, StackTrace)? onError}) {
    final bus = ref.read(eventBusProvider);
    return bus.stream(event.eventName, onError: onError);
  }

  @override
  void emit(T value) {
    ref.read(eventBusProvider).emit(event.eventName, value);
  }

  @override
  void clearListeners() {
    ref.read(eventBusProvider).clearEvent<T>(event.eventName);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).hasClients<T>(event.eventName);
  }
}

/// [EventBusAction] implementation tied to a [WidgetRef], used from widgets.
///
/// Does **not** provide a [listen] method — use [listenManually] instead,
/// since widget lifecycles are managed differently.
class EventBusActionForWidgetRef<T> extends EventBusAction<T> {
  final WidgetRef ref;

  EventBusActionForWidgetRef({required super.event, required this.ref});

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.on(event.eventName, callback, onError: onError);
  }

  @override
  Stream<T> stream({void Function(Object, StackTrace)? onError}) {
    final bus = ref.read(eventBusProvider);
    return bus.stream(event.eventName, onError: onError);
  }

  @override
  void emit(T value) {
    ref.read(eventBusProvider).emit(event.eventName, value);
  }

  @override
  void clearListeners() {
    ref.read(eventBusProvider).clearEvent<T>(event.eventName);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).hasClients<T>(event.eventName);
  }
}
