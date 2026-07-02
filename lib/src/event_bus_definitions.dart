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

class _EventBus {
  final Map<int, List<_ListenerEntry>> _listeners = {};
  final Map<int, _EventCacheEntry> _lastValues = {};
  final Map<int, List<_MiddlewareEntry>> _middlewares = {};

  BusMetadata _buildMetadata(BusMetadataForEmit? emitMetadata) {
    return BusMetadata(
      timestamp: DateTime.now(),
      source: emitMetadata?.source,
      extraData: emitMetadata?.extraData,
    );
  }

  void listen<T>(
    Ref ref,
    int key,
    ListenerCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
    int priority = 0,
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      try {
        callback(_lastValues[key]!.value as T);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      try {
        callback(_lastValues[key]!.value as T);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      final cached = _lastValues[key]!;
      try {
        callback(cached.value as T, cached.metadata);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      hasMetadata: true,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      final cached = _lastValues[key]!;
      try {
        callback(cached.value as T, cached.metadata);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      hasMetadata: true,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      try {
        callback(_lastValues[key]!.value as T);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      try {
        callback(_lastValues[key]!.value as T);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      final cached = _lastValues[key]!;
      try {
        callback(cached.value as T, cached.metadata);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      priority: priority,
      hasMetadata: true,
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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      final cached = _lastValues[key]!;
      try {
        callback(cached.value as T, cached.metadata);
      } catch (_) {}
    }
    final entry = _ListenerEntry(
      callback,
      onError: onError,
      isAsync: true,
      priority: priority,
      hasMetadata: true,
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

  void emit<T>(int key, T value, {BusMetadataForEmit? metadata}) {
    final meta = _buildMetadata(metadata);
    _emitThroughMiddleware(key, value, meta, (finalValue, m) {
      _notifySync(key, finalValue, m);
    });
  }

  Future<void> emitAsync<T>(
    int key,
    T value, {
    BusMetadataForEmit? metadata,
  }) async {
    final meta = _buildMetadata(metadata);
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

  Stream<T> stream<T>(int key) {
    _ListenerEntry? entry;

    late final StreamController<T> controller;

    controller = StreamController<T>(
      onListen: () {
        entry = _ListenerEntry((T value) => controller.add(value));
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
  bool isDisposed = false;
  bool isAsync = false;
  bool hasMetadata = false;

  _ListenerEntry(
    this.callback, {
    this.onError,
    this.isAsync = false,
    this.priority = 0,
    this.hasMetadata = false,
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
