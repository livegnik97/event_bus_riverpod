class EventBusIdentifier<T> {
  final String eventName;
  final int historySize;
  EventBusIdentifier(this.eventName, {this.historySize = 0})
    : assert(historySize >= 0);
  Type get type => T;

  int? _key;
  int get key => _key ??= Object.hash(eventName, T);

  @override
  String toString() => 'EventBusIdentifier($eventName, $T)';
}
