class EventBusIdentifier<T> {
  final String eventName;
  EventBusIdentifier(this.eventName);
  Type get type => T;
}
