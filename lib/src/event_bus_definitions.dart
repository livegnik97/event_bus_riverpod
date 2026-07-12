part of './event_bus_provider.dart';

// Generic callback type definitions
typedef ListenerCallback<T> = void Function(T value);
typedef ListenerCallbackAsync<T> = Future<void> Function(T value);
typedef EventMiddleware<T> =
    void Function(T value, void Function(T value) next);

typedef ListenerWithMetaCallback<T> =
    void Function(T value, BusMetadata metadata);
typedef ListenerWithMetaCallbackAsync<T> =
    Future<void> Function(T value, BusMetadata metadata);

typedef ListenerWhere<T> = bool Function(T value, BusMetadata metadata);

class EventBusCore {
  final Map<int, List<_ListenerEntry>> _listeners = {};
  final Map<int, _EventCacheEntry> _lastValues = {};
  final Map<int, List<_MiddlewareEntry>> _middlewares = {};
  final Map<int, List<_ListenerEntry>> _subEventListeners = {};
  final Map<int, _EventCacheEntry> _subEventLastValues = {};
  final Map<int, List<int>> _parentToSubEventKeys = {};
  final Map<int, dynamic> _subEventWhere = {};
  final Set<int> _subEventBackfilledNoMatch = {};

  BusMetadata _buildMetadata(String? source, dynamic extraData) {
    return BusMetadata(
      timestamp: DateTime.now(),
      source: source,
      extraData: extraData,
    );
  }

  void _tryDeliverSticky<T>(
    int key,
    ListenerWhere<T>? where,
    void Function(T value) deliver,
  ) {
    try {
      if (!_lastValues.containsKey(key)) return;
      final cached = _lastValues[key]!;
      if (where == null || where(cached.value as T, cached.metadata)) {
        deliver(cached.value as T);
      }
    } catch (_) {}
  }

  void _tryDeliverStickyWithMeta<T>(
    int key,
    ListenerWhere<T>? where,
    void Function(T value, BusMetadata metadata) deliver,
  ) {
    try {
      if (!_lastValues.containsKey(key)) return;
      final cached = _lastValues[key]!;
      if (where == null || where(cached.value as T, cached.metadata)) {
        deliver(cached.value as T, cached.metadata);
      }
    } catch (_) {}
  }

  void _tryDeliverSubEventSticky<T>(
    int subKey,
    int parentKey,
    dynamic subEventWhere,
    ListenerWhere<T>? where,
    void Function(T value) deliver,
  ) {
    if (!_subEventLastValues.containsKey(subKey)) {
      _backfillSubEventStickyFromParent<T>(subKey, parentKey, subEventWhere);
    }
    try {
      if (!_subEventLastValues.containsKey(subKey)) return;
      final cached = _subEventLastValues[subKey]!;
      if (where == null || where(cached.value as T, cached.metadata)) {
        deliver(cached.value as T);
      }
    } catch (_) {}
  }

  void _tryDeliverSubEventStickyWithMeta<T>(
    int subKey,
    int parentKey,
    dynamic subEventWhere,
    ListenerWhere<T>? where,
    void Function(T value, BusMetadata metadata) deliver,
  ) {
    if (!_subEventLastValues.containsKey(subKey)) {
      _backfillSubEventStickyFromParent<T>(subKey, parentKey, subEventWhere);
    }
    try {
      if (!_subEventLastValues.containsKey(subKey)) return;
      final cached = _subEventLastValues[subKey]!;
      if (where == null || where(cached.value as T, cached.metadata)) {
        deliver(cached.value as T, cached.metadata);
      }
    } catch (_) {}
  }

  void listen<T>(
    Ref ref,
    int key,
    ListenerCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverSticky<T>(key, where, (v) => callback(v));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    if (autoDispose) {
      ref.onDispose(() {
        _removeListener(key, entry);
      });
    }
  }

