import 'package:event_bus_riverpod/src/bus_metadata.dart';
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
  ///
  /// Use [sticky] to receive the last emitted value immediately:
  /// ```dart
  /// ref.event(onCounter).emit(42);
  /// ref.event(onCounter).listenManually((v) {
  ///   print(v); // 42 — received immediately
  /// }, sticky: true);
  /// ```
  ///
  /// Use [priority] to control execution order (higher runs first):
  /// ```dart
  /// ref.event(onCounter).listenManually((v) {
  ///   // runs first
  /// }, priority: 10);
  /// ref.event(onCounter).listenManually((v) {
  ///   // runs after priority 10
  /// }, priority: 0);
  /// ```
  ///
  /// Use [onError] to catch errors thrown by the listener:
  /// ```dart
  /// ref.event(onCounter).listenManually((v) {
  ///   throw Exception('fail');
  /// }, onError: (error, stackTrace) {
  ///   log('Caught: $error');
  /// });
  /// ```
  ///
  /// Use [where] to filter which emissions trigger the callback:
  /// ```dart
  /// ref.event(onCounter).listenManually((v) {
  ///   print(v); // only triggered when v > 0
  /// }, where: (v, _) => v > 0);
  /// ```
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Subscribes to this event and returns a [ListenerDisposable]
  /// with access to [BusMetadata].
  ///
  /// ```dart
  /// final disposable = ref.event(onCounter).listenManuallyWithMeta((v, meta) {
  ///   print(v);                       // 42
  ///   print(meta.timestamp);          // 2026-07-02 15:30:00.123
  ///   print(meta.source);             // "dashboard"
  /// });
  /// disposable.dispose();
  /// ```
  ListenerDisposable listenManuallyWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
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
  ///
  /// Use [sticky] to receive the last emitted value immediately:
  /// ```dart
  /// await ref.event(onCounter).emitAsync(42);
  /// ref.event(onCounter).listenManuallyAsync((v) async {
  ///   print(v); // 42 — received immediately
  /// }, sticky: true);
  /// ```
  ///
  /// Use [priority] to control execution order (higher runs first):
  /// ```dart
  /// ref.event(onCounter).listenManuallyAsync((v) async {
  ///   // runs first
  /// }, priority: 10);
  /// ref.event(onCounter).listenManuallyAsync((v) async {
  ///   // runs after priority 10
  /// }, priority: 0);
  /// ```
  ///
  /// Use [onError] to catch errors thrown by the listener:
  /// ```dart
  /// ref.event(onCounter).listenManuallyAsync((v) async {
  ///   throw Exception('fail');
  /// }, onError: (error, stackTrace) {
  ///   log('Caught: $error');
  /// });
  /// ```
  ///
  /// Use [where] to filter which emissions trigger the callback:
  /// ```dart
  /// ref.event(onCounter).listenManuallyAsync((v) async {
  ///   await log(v);
  /// }, where: (v, _) => v > 0);
  /// ```
  ListenerDisposable listenManuallyAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Subscribes to this event with an async callback and returns a
  /// [ListenerDisposable] with access to [BusMetadata].
  ///
  /// ```dart
  /// final disposable = ref.event(onCounter).listenManuallyAsyncWithMeta(
  ///   (v, meta) async {
  ///     await save(v);
  ///     log('Emitted at ${meta.timestamp} from ${meta.source}');
  ///   },
  /// );
  /// disposable.dispose();
  /// ```
  ListenerDisposable listenManuallyAsyncWithMeta(
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Fires the event, delivering [value] to all active listeners.
  ///
  /// ```dart
  /// ref.event(onCounter).emit(42);
  /// ```
  ///
  /// Optionally attach [source] and [extraData] to this emission:
  /// ```dart
  /// ref.event(onCounter).emit(42, source: 'dashboard');
  /// ```
  void emit(T value, {String? source, dynamic extraData});

  /// Fires the event and awaits all async listeners.
  ///
  /// Sync listeners run first, then all async listeners run in parallel.
  /// The returned future completes when all have finished.
  ///
  /// ```dart
  /// await ref.event(onCounter).emitAsync(42);
  /// ```
  ///
  /// Optionally attach [source] and [extraData] to this emission:
  /// ```dart
  /// await ref.event(onCounter).emitAsync(42, source: 'dashboard');
  /// ```
  Future<void> emitAsync(T value, {String? source, dynamic extraData});

  /// Returns a [Stream] that emits every time this event fires.
  ///
  /// The stream is single-subscription by default. Set [broadcast] to `true` to
  /// allow multiple subscribers. It is automatically cleaned up when
  /// the stream subscription is cancelled.
  ///
  /// ```dart
  /// ref.event(onCounter).stream().listen(print);
  /// ```
  ///
  /// Use [sticky] to receive the last emitted value immediately:
  /// ```dart
  /// ref.event(onCounter).emit(42);
  /// ref.event(onCounter).stream(sticky: true).listen(print); // 42
  /// ```
  ///
  /// Use [priority] to control execution order (higher runs first):
  /// ```dart
  /// ref.event(onCounter).stream(priority: 10).listen(print);
  /// ```
  ///
  /// Use [where] to filter which emissions reach the stream:
  /// ```dart
  /// ref.event(onCounter).stream(where: (v, _) => v > 0).listen(print);
  /// ```
  ///
  /// Use [broadcast] to allow multiple subscribers on the same stream:
  /// ```dart
  /// final stream = ref.event(onCounter).stream(broadcast: true);
  /// stream.listen(print); // subscriber 1
  /// stream.listen(print); // subscriber 2
  /// ```
  Stream<T> stream({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  });

  /// Returns a [Stream] that emits a record `(T, BusMetadata)` every time this
  /// event fires, providing access to metadata alongside the value.
  ///
  /// The stream is single-subscription by default. Set [broadcast] to `true` to
  /// allow multiple subscribers. It is automatically cleaned up when
  /// the stream subscription is cancelled.
  ///
  /// ```dart
  /// ref.event(onCounter).streamWithMeta().listen((v, meta) {
  ///   print(v);                       // 42
  ///   print(meta.timestamp);          // 2026-07-02 15:30:00.123
  /// });
  /// ```
  ///
  /// Use [sticky] to receive the last emitted value immediately:
  /// ```dart
  /// ref.event(onCounter).emit(42, source: 'test');
  /// ref.event(onCounter).streamWithMeta(sticky: true).listen((v, meta) {
  ///   print(v);      // 42
  ///   print(meta.source); // 'test'
  /// });
  /// ```
  ///
  /// Use [priority] to control execution order (higher runs first):
  /// ```dart
  /// ref.event(onCounter).streamWithMeta(priority: 10).listen(print);
  /// ```
  ///
  /// Use [where] to filter which emissions reach the stream:
  /// ```dart
  /// ref.event(onCounter).streamWithMeta(where: (v, _) => v > 0).listen(print);
  /// ```
  ///
  /// Use [broadcast] to allow multiple subscribers on the same stream:
  /// ```dart
  /// final stream = ref.event(onCounter).streamWithMeta(broadcast: true);
  /// stream.listen(print); // subscriber 1
  /// stream.listen(print); // subscriber 2
  /// ```
  Stream<(T, BusMetadata)> streamWithMeta({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  });

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

  /// The last emitted value, or `null` if nothing has been emitted yet
  /// (or after [clearSticky]).
  T? get lastValue;

  /// Returns the last [historySize] emitted values with their metadata, ordered
  /// chronologically. The most recent value is at the end of the list.
  ///
  /// Configured via [EventBusIdentifier.historySize]. Returns an empty list
  /// if [historySize] is 0 (the default).
  ///
  /// ```dart
  /// final onCounter = EventBusIdentifier<int>('onCounter', historySize: 10);
  /// // ...
  /// ref.event(onCounter).emit(1);
  /// ref.event(onCounter).emit(2);
  /// print(ref.event(onCounter).history); // [(1, meta), (2, meta)]
  /// ```
  List<ValueWithMeta<T>> get history;

  /// Clears the event history buffer without affecting listeners, sticky cache,
  /// or middlewares.
  void clearHistory();

  /// Subscribes to the **next** emission only, then automatically unsubscribes.
  ///
  /// Returns a [ListenerDisposable] that can be used to cancel the one-shot
  /// subscription before it fires. Supports [sticky], [priority], [where], and
  /// [onError] like any other listen method.
  ///
  /// ```dart
  /// ref.event(onUserLogin).listenOnceManually((user) {
  ///   navigateToHome(); // fires once, then auto-removes
  /// });
  /// ```
  ListenerDisposable listenOnceManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// One-shot variant with [BusMetadata] access.
  ListenerDisposable listenOnceManuallyWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Awaits the next emission of this event and returns its value.
  ///
  /// Returns a [Future] that completes with the value of the first emission
  /// after this call. Does **not** resolve with previously emitted values
  /// (no sticky behavior).
  ///
  /// Optionally, provide a [timeout] — if the event doesn't fire within the
  /// given duration, the future completes with a [TimeoutException].
  ///
  /// Optionally, provide a [where] filter — only emissions where the
  /// predicate returns `true` will resolve the future.
  ///
  /// ```dart
  /// final user = await ref.event(onUserLogin).waitFor(
  ///   timeout: Duration(seconds: 5),
  ///   where: (u, _) => u.isVerified,
  /// );
  /// ```
  ///
  /// Default [timeout] is 30 seconds. Pass `timeout: null` to wait
  /// indefinitely (not recommended — use [listenOnceManually] instead).
  Future<T> waitFor({
    Duration? timeout = const Duration(seconds: 30),
    ListenerWhere<T>? where,
  });
}

