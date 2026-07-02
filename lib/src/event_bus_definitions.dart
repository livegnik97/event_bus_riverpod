part of './event_bus_provider.dart';

// Definimos el tipo de callback genérico
typedef ListenerCallback<T> = void Function(T value);

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
      // Se limpia automáticamente cuando el provider que se suscribió es destruido
      ref.onDispose(() {
        _removeListener(key, entry);
      });
    }
  }

  // Versión manual que devuelve un disposer
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

  // Emitir evento
  void emit<T>(int key, T value) {
    final listeners = _listeners[key];

    if (listeners != null) {
      // Ejecutamos todos los callbacks
      for (final entry in List.from(listeners)) {
        if (!entry.isDisposed) {
          try {
            entry.callback(value);
          } catch (e, st) {
            try {
              if (entry.onError != null) {
                entry.onError!(e, st);
              } else if (kDebugMode) {
                log('[event_bus_riverpod] Error in listener: $e\n$st');
              }
            } catch (e, st) {
              if (kDebugMode) {
                log('[event_bus_riverpod] Error in onError: $e\n$st');
              }
            }
          }
        }
      }

      // Limpiamos listeners que se marcaron como desechados
      listeners.removeWhere((entry) => entry.isDisposed);
      if (listeners.isEmpty) {
        _listeners.remove(key);
      }
    }
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

// Clase interna para trackear el estado de los listeners
class _ListenerEntry {
  final dynamic callback;
  final void Function(Object, StackTrace)? onError;
  bool isDisposed = false;

  _ListenerEntry(this.callback, {this.onError});

  void markAsDisposed() => isDisposed = true;
}