  void listenAsync<T>(
    Ref ref,
    int key,
    ListenerCallbackAsync<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverSticky<T>(key, where, (v) => callback(v));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    if (autoDispose) {
      ref.onDispose(() {
        _removeListener(key, entry);
      });
    }
  }

  void listenWithMeta<T>(
    Ref ref,
    int key,
    ListenerWithMetaCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverStickyWithMeta<T>(key, where, (v, m) => callback(v, m));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    if (autoDispose) {
      ref.onDispose(() {
        _removeListener(key, entry);
      });
    }
  }

  void listenAsyncWithMeta<T>(
    Ref ref,
    int key,
    ListenerWithMetaCallbackAsync<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverStickyWithMeta<T>(key, where, (v, m) => callback(v, m));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      hasMetadata: true,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    if (autoDispose) {
      ref.onDispose(() {
        _removeListener(key, entry);
      });
    }
  }

  ListenerDisposable on<T>(
    int key,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverSticky<T>(key, where, (v) => callback(v));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    return ListenerDisposable(() {
      _removeListener(key, entry);
    });
  }

  ListenerDisposable onAsync<T>(
    int key,
    ListenerCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverSticky<T>(key, where, (v) => callback(v));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    return ListenerDisposable(() {
      _removeListener(key, entry);
    });
  }

  ListenerDisposable onWithMeta<T>(
    int key,
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverStickyWithMeta<T>(key, where, (v, m) => callback(v, m));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    return ListenerDisposable(() {
      _removeListener(key, entry);
    });
  }

  ListenerDisposable onAsyncWithMeta<T>(
    int key,
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    if (sticky) {
      _tryDeliverStickyWithMeta<T>(key, where, (v, m) => callback(v, m));
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      hasMetadata: true,
      where: where,
    );

    _listeners.putIfAbsent(key, () => []).add(entry);

    return ListenerDisposable(() {
      _removeListener(key, entry);
    });
  }

  void listenOnce<T>(
    Ref ref,
    int key,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ListenerEntry? entry;
    void wrapped(T value) {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
      callback(value);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      where: where,
    );
    entry = e1;
    _listeners.putIfAbsent(key, () => []).add(e1);
    if (sticky) {
      _tryDeliverSticky<T>(key, where, (v) => wrapped(v));
    }
    ref.onDispose(() {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
    });
  }

