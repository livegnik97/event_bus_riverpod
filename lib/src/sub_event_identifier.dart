import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier_base.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';

class SubEventIdentifier<T> extends EventBusIdentifierBase<T> {
  final EventBusIdentifier<T> parentEvent;
  @override
  final String eventName;
  final ListenerWhere<T> where;
  @override
  final int historySize;

  SubEventIdentifier(
    this.eventName, {
    required this.parentEvent,
    required this.where,
    this.historySize = 0,
  }) : assert(historySize >= 0);

  @override
  Type get type => T;

  int? _key;
  @override
  int get key => _key ??= Object.hash(parentEvent.key, eventName);

  @override
  String toString() =>
      'SubEventIdentifier(${parentEvent.eventName}.$eventName, $T)';
}
