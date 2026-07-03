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

class _EventBus {
  final Map<int, List<_ListenerEntry>> _listeners = {};
  final Map<int, _EventCacheEntry> _lastValues = {};
  final Map<int, List<_MiddlewareEntry>> _middlewares = {};

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

  void _notifySync<T>(int key, T value, BusMetadata metadata) {
    _lastValues[key] = _EventCacheEntry(value, metadata);
    final listeners = _listeners[key];
    if (listeners == null) return;

    final sorted = List<_ListenerEntry>.from(listeners)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final entry in sorted) {
      if (entry.isDisposed) continue;

      bool canContinue = true;
      if (entry.where != null) {
        try {
          canContinue = (entry.where! as bool Function(T, BusMetadata))(
            value,
            metadata,
          );
        } catch (e, st) {
          canContinue = false;
          if (kDebugMode) {
            log('[event_bus_riverpod] Error in where: $e\n$st');
          }
        }
      }
      if (!canContinue) continue;

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

    listeners.removeWhere((entry) => entry.isDisposed);
    if (listeners.isEmpty) _listeners.remove(key);
  }

  Future<void> _notifyAsync<T>(int key, T value, BusMetadata metadata) async {
    _lastValues[key] = _EventCacheEntry(value, metadata);
    final listeners = _listeners[key];
    if (listeners == null) return;

    final sorted = List<_ListenerEntry>.from(listeners)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final futures = <Future<void>>[];

    for (final entry in sorted) {
      if (entry.isDisposed) continue;

      bool canContinue = true;
      if (entry.where != null) {
        try {
          canContinue = (entry.where! as bool Function(T, BusMetadata))(
            value,
            metadata,
          );
        } catch (e, st) {
          canContinue = false;
          if (kDebugMode) {
            log('[event_bus_riverpod] Error in where: $e\n$st');
          }
        }
      }
      if (!canContinue) continue;

      if (entry.isAsync) {
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

    await Future.wait(futures);

    listeners.removeWhere((entry) => entry.isDisposed);
    if (listeners.isEmpty) _listeners.remove(key);
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

    final completer = Completer<void>();
    int i = 0;
    void next(T val) {
      if (i < chain.length) {
        (chain[i++].callback as EventMiddleware<T>)(val, next);
      } else {
        _notifyAsync(key, val, metadata).then((_) => completer.complete());
      }
    }

    next(value);
    await completer.future;
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
  }) {
    _ListenerEntry? entry;

    late final StreamController<T> controller;

    controller = StreamController<T>(
      onListen: () {
        if (sticky) {
          _tryDeliverSticky<T>(key, where, (v) => controller.add(v));
        }
        entry = _ListenerEntry(
          (T value) => controller.add(value),
          priority: priority,
          where: where,
        );
        _listeners.putIfAbsent(key, () => []).add(entry!);
      },
      onCancel: () {
        if (entry != null) {
          _removeListener(key, entry!);
          entry = null;
        }
      },
    );

    return controller.stream;
  }

  Stream<(T, BusMetadata)> streamWithMeta<T>(
    int key, {
    bool sticky = false,
    int priority = 0,
    ListenerWhere<T>? where,
  }) {
    _ListenerEntry? entry;

    late final StreamController<(T, BusMetadata)> controller;

    controller = StreamController<(T, BusMetadata)>(
      onListen: () {
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
      },
      onCancel: () {
        if (entry != null) {
          _removeListener(key, entry!);
          entry = null;
        }
      },
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

  void clearEvent(int key) => _listeners.remove(key);

  void clearSticky(int key) => _lastValues.remove(key);

  void clearMiddlewares(int key) => _middlewares.remove(key);

  void clearAll() {
    _listeners.clear();
    _lastValues.clear();
    _middlewares.clear();
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
