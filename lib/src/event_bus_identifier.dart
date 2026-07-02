class EventBusIdentifier<T> {
  final String eventName;
  EventBusIdentifier(this.eventName);
  Type get type => T;

  int? _key;
  int get key => _key ??= Object.hash(eventName, T);

  @override
  String toString() => 'EventBusIdentifier($eventName, $T)';
}