  void listenOnceWithMeta<T>(
    Ref ref,
    int key,
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ListenerEntry? entry;
    void wrapped(T value, BusMetadata metadata) {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
      callback(value, metadata);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    entry = e1;
    _listeners.putIfAbsent(key, () => []).add(e1);
    if (sticky) {
      _tryDeliverStickyWithMeta<T>(key, where, (v, m) => wrapped(v, m));
    }
    ref.onDispose(() {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
    });
  }

  ListenerDisposable onOnce<T>(
    int key,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ListenerEntry? entry;
    void wrapped(T value) {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
      callback(value);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      where: where,
    );
    entry = e1;
    _listeners.putIfAbsent(key, () => []).add(e1);
    if (sticky) {
      _tryDeliverSticky<T>(key, where, (v) => wrapped(v));
    }
    return ListenerDisposable(() {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
    });
  }

  ListenerDisposable onOnceWithMeta<T>(
    int key,
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ListenerEntry? entry;
    void wrapped(T value, BusMetadata metadata) {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
      callback(value, metadata);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    entry = e1;
    _listeners.putIfAbsent(key, () => []).add(e1);
    if (sticky) {
      _tryDeliverStickyWithMeta<T>(key, where, (v, m) => wrapped(v, m));
    }
    return ListenerDisposable(() {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
    });
  }

  void _reportError(_ListenerEntry entry, Object error, StackTrace stack) {
    try {
      if (entry.onError != null) {
        entry.onError!(error, stack);
      } else if (kDebugMode) {
        log('[event_bus_riverpod] Error in listener: $error\n$stack');
      }
    } catch (e, st) {
      if (kDebugMode) {
        log('[event_bus_riverpod] Error in onError: $e\n$st');
      }
    }
  }

  List<Future<void>> _invokeListeners<T>(
    List<_ListenerEntry> listeners,
    T value,
    BusMetadata metadata, {
    bool collectAsync = false,
  }) {
    if (listeners.isEmpty) return [];

    final sorted = List<_ListenerEntry>.from(listeners);
    if (listeners.length > 1) {
      final firstPriority = listeners.first.priority;
      final allSame = listeners.every((e) => e.priority == firstPriority);
      if (!allSame) {
        sorted.sort((a, b) => b.priority.compareTo(a.priority));
      }
    }

    final futures = <Future<void>>[];

    for (final entry in sorted) {
      if (entry.isDisposed) continue;

      if (entry.where != null) {
        try {
          if (!(entry.where! as bool Function(T, BusMetadata))(
            value,
            metadata,
          )) {
            continue;
          }
        } catch (e, st) {
          if (kDebugMode) {
            log('[event_bus_riverpod] Error in where: $e\n$st');
          }
          continue;
        }
      }

      if (collectAsync && entry.isAsync) {
        futures.add(() async {
          try {
            if (entry.hasMetadata) {
              await entry.callback(value, metadata);
            } else {
              await entry.callback(value);
            }
          } catch (e, st) {
            _reportError(entry, e, st);
          }
        }());
      } else {
        try {
          if (entry.hasMetadata) {
            entry.callback(value, metadata);
          } else {
            entry.callback(value);
          }
        } catch (e, st) {
          _reportError(entry, e, st);
        }
      }
    }

    return futures;
  }

  void _notifySync<T>(int key, T value, BusMetadata metadata) {
    _lastValues[key] = _EventCacheEntry(value, metadata);
    final listeners = _listeners[key];
    if (listeners != null) {
      _invokeListeners(listeners, value, metadata);
      listeners.removeWhere((entry) => entry.isDisposed);
      if (listeners.isEmpty) _listeners.remove(key);
    }
    _fireSubEventsSync<T>(key, value, metadata);
  }

  Future<void> _notifyAsync<T>(int key, T value, BusMetadata metadata) async {
    _lastValues[key] = _EventCacheEntry(value, metadata);
    final listeners = _listeners[key];
    if (listeners != null) {
      final futures = _invokeListeners(
        listeners,
        value,
        metadata,
        collectAsync: true,
      );
      await Future.wait(futures);
      listeners.removeWhere((entry) => entry.isDisposed);
      if (listeners.isEmpty) _listeners.remove(key);
    }
    await _fireSubEventsAsync<T>(key, value, metadata);
  }

  void _fireSubEventsSync<T>(int parentKey, T value, BusMetadata metadata) {
    final subKeys = _parentToSubEventKeys[parentKey];
    if (subKeys == null || subKeys.isEmpty) return;

    for (final subKey in List<int>.from(subKeys)) {
      final subWhere = _subEventWhere[subKey];
      if (subWhere == null) continue;

      try {
        if (!(subWhere as bool Function(T, BusMetadata))(value, metadata))
          continue;
      } catch (_) {
        continue;
      }

      _subEventLastValues[subKey] = _EventCacheEntry(value, metadata);

      final listeners = _subEventListeners[subKey];
      if (listeners == null || listeners.isEmpty) continue;

      _invokeListeners(listeners, value, metadata);

      listeners.removeWhere((entry) => entry.isDisposed);
      if (listeners.isEmpty) {
        _subEventListeners.remove(subKey);
        _subEventWhere.remove(subKey);
        subKeys.remove(subKey);
      }
    }

    if (subKeys.isEmpty) _parentToSubEventKeys.remove(parentKey);
  }

  Future<void> _fireSubEventsAsync<T>(
    int parentKey,
    T value,
    BusMetadata metadata,
  ) async {
    final subKeys = _parentToSubEventKeys[parentKey];
    if (subKeys == null || subKeys.isEmpty) return;

    for (final subKey in List<int>.from(subKeys)) {
      final subWhere = _subEventWhere[subKey];
      if (subWhere == null) continue;

      try {
        if (!(subWhere as bool Function(T, BusMetadata))(value, metadata))
          continue;
      } catch (_) {
        continue;
      }

      _subEventLastValues[subKey] = _EventCacheEntry(value, metadata);

      final listeners = _subEventListeners[subKey];
      if (listeners == null || listeners.isEmpty) continue;

      final futures = _invokeListeners(
        listeners,
        value,
        metadata,
        collectAsync: true,
      );
      await Future.wait(futures);

      listeners.removeWhere((entry) => entry.isDisposed);
      if (listeners.isEmpty) {
        _subEventListeners.remove(subKey);
        _subEventWhere.remove(subKey);
        subKeys.remove(subKey);
      }
    }

    if (subKeys.isEmpty) _parentToSubEventKeys.remove(parentKey);
  }

  void _emitThroughMiddleware<T>(
    int key,
    T value,
    BusMetadata metadata,
    void Function(T, BusMetadata) onDelivered,
  ) {
    final chain = _middlewares[key];
    if (chain == null || chain.isEmpty) {
      onDelivered(value, metadata);
      return;
    }

    int i = 0;
    void next(T val) {
      if (i < chain.length) {
        (chain[i++].callback as EventMiddleware<T>)(val, next);
      } else {
        onDelivered(val, metadata);
      }
    }

    next(value);
  }

  void emit<T>(int key, T value, {String? source, dynamic extraData}) {
    final meta = _buildMetadata(source, extraData);
    _emitThroughMiddleware(key, value, meta, (finalValue, m) {
      _notifySync(key, finalValue, m);
    });
  }

  Future<void> emitAsync<T>(
    int key,
    T value, {
    String? source,
    dynamic extraData,
  }) async {
    final meta = _buildMetadata(source, extraData);
    await _emitThroughMiddlewareAsync(key, value, meta);
  }

  Future<void> _emitThroughMiddlewareAsync<T>(
    int key,
    T value,
    BusMetadata metadata,
  ) async {
    final chain = _middlewares[key];
    if (chain == null || chain.isEmpty) {
      await _notifyAsync(key, value, metadata);
      return;
    }

    bool completed = false;
    T? finalValue;
    int i = 0;
    void next(T val) {
      if (i < chain.length) {
        (chain[i++].callback as EventMiddleware<T>)(val, next);
      } else {
        completed = true;
        finalValue = val;
      }
    }

    next(value);

    if (completed) {
      await _notifyAsync(key, finalValue as T, metadata);
    }
  }

  ListenerDisposable applyMiddleware<T>(
    int key,
    EventMiddleware<T> middleware,
  ) {
    final entry = _MiddlewareEntry(middleware);
    _middlewares.putIfAbsent(key, () => []).add(entry);
    return ListenerDisposable(() {
      _middlewares[key]?.remove(entry);
      if (_middlewares[key]?.isEmpty ?? false) {
        _middlewares.remove(key);
      }
    });
  }

  Stream<T> stream<T>(
    int key, {
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  }) {
    _ListenerEntry? entry;

    late final StreamController<T> controller;

    void onListen() {
      if (sticky) {
        _tryDeliverSticky<T>(key, where, (v) => controller.add(v));
      }
      entry = _ListenerEntry(
        (T value) => controller.add(value),
        priority: priority,
        where: where,
      );
      _listeners.putIfAbsent(key, () => []).add(entry!);
    }

    void onCancel() {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
    }

    controller = broadcast
        ? StreamController<T>.broadcast(onListen: onListen, onCancel: onCancel)
        : StreamController<T>(onListen: onListen, onCancel: onCancel);

    return controller.stream;
  }

  Stream<(T, BusMetadata)> streamWithMeta<T>(
    int key, {
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  }) {
    _ListenerEntry? entry;

    late final StreamController<(T, BusMetadata)> controller;

    void onListenWithMeta() {
      if (sticky) {
        _tryDeliverStickyWithMeta<T>(
          key,
          where,
          (v, m) => controller.add((v, m)),
        );
      }
      entry = _ListenerEntry(
        (T value, BusMetadata metadata) => controller.add((value, metadata)),
        priority: priority,
        where: where,
        hasMetadata: true,
      );
      _listeners.putIfAbsent(key, () => []).add(entry!);
    }

    void onCancel() {
      if (entry != null) {
        _removeListener(key, entry!);
        entry = null;
      }
    }

    controller = broadcast
        ? StreamController<(T, BusMetadata)>.broadcast(
            onListen: onListenWithMeta,
            onCancel: onCancel,
          )
        : StreamController<(T, BusMetadata)>(
            onListen: onListenWithMeta,
            onCancel: onCancel,
          );

    return controller.stream;
  }

  bool hasClients(int key) {
    final listeners = _listeners[key];
    return listeners != null &&
        List.from(listeners).any((entry) => !entry.isDisposed);
  }

  void _removeListener(int key, _ListenerEntry entry) {
    entry.markAsDisposed();
    _listeners[key]?.remove(entry);
    if (_listeners[key]?.isEmpty ?? false) {
      _listeners.remove(key);
    }
  }

  T? lastValue<T>(int key) => _lastValues[key]?.value as T?;

  T? lastSubEventValue<T>(int subKey) =>
      _subEventLastValues[subKey]?.value as T?;

  T? subEventCached<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
  ) {
    if (!_subEventLastValues.containsKey(subKey)) {
      if (!_subEventWhere.containsKey(subKey)) {
        _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
      }
      _backfillSubEventStickyFromParent<T>(subKey, parentKey, subEventWhere);
    }
    return _subEventLastValues[subKey]?.value as T?;
  }

  void clearEvent(int key) => _listeners.remove(key);

  void clearSticky(int key) => _lastValues.remove(key);

  void clearMiddlewares(int key) => _middlewares.remove(key);

  void clearAll() {
    _listeners.clear();
    _lastValues.clear();
    _middlewares.clear();
    _subEventListeners.clear();
    _subEventLastValues.clear();
    _parentToSubEventKeys.clear();
    _subEventWhere.clear();
    _subEventBackfilledNoMatch.clear();
  }

  // ── SubEvent listener methods ──

  void _ensureSubEventRegistered(
    int subKey,
    int parentKey,
    dynamic subEventWhere,
  ) {
    _parentToSubEventKeys.putIfAbsent(parentKey, () => []).add(subKey);
    _subEventWhere.putIfAbsent(subKey, () => subEventWhere);
  }

  void _backfillSubEventStickyFromParent<T>(
    int subKey,
    int parentKey,
    dynamic subEventWhere,
  ) {
    if (_subEventLastValues.containsKey(subKey)) return;
    if (_subEventBackfilledNoMatch.contains(subKey)) return;
    final parentCached = _lastValues[parentKey];
    if (parentCached == null) return;
    try {
      if (subEventWhere(parentCached.value as T, parentCached.metadata)) {
        _subEventLastValues[subKey] = parentCached;
      } else {
        _subEventBackfilledNoMatch.add(subKey);
      }
    } catch (_) {
      _subEventBackfilledNoMatch.add(subKey);
    }
  }

  void listenSubEvent<T>(
    Ref ref,
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventSticky<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v) => callback(v),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    if (autoDispose) {
      ref.onDispose(() => _removeSubEventListener(subKey, entry));
    }
  }

