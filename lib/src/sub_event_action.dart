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
  ///
  /// Set [broadcast] to `true` to allow multiple subscribers.
  Stream<T> stream({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  });

  /// Returns a [Stream] emitting a record `(T, BusMetadata)`.
  ///
  /// Set [broadcast] to `true` to allow multiple subscribers.
  Stream<(T, BusMetadata)> streamWithMeta({
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
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

  List<ValueWithMeta<T>> get history;

  void clearHistory();

  /// Subscribes to the **next** matching emission only, then auto-unsubscribes.
  ///
  /// Returns a [ListenerDisposable] to cancel before it fires.
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
}

/// Shared implementation of [SubEventAction] methods common to both [Ref] and
/// [WidgetRef].
mixin SubEventActionMixin<T> on SubEventAction<T> {
  EventBusCore get eventBus;

  @override
  ListenerDisposable listenManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onSubEvent(
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
    return eventBus.onSubEventWithMeta(
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
    return eventBus.onAsyncSubEvent(
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
    return eventBus.onAsyncSubEventWithMeta(
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
    bool broadcast = false,
  }) {
    return eventBus.streamSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
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
    return eventBus.streamWithMetaSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
      sticky: sticky,
      priority: priority,
      where: where,
      broadcast: broadcast,
    );
  }

  @override
  void clearListeners() {
    eventBus.clearSubEvent(identifier.key);
  }

  @override
  void clearSticky() {
    eventBus.clearSubEventSticky(identifier.key);
  }

  @override
  bool get hasClients {
    return eventBus.subEventHasClients(identifier.key);
  }

  @override
  T? get lastValue => eventBus.subEventCached<T>(
        identifier.key,
        identifier.parentEvent.key,
        identifier.where,
      );

  @override
  List<ValueWithMeta<T>> get history {
    eventBus.setHistorySize(identifier.key, identifier.historySize);
    eventBus.ensureSubEventRegistered(identifier.key, identifier.parentEvent.key, identifier.where);
    return eventBus.history<T>(identifier.key);
  }

  @override
  void clearHistory() => eventBus.clearHistory(identifier.key);

  @override
  ListenerDisposable listenOnceManually(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onOnceSubEvent(
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
  ListenerDisposable listenOnceManuallyWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    return eventBus.onOnceSubEventWithMeta(
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
}

/// [SubEventAction] implementation tied to a [Ref] for automatic lifecycle
/// management via [listen].
class SubEventActionForRef<T> extends SubEventAction<T>
    with SubEventActionMixin<T> {
  final Ref ref;

  SubEventActionForRef({required super.identifier, required this.ref}) {
    eventBus.setHistorySize(identifier.key, identifier.historySize);
  }

  @override
  EventBusCore get eventBus => ref.read(eventBusProvider);

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
    eventBus.listenSubEvent(
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
    eventBus.listenSubEventWithMeta(
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
    eventBus.listenAsyncSubEvent(
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
    eventBus.listenAsyncSubEventWithMeta(
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

  /// Subscribes to the **next** matching emission only with **auto-disposal**.
  void listenOnce(
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenOnceSubEvent(
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

  /// One-shot with metadata and **automatic disposal**.
  void listenOnceWithMeta(
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    eventBus.listenOnceSubEventWithMeta(
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
}

/// [SubEventAction] implementation tied to a [WidgetRef], used from widgets.
///
/// Does **not** provide a [listen] method — use [listenManually] instead.
class SubEventActionForWidgetRef<T> extends SubEventAction<T>
    with SubEventActionMixin<T> {
  final WidgetRef ref;

  SubEventActionForWidgetRef({required super.identifier, required this.ref}) {
    eventBus.setHistorySize(identifier.key, identifier.historySize);
  }

  @override
  EventBusCore get eventBus => ref.read(eventBusProvider);
}
