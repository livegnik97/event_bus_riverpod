part of './event_bus_provider.dart';

// Generic callback type definitions
typedef ListenerCallback<T> = void Function(T value);
typedef ListenerCallbackAsync<T> = Future<void> Function(T value);
typedef EventMiddleware<T> = void Function(T value, void Function(T value) next);

class _EventBus {
  final Map<int, List<_ListenerEntry>> _listeners = {};
  final Map<int, Object?> _lastValues = {};
  final Map<int, List<_MiddlewareEntry>> _middlewares = {};

  void listen<T>(
    Ref ref,
    int key,
    ListenerCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
    bool sticky = false,
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      callback(_lastValues[key] as T);
    }
    final entry = _ListenerEntry(callback, onError: onError);

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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      callback(_lastValues[key] as T);
    }
    final entry = _ListenerEntry(callback, onError: onError, isAsync: true);

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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      callback(_lastValues[key] as T);
    }
    final entry = _ListenerEntry(callback, onError: onError);

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
  }) {
    if (sticky && _lastValues.containsKey(key)) {
      callback(_lastValues[key] as T);
    }
    final entry = _ListenerEntry(callback, onError: onError, isAsync: true);

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

  void _notifySync<T>(int key, T value) {
    _lastValues[key] = value;
    final listeners = _listeners[key];
    if (listeners == null) return;

    for (final entry in List.from(listeners)) {
      if (entry.isDisposed) continue;
      try {
        entry.callback(value);
      } catch (e, st) {
        _reportError(entry, e, st);
      }
    }

    listeners.removeWhere((entry) => entry.isDisposed);
    if (listeners.isEmpty) _listeners.remove(key);
  }

  Future<void> _notifyAsync<T>(int key, T value) async {
    _lastValues[key] = value;
    final listeners = _listeners[key];
    if (listeners == null) return;

    final futures = <Future<void>>[];

    for (final entry in List.from(listeners)) {
      if (entry.isDisposed) continue;
      if (entry.isAsync) {
        futures.add(() async {
          try {
            await entry.callback(value);
          } catch (e, st) {
            _reportError(entry, e, st);
          }
        }());
      } else {
        try {
          entry.callback(value);
        } catch (e, st) {
          _reportError(entry, e, st);
        }
      }
    }

    await Future.wait(futures);

    listeners.removeWhere((entry) => entry.isDisposed);
    if (listeners.isEmpty) _listeners.remove(key);
  }

  void _emitThroughMiddleware<T>(int key, T value, void Function(T) onDelivered) {
    final chain = _middlewares[key];
    if (chain == null || chain.isEmpty) {
      onDelivered(value);
      return;
    }

    int i = 0;
    void next(T val) {
      if (i < chain.length) {
        (chain[i++].callback as EventMiddleware<T>)(val, next);
      } else {
        onDelivered(val);
      }
    }
    next(value);
  }

  void emit<T>(int key, T value) {
    _emitThroughMiddleware(key, value, (finalValue) {
      _notifySync(key, finalValue);
    });
  }

  Future<void> emitAsync<T>(int key, T value) async {
    await _emitThroughMiddlewareAsync(key, value);
  }

  Future<void> _emitThroughMiddlewareAsync<T>(int key, T value) async {
    final chain = _middlewares[key];
    if (chain == null || chain.isEmpty) {
      await _notifyAsync(key, value);
      return;
    }

    final completer = Completer<void>();
    int i = 0;
    void next(T val) {
      if (i < chain.length) {
        (chain[i++].callback as EventMiddleware<T>)(val, next);
      } else {
        _notifyAsync(key, val).then((_) => completer.complete());
      }
    }
    next(value);
    await completer.future;
  }

  ListenerDisposable applyMiddleware<T>(int key, EventMiddleware<T> middleware) {
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
  bool isDisposed = false;
  bool isAsync = false;

  _ListenerEntry(this.callback, {this.onError, this.isAsync = false});

  void markAsDisposed() => isDisposed = true;
}

class _MiddlewareEntry {
  final dynamic callback;
  _MiddlewareEntry(this.callback);
}
