import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';

class SubEventIdentifier<T> {
  final EventBusIdentifier<T> parentEvent;
  final String subEventName;
  final ListenerWhere<T> where;
  final int historySize;

  SubEventIdentifier(
    this.subEventName, {
    required this.parentEvent,
    required this.where,
    this.historySize = 0,
  }) : assert(historySize >= 0);

  int? _key;
  int get key => _key ??= Object.hash(parentEvent.key, subEventName);

  @override
  String toString() =>
      'SubEventIdentifier(${parentEvent.eventName}.$subEventName, $T)';
}
