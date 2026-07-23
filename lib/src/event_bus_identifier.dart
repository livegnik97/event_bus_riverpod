import 'package:event_bus_riverpod/src/event_bus_identifier_base.dart';

class EventBusIdentifier<T> extends EventBusIdentifierBase<T> {
  @override
  final String eventName;
  @override
  final int historySize;
  EventBusIdentifier(this.eventName, {this.historySize = 0})
    : assert(historySize >= 0);
  @override
  Type get type => T;

  int? _key;
  @override
  int get key => _key ??= Object.hash(eventName, T);

  @override
  String toString() => 'EventBusIdentifier($eventName, $T)';
}