/// Shared implementation of [EventBusAction] methods common to both [Ref] and
/// [WidgetRef].
mixin EventBusActionMixin<T> on EventBusAction<T> {
  EventBusCore get eventBus;

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.on(
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  ListenerDisposable listenManuallyWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onWithMeta(
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  ListenerDisposable listenManuallyAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onAsync(
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  ListenerDisposable listenManuallyAsyncWithMeta(
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onAsyncWithMeta(
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  Stream<T> stream({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  }) {
    return eventBus.stream(
      event.key,
      sticky: sticky,
      priority: priority,
      where: where,
      broadcast: broadcast,
    );
  }

  @override
  Stream<(T, BusMetadata)> streamWithMeta({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  }) {
    return eventBus.streamWithMeta(
      event.key,
      sticky: sticky,
      priority: priority,
      where: where,
      broadcast: broadcast,
    );
  }

  @override
  void emit(T value, {String? source, dynamic extraData}) {
    eventBus.setHistorySize(event.key, event.historySize);
    eventBus.registerEventName(event.key, event.eventName);
    eventBus.emit(event.key, value, source: source, extraData: extraData);
  }

  @override
  Future<void> emitAsync(T value, {String? source, dynamic extraData}) {
    eventBus.setHistorySize(event.key, event.historySize);
    eventBus.registerEventName(event.key, event.eventName);
    return eventBus.emitAsync(
      event.key,
      value,
      source: source,
      extraData: extraData,
    );
  }

  @override
  void clearListeners() {
    eventBus.clearEvent(event.key);
  }

  @override
  void clearSticky() {
    eventBus.clearSticky(event.key);
  }

  @override
  ListenerDisposable applyMiddleware(EventMiddleware<T> middleware) {
    return eventBus.applyMiddleware(event.key, middleware);
  }

  @override
  void clearMiddlewares() {
    eventBus.clearMiddlewares(event.key);
  }

  @override
  bool get hasClients {
    return eventBus.hasClients(event.key);
  }

  @override
  T? get lastValue => eventBus.lastValue<T>(event.key);

  @override
  List<ValueWithMeta<T>> get history {
    eventBus.setHistorySize(event.key, event.historySize);
    return eventBus.history<T>(event.key);
  }

  @override
  void clearHistory() => eventBus.clearHistory(event.key);

  @override
  ListenerDisposable listenOnceManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onOnce(
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  ListenerDisposable listenOnceManuallyWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onOnceWithMeta(
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  Future<T> waitFor({
    Duration? timeout,
    ListenerWhere<T>? where,
  }) {
    return eventBus.waitFor(
      event.key,
      timeout: timeout,
      where: where,
    );
  }
}

/// [EventBusAction] implementation tied to a [Ref] for automatic lifecycle
/// management via [listen].
class EventBusActionForRef<T> extends EventBusAction<T>
    with EventBusActionMixin<T> {
  final Ref ref;

  EventBusActionForRef({required super.event, required this.ref});

  @override
  EventBusCore get eventBus => ref.read(eventBusProvider);

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
  ///
  /// Use [sticky] to receive the last emitted value immediately:
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listen((msg) {
  ///     print(msg); // receives last value if one was emitted before
  ///   }, sticky: true);
  /// });
  /// ```
  ///
  /// Use [priority] to control execution order (higher runs first):
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listen((msg) {
  ///     // runs first
  ///   }, priority: 10);
  ///   ref.event(onGreeting).listen((msg) {
  ///     // runs after priority 10
  ///   }, priority: 0);
  /// });
  /// ```
  ///
  /// Use [onError] to catch errors thrown by the listener:
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listen((msg) {
  ///     throw Exception('fail');
  ///   }, onError: (error, stackTrace) {
  ///     log('Caught: $error');
  ///   });
  /// });
  /// ```
  ///
  /// Use [where] to filter which emissions trigger the callback:
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listen((msg) {
  ///     log(msg);
  ///   }, where: (msg, _) => msg.isNotEmpty);
  /// });
  /// ```
  void listen(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listen(
      ref,
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// Subscribes to this event with **automatic disposal** and access to
  /// [BusMetadata].
  ///
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenWithMeta((msg, meta) {
  ///     log('$msg at ${meta.timestamp}');
  ///   });
  /// });
  /// ```
  void listenWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenWithMeta(
      ref,
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
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
  ///
  /// Use [sticky] to receive the last emitted value immediately:
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenAsync((msg) async {
  ///     print(msg); // receives last value if one was emitted before
  ///   }, sticky: true);
  /// });
  /// ```
  ///
  /// Use [priority] to control execution order (higher runs first):
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenAsync((msg) async {
  ///     // runs first
  ///   }, priority: 10);
  ///   ref.event(onGreeting).listenAsync((msg) async {
  ///     // runs after priority 10
  ///   }, priority: 0);
  /// });
  /// ```
  ///
  /// Use [onError] to catch errors thrown by the listener:
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenAsync((msg) async {
  ///     throw Exception('fail');
  ///   }, onError: (error, stackTrace) {
  ///     log('Caught: $error');
  ///   });
  /// });
  /// ```
  ///
  /// Use [where] to filter which emissions trigger the callback:
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenAsync((msg) async {
  ///     await log(msg);
  ///   }, where: (msg, _) => msg.isNotEmpty);
  /// });
  /// ```
  void listenAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenAsync(
      ref,
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// Subscribes to this event with an async callback, **automatic disposal**,
  /// and access to [BusMetadata].
  ///
  /// ```dart
  /// final provider = Provider<void>((ref) {
  ///   ref.event(onGreeting).listenAsyncWithMeta((msg, meta) async {
  ///     await save(msg);
  ///     log('Received at ${meta.timestamp}');
  ///   });
  /// });
  /// ```
  void listenAsyncWithMeta(
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenAsyncWithMeta(
      ref,
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// Subscribes to the **next** emission only with **automatic disposal**.
  ///
  /// The listener fires once, then removes itself. If the provider is
  /// invalidated before the event fires, [ref.onDispose] cleans it up.
  ///
  /// ```dart
  /// ref.event(onUserLogin).listenOnce((user) {
  ///   navigateToHome(); // fires once, auto-removes
  /// });
  /// ```
  void listenOnce(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenOnce(
      ref,
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// One-shot with metadata and **automatic disposal**.
  void listenOnceWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenOnceWithMeta(
      ref,
      event.key,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }
}

/// [EventBusAction] implementation tied to a [WidgetRef], used from widgets.
///
/// Does **not** provide a [listen] method — use [listenManually] instead,
/// since widget lifecycles are managed differently.
class EventBusActionForWidgetRef<T> extends EventBusAction<T>
    with EventBusActionMixin<T> {
  final WidgetRef ref;

  EventBusActionForWidgetRef({required super.event, required this.ref});

  @override
  EventBusCore get eventBus => ref.read(eventBusProvider);
}
