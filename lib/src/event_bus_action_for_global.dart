import 'package:event_bus_riverpod/src/event_bus_action.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';
import 'package:event_bus_riverpod/src/event_bus_singleton.dart';
import 'package:event_bus_riverpod/src/sub_event_action.dart';

/// [EventBusAction] implementation that uses the global
/// [EventBusSingleton] instead of a Riverpod [Ref].
class EventBusActionForGlobal<T> extends EventBusAction<T>
    with EventBusActionMixin<T> {
  EventBusActionForGlobal({required super.event});

  @override
  EventBusCore get eventBus => EventBusSingleton.getInstance().core;
}

/// [SubEventAction] implementation that uses the global
/// [EventBusSingleton] instead of a Riverpod [Ref].
class SubEventActionForGlobal<T> extends SubEventAction<T>
    with SubEventActionMixin<T> {
  SubEventActionForGlobal({required super.identifier}) {
    eventBus.setHistorySize(identifier.key, identifier.historySize);
    eventBus.initSubEvent(
      identifier.key,
      identifier.parentEvent.key,
      identifier.where,
    );
  }

  @override
  EventBusCore get eventBus => EventBusSingleton.getInstance().core;
}
