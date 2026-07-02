part of './event_bus_provider.dart';

// Definimos el tipo de callback genérico
typedef ListenerCallback<T> = void Function(T value);

class _EventBus {
  final Map<String, List<_ListenerEntry>> _listeners = {};

  void listen<T>(
    Ref ref,
    String eventName,
    ListenerCallback<T> callback, {
    bool autoDispose = true,
    void Function(Object, StackTrace)? onError,
  }) {
    final key = _buildKey<T>(eventName);
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
    String eventName,
    ListenerCallback<T> callback, {
    void Function(Object, StackTrace)? onError,
  }) {
    final key = _buildKey<T>(eventName);
    final entry = _ListenerEntry(callback, onError: onError);

    _listeners.putIfAbsent(key, () => []).add(entry);

    return ListenerDisposable(() {
      _removeListener(key, entry);
    });
  }

  // Emitir evento
  void emit<T>(String eventName, T value) {
    final key = _buildKey<T>(eventName);
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
            } catch (_) {}
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

  bool hasClients<T>(String eventName) {
    final key = _buildKey<T>(eventName);
    final listeners = _listeners[key];
    if (listeners != null && listeners.isNotEmpty) {
      // Limpiamos listeners que se marcaron como desechados
      listeners.removeWhere((entry) => entry.isDisposed);
      if (listeners.isEmpty) {
        _listeners.remove(key);
      }
      return listeners.isNotEmpty;
    }
    return false;
  }

  void _removeListener(String key, _ListenerEntry entry) {
    entry.markAsDisposed();
    _listeners[key]?.remove(entry);
    if (_listeners[key]?.isEmpty ?? false) {
      _listeners.remove(key);
    }
  }

  String _buildKey<T>(String eventName) => '$eventName${T.toString()}';

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
