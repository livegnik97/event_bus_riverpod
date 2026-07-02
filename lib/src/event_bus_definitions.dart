part of './event_bus_provider.dart';

// Definimos el tipo de callback genérico
typedef ListenerCallback<T> = void Function(T value);
typedef ListenerCallbackAsync<T> = Future<void> Function(T value);

class _EventBus {
  final Map<int, List<_ListenerEntry>> _listeners = {};

  void listen<T>(
    Ref ref,
    int key,
    ListenerCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
  }) {
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
  }) {
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
  }) {
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
  }) {
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

  void emit<T>(int key, T value) {
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

  Future<void> emitAsync<T>(int key, T value) async {
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

  void clearAll() => _listeners.clear();
}

class _ListenerEntry {
  final dynamic callback;
  final void Function(Object, StackTrace)? onError;
  bool isDisposed = false;
  bool isAsync = false;

  _ListenerEntry(this.callback, {this.onError, this.isAsync = false});

  void markAsDisposed() => isDisposed = true;
}