  void listenAsyncSubEvent<T>(
    Ref ref,
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerCallbackAsync<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventSticky<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v) => callback(v),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    if (autoDispose) {
      ref.onDispose(() => _removeSubEventListener(subKey, entry));
    }
  }

  void listenSubEventWithMeta<T>(
    Ref ref,
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerWithMetaCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventStickyWithMeta<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v, m) => callback(v, m),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    if (autoDispose) {
      ref.onDispose(() => _removeSubEventListener(subKey, entry));
    }
  }

  void listenAsyncSubEventWithMeta<T>(
    Ref ref,
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerWithMetaCallbackAsync<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventStickyWithMeta<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v, m) => callback(v, m),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    if (autoDispose) {
      ref.onDispose(() => _removeSubEventListener(subKey, entry));
    }
  }

  ListenerDisposable onSubEvent<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventSticky<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v) => callback(v),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    return ListenerDisposable(() => _removeSubEventListener(subKey, entry));
  }

  ListenerDisposable onAsyncSubEvent<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventSticky<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v) => callback(v),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    return ListenerDisposable(() => _removeSubEventListener(subKey, entry));
  }

  ListenerDisposable onSubEventWithMeta<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventStickyWithMeta<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v, m) => callback(v, m),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    return ListenerDisposable(() => _removeSubEventListener(subKey, entry));
  }

  ListenerDisposable onAsyncSubEventWithMeta<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerWithMetaCallbackAsync<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    if (sticky) {
      _tryDeliverSubEventStickyWithMeta<T>(
        subKey,
        parentKey,
        subEventWhere,
        where,
        (v, m) => callback(v, m),
      );
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    _subEventListeners.putIfAbsent(subKey, () => []).add(entry);
    return ListenerDisposable(() => _removeSubEventListener(subKey, entry));
  }

  void listenOnceSubEvent<T>(
    Ref ref,
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    _ListenerEntry? entry;
    void wrapped(T value) {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
      callback(value);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      where: where,
    );
    entry = e1;
    _subEventListeners.putIfAbsent(subKey, () => []).add(e1);
    if (sticky) {
      _tryDeliverSubEventSticky<T>(subKey, parentKey, subEventWhere, where, (v) => wrapped(v));
    }
    ref.onDispose(() {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
    });
  }

  void listenOnceSubEventWithMeta<T>(
    Ref ref,
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    _ListenerEntry? entry;
    void wrapped(T value, BusMetadata metadata) {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
      callback(value, metadata);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    entry = e1;
    _subEventListeners.putIfAbsent(subKey, () => []).add(e1);
    if (sticky) {
      _tryDeliverSubEventStickyWithMeta<T>(subKey, parentKey, subEventWhere, where, (v, m) => wrapped(v, m));
    }
    ref.onDispose(() {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
    });
  }

  ListenerDisposable onOnceSubEvent<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    _ListenerEntry? entry;
    void wrapped(T value) {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
      callback(value);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      where: where,
    );
    entry = e1;
    _subEventListeners.putIfAbsent(subKey, () => []).add(e1);
    if (sticky) {
      _tryDeliverSubEventSticky<T>(subKey, parentKey, subEventWhere, where, (v) => wrapped(v));
    }
    return ListenerDisposable(() {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
    });
  }

  ListenerDisposable onOnceSubEventWithMeta<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere,
    ListenerWithMetaCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    _ListenerEntry? entry;
    void wrapped(T value, BusMetadata metadata) {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
      callback(value, metadata);
    }
    final e1 = _ListenerEntry(
      wrapped,
      onError: onError,
      priority: priority,
      hasMetadata: true,
      where: where,
    );
    entry = e1;
    _subEventListeners.putIfAbsent(subKey, () => []).add(e1);
    if (sticky) {
      _tryDeliverSubEventStickyWithMeta<T>(subKey, parentKey, subEventWhere, where, (v, m) => wrapped(v, m));
    }
    return ListenerDisposable(() {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
    });
  }

  // ── SubEvent stream methods ──

  Stream<T> streamSubEvent<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere, {
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    _ListenerEntry? entry;

    late final StreamController<T> controller;

    void onListen() {
      if (sticky) {
        _tryDeliverSubEventSticky<T>(
          subKey,
          parentKey,
          subEventWhere,
          where,
          (v) => controller.add(v),
        );
      }
      entry = _ListenerEntry(
        (T value) => controller.add(value),
        priority: priority,
        where: where,
      );
      _subEventListeners.putIfAbsent(subKey, () => []).add(entry!);
    }

    void onCancel() {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
    }

    controller = broadcast
        ? StreamController<T>.broadcast(onListen: onListen, onCancel: onCancel)
        : StreamController<T>(onListen: onListen, onCancel: onCancel);

    return controller.stream;
  }

  Stream<(T, BusMetadata)> streamWithMetaSubEvent<T>(
    int subKey,
    int parentKey,
    ListenerWhere<T> subEventWhere, {
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
    bool broadcast = false,
  }) {
    _ensureSubEventRegistered(subKey, parentKey, subEventWhere);
    _ListenerEntry? entry;

    late final StreamController<(T, BusMetadata)> controller;

    void onListen() {
      if (sticky) {
        _tryDeliverSubEventStickyWithMeta<T>(
          subKey,
          parentKey,
          subEventWhere,
          where,
          (v, m) => controller.add((v, m)),
        );
      }
      entry = _ListenerEntry(
        (T value, BusMetadata metadata) => controller.add((value, metadata)),
        priority: priority,
        where: where,
        hasMetadata: true,
      );
      _subEventListeners.putIfAbsent(subKey, () => []).add(entry!);
    }

    void onCancel() {
      if (entry != null) {
        _removeSubEventListener(subKey, entry!);
        entry = null;
      }
    }

    controller = broadcast
        ? StreamController<(T, BusMetadata)>.broadcast(
            onListen: onListen,
            onCancel: onCancel,
          )
        : StreamController<(T, BusMetadata)>(
            onListen: onListen,
            onCancel: onCancel,
          );

    return controller.stream;
  }

  // ── SubEvent helpers ──

  bool subEventHasClients(int subKey) {
    final listeners = _subEventListeners[subKey];
    return listeners != null &&
        List.from(listeners).any((entry) => !entry.isDisposed);
  }

  void _removeSubEventListener(int subKey, _ListenerEntry entry) {
    entry.markAsDisposed();
    _subEventListeners[subKey]?.remove(entry);
    if (_subEventListeners[subKey]?.isEmpty ?? false) {
      _subEventListeners.remove(subKey);
      _subEventWhere.remove(subKey);
      _subEventBackfilledNoMatch.remove(subKey);
      for (final v in _parentToSubEventKeys.values) {
        v.remove(subKey);
      }
      _parentToSubEventKeys.removeWhere((_, v) => v.isEmpty);
    }
  }

  void clearSubEvent(int subKey) {
    _subEventListeners.remove(subKey);
    _subEventWhere.remove(subKey);
    _subEventBackfilledNoMatch.remove(subKey);
    for (final v in _parentToSubEventKeys.values) {
      v.remove(subKey);
    }
    _parentToSubEventKeys.removeWhere((_, v) => v.isEmpty);
  }

  void clearSubEventSticky(int subKey) {
    _subEventLastValues.remove(subKey);
    _subEventBackfilledNoMatch.remove(subKey);
  }
}

class _ListenerEntry {
  final dynamic callback;
  final void Function(Object, StackTrace)? onError;
  final int priority;
  final dynamic where;
  bool isDisposed = false;
  bool isAsync = false;
  bool hasMetadata = false;

  _ListenerEntry(
    this.callback, {
    this.onError,
    this.isAsync = false,
    this.priority = 0,
    this.hasMetadata = false,
    this.where,
  });

  void markAsDisposed() => isDisposed = true;
}

class _MiddlewareEntry {
  final dynamic callback;
  _MiddlewareEntry(this.callback);
}

class _EventCacheEntry {
  final Object? value;
  final BusMetadata metadata;
  _EventCacheEntry(this.value, this.metadata);
}
