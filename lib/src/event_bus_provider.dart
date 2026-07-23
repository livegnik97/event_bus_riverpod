import 'dart:async';
import 'dart:developer';

import 'package:event_bus_riverpod/src/bus_metadata.dart';
import 'package:event_bus_riverpod/src/event_bus_singleton.dart';
import 'package:event_bus_riverpod/src/listener_disposable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'event_bus_definitions.dart';

final eventBusProvider = Provider<EventBusCore>((ref) {
  final bus = EventBusSingleton.getInstance().core;

  ref.onDispose(() {
    bus.clearAll();
  });

  return bus;
});
