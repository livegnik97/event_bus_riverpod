import 'package:event_bus_riverpod/src/bus_metadata.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';
import 'package:event_bus_riverpod/src/listener_disposable.dart';
import 'package:event_bus_riverpod/src/sub_event_identifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a typed interface to interact with a subEvent.
///
/// A subEvent is a filtered view of a parent [EventBusIdentifier]. It has its
/// own sticky cache and listener list, separate from the parent event.
///
/// Obtain an instance via [Ref.subEvent] or [WidgetRef.subEvent].
abstract class SubEventAction<T> {
  final SubEventIdentifier<T> identifier;

  SubEventAction({required this.identifier});

  /// Subscribes to this subEvent and returns a [ListenerDisposable].
  ///
  /// The subscription lives until [ListenerDisposable.dispose] is called.
  /// It is **not** tied to any Riverpod lifecycle.
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Subscribes to this subEvent with [BusMetadata] access.
  ListenerDisposable listenManuallyWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Subscribes with an async callback and returns a [ListenerDisposable].
  ListenerDisposable listenManuallyAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Subscribes with an async callback and [BusMetadata] access.
  ListenerDisposable listenManuallyAsyncWithMeta(
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Returns a [Stream] that emits every time this subEvent fires.
  Stream<T> stream({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Returns a [Stream] emitting a record `(T, BusMetadata)`.
  Stream<(T, BusMetadata)> streamWithMeta({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  });

  /// Removes all listeners registered for this subEvent.
  void clearListeners();

  /// Clears the cached last value so new sticky subscribers won't receive it.
  void clearSticky();

  /// Whether there is at least one active listener for this subEvent.
  bool get hasClients;

  /// The last value that passed this subEvent's `where` predicate,
  /// or `null` if nothing has been emitted yet (or after [clearSticky]).
  T? get lastValue;
}

/// [SubEventAction] implementation tied to a [Ref] for automatic lifecycle
/// management via [listen].
class SubEventActionForRef<T> extends SubEventAction<T> {
  final Ref ref;

  SubEventActionForRef({required super.identifier, required this.ref});

  /// Subscribes with **automatic disposal** tied to the [Ref].
  ///
  /// The listener is cleaned up when the provider is invalidated.
  void listen(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listenSubEvent(
      ref,
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// Subscribes with **automatic disposal** and [BusMetadata] access.
  void listenWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listenSubEventWithMeta(
      ref,
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// Subscribes with an async callback and **automatic disposal**.
  void listenAsync(
    Future<void> Function(T value) callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listenAsyncSubEvent(
      ref,
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  /// Subscribes with async callback, **automatic disposal**, and metadata.
  void listenAsyncWithMeta(
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    bus.listenAsyncSubEventWithMeta(
      ref,
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      callback,
      onError: onError,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.onSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    final bus = ref.read(eventBusProvider);
    return bus.onSubEventWithMeta(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    final bus = ref.read(eventBusProvider);
    return bus.onAsyncSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    final bus = ref.read(eventBusProvider);
    return bus.onAsyncSubEventWithMeta(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.streamSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  Stream<(T, BusMetadata)> streamWithMeta({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.streamWithMetaSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  void clearListeners() {
    ref.read(eventBusProvider).clearSubEvent(identifier.key);
  }

  @override
  void clearSticky() {
    ref.read(eventBusProvider).clearSubEventSticky(identifier.key);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).subEventHasClients(identifier.key);
  }

  @override
  T? get lastValue => ref.read(eventBusProvider).subEventCached<T>(
        identifier.key,
        identifier.parentEvent.key,
        identifier.where,
      );
}

/// [SubEventAction] implementation tied to a [WidgetRef], used from widgets.
///
/// Does **not** provide a [listen] method — use [listenManually] instead.
class SubEventActionForWidgetRef<T> extends SubEventAction<T> {
  final WidgetRef ref;

  SubEventActionForWidgetRef({required super.identifier, required this.ref});

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.onSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    final bus = ref.read(eventBusProvider);
    return bus.onSubEventWithMeta(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    final bus = ref.read(eventBusProvider);
    return bus.onAsyncSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    final bus = ref.read(eventBusProvider);
    return bus.onAsyncSubEventWithMeta(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.streamSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  Stream<(T, BusMetadata)> streamWithMeta({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    final bus = ref.read(eventBusProvider);
    return bus.streamWithMetaSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      sticky: sticky,
      priority: priority,
      where: where,
    );
  }

  @override
  void clearListeners() {
    ref.read(eventBusProvider).clearSubEvent(identifier.key);
  }

  @override
  void clearSticky() {
    ref.read(eventBusProvider).clearSubEventSticky(identifier.key);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).subEventHasClients(identifier.key);
  }

  @override
  T? get lastValue => ref.read(eventBusProvider).subEventCached<T>(
        identifier.key,
        identifier.parentEvent.key,
        identifier.where,
      );
}
