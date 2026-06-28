import 'package:event_bus_riverpod/utils/listener_disposable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part './event_bus_definitions.dart';

final eventBusProvider = Provider<_EventBus>((ref) {
  final bus = _EventBus();

  ref.onDispose(() {
    bus.clearAll();
  });

  return bus;
});
