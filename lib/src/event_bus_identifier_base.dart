abstract class EventBusIdentifierBase<T> {
  String get eventName;
  Type get type;
  int get key;
  int get historySize;
}
