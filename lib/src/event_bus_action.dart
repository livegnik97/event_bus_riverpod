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
    bool sticky = false,
  });

  /// Subscribes to this event with an async callback and returns a [ListenerDisposable].
  ///
  /// The subscription lives until [ListenerDisposable.dispose] is called.
  /// It is **not** tied to any Riverpod lifecycle.
  ///
  /// ```dart
  /// final disposable = ref.event(onCounter).listenManuallyAsync((v) async {
  ///   await someAsyncOp(v);
  /// });
  /// disposable.dispose();
  /// ```
  ListenerDisposable listenManuallyAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
  });

  /// Fires the event, delivering [value] to all active listeners.
  ///
  /// ```dart
  /// ref.event(onCounter).emit(42);
  /// ```
  void emit(T value);

  /// Fires the event and awaits all async listeners.
  ///
  /// Sync listeners run first, then all async listeners run in parallel.
  /// The returned future completes when all have finished.
  ///
  /// ```dart
  /// await ref.event(onCounter).emitAsync(42);
  /// ```
  Future<void> emitAsync(T value);

  /// Returns a [Stream] that emits every time this event fires.
  ///
  /// The stream is single-subscription. It is automatically cleaned up when
  /// the stream subscription is cancelled.
  ///
  /// ```dart
  /// ref.event(onCounter).stream().listen(print);
  /// ```
  Stream<T> stream();

  /// Removes all listeners registered for this event.
  void clearListeners();

  /// Clears the cached last value so new sticky subscribers won't receive it.
  ///
  /// ```dart
  /// ref.event(onCounter).emit(42);
  ///
  /// // This listener receives 42 immediately from the sticky cache
  /// ref.event(onCounter).listen((v) { }, sticky: true);
  ///
  /// ref.event(onCounter).clearSticky();
  ///
  /// // This listener receives nothing from cache (no value emitted yet)
  /// ref.event(onCounter).listen((v) { }, sticky: true);
  /// ```
  void clearSticky();

  /// Registers a middleware that intercepts events before they reach listeners.
  ///
  /// Middlewares run in FIFO order. Each middleware can modify the value or
  /// cancel the event by not calling [next]. Returns a [ListenerDisposable]
  /// to remove the middleware.
  ///
  /// ```dart
  /// final disposable = ref.event(onCounter).applyMiddleware((value, next) {
  ///   log('Event: $value');
  ///   next(value + 1);
  /// });
  ///
  /// // Remove the middleware when no longer needed
  /// disposable.dispose();
  /// ```
  ListenerDisposable applyMiddleware(EventMiddleware<T> middleware);

  /// Removes all middlewares registered for this event.
  void clearMiddlewares();

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
    bool sticky = false,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listen(ref, event.key, callback, onError: onError, sticky: sticky);
  }

  /// Subscribes to this event with an async callback and **automatic disposal**
  /// tied to the [Ref].
  ///
  /// The listener is cleaned up when the provider that owns [ref] is
  /// invalidated or its container disposed. No manual unsubscribe needed.
  ///
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenAsync((msg) async {
  ///     await saveToLog(msg);
  ///   });
  /// });
  /// ```
  void listenAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listenAsync(ref, event.key, callback, onError: onError, sticky: sticky);
  }

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.on(event.key, callback, onError: onError, sticky: sticky);
  }

  @override
  ListenerDisposable listenManuallyAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.onAsync(event.key, callback, onError: onError, sticky: sticky);
  }

  @override
  Stream<T> stream() {
    final bus = ref.read(eventBusProvider);
    return bus.stream(event.key);
  }

  @override
  void emit(T value) {
    ref.read(eventBusProvider).emit(event.key, value);
  }

  @override
  Future<void> emitAsync(T value) {
    return ref.read(eventBusProvider).emitAsync(event.key, value);
  }

  @override
  void clearListeners() {
    ref.read(eventBusProvider).clearEvent(event.key);
  }

  @override
  void clearSticky() {
    ref.read(eventBusProvider).clearSticky(event.key);
  }

  @override
  ListenerDisposable applyMiddleware(EventMiddleware<T> middleware) {
    final bus = ref.read(eventBusProvider);
    return bus.applyMiddleware(event.key, middleware);
  }

  @override
  void clearMiddlewares() {
    ref.read(eventBusProvider).clearMiddlewares(event.key);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).hasClients(event.key);
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
    bool sticky = false,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.on(event.key, callback, onError: onError, sticky: sticky);
  }

  @override
  ListenerDisposable listenManuallyAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.onAsync(event.key, callback, onError: onError, sticky: sticky);
  }

  @override
  Stream<T> stream() {
    final bus = ref.read(eventBusProvider);
    return bus.stream(event.key);
  }

  @override
  void emit(T value) {
    ref.read(eventBusProvider).emit(event.key, value);
  }

  @override
  Future<void> emitAsync(T value) {
    return ref.read(eventBusProvider).emitAsync(event.key, value);
  }

  @override
  void clearListeners() {
    ref.read(eventBusProvider).clearEvent(event.key);
  }

  @override
  void clearSticky() {
    ref.read(eventBusProvider).clearSticky(event.key);
  }

  @override
  ListenerDisposable applyMiddleware(EventMiddleware<T> middleware) {
    final bus = ref.read(eventBusProvider);
    return bus.applyMiddleware(event.key, middleware);
  }

  @override
  void clearMiddlewares() {
    ref.read(eventBusProvider).clearMiddlewares(event.key);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).hasClients(event.key);
  }
}
