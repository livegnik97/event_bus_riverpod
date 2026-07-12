class BusMetadata {
  final DateTime timestamp;
  final String? source;
  final dynamic extraData;

  const BusMetadata({required this.timestamp, this.source, this.extraData});
}

class ValueWithMeta<T> {
  final T value;
  final BusMetadata metadata;

  const ValueWithMeta(this.value, this.metadata);
}
