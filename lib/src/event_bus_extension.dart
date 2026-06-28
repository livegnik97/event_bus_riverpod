import 'package:event_bus_riverpod/src/event_bus_action.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension EventBusForRef on Ref {
  EventBusActionForRef<T> event<T>(EventBusIdentifier<T> event) =>
      EventBusActionForRef<T>(event: event, ref: this);
}

extension EventBusForWidgetRef on WidgetRef {
  EventBusActionForWidgetRef<T> event<T>(EventBusIdentifier<T> event) =>
      EventBusActionForWidgetRef<T>(event: event, ref: this);
}
