import 'package:event_bus_riverpod/src/event_bus_provider.dart';
import 'package:flutter/foundation.dart';

class EventBusSingleton {
  static EventBusSingleton? _instance;

  EventBusSingleton._();

  static EventBusSingleton getInstance() {
    _instance ??= EventBusSingleton._();
    return _instance!;
  }

  final EventBusCore core = EventBusCore();

  @visibleForTesting
  static void reset() => _instance = null;
}
