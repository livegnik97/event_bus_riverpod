import 'package:event_bus_riverpod/event_bus/event_bus_identifier.dart';
import 'package:event_bus_riverpod/event_bus/event_bus_provider.dart';
import 'package:event_bus_riverpod/utils/listener_disposable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class EventBusAction<T> {
  final EventBusIdentifier<T> event;

  EventBusAction({required this.event});

  ListenerDisposable listenManually(ListenerCallback<T> callback);

  void emit(T value);

  bool get hasClients;
}

class EventBusActionForRef<T> extends EventBusAction<T> {
  final Ref ref;

  EventBusActionForRef({required super.event, required this.ref});

  void listen(ListenerCallback<T> callback) {
    final bus = ref.read(eventBusProvider);
    bus.listen(ref, event.eventName, callback);
  }

  @override
  ListenerDisposable listenManually(ListenerCallback<T> callback) {
    final bus = ref.read(eventBusProvider);
    return bus.on(event.eventName, callback);
  }

  @override
  void emit(T value) {
    ref.read(eventBusProvider).emit(event.eventName, value);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).hasClients<T>(event.eventName);
  }
}

class EventBusActionForWidgetRef<T> extends EventBusAction<T> {
  final WidgetRef ref;

  EventBusActionForWidgetRef({required super.event, required this.ref});

  @override
  ListenerDisposable listenManually(ListenerCallback<T> callback) {
    final bus = ref.read(eventBusProvider);
    return bus.on(event.eventName, callback);
  }

  @override
  void emit(T value) {
    ref.read(eventBusProvider).emit(event.eventName, value);
  }

  @override
  bool get hasClients {
    return ref.read(eventBusProvider).hasClients<T>(event.eventName);
  }
}
