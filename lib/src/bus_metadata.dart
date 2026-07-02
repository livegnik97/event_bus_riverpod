class BusMetadataForEmit {
  final String? source;
  final dynamic extraData;

  const BusMetadataForEmit({this.source, this.extraData});
}

class BusMetadata {
  final DateTime timestamp;
  final String? source;
  final dynamic extraData;

  const BusMetadata({
    required this.timestamp,
    this.source,
    this.extraData,
  });
}
