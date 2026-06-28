import 'package:event_bus_riverpod/event_bus_riverpod.dart';

class EventBusConstants {
  static final onPossibleString = EventBusIdentifier<String?>(
    "onPossibleString",
  );
  static final onSecureInt = EventBusIdentifier<int>("onSecureInt");
  static final onUserName = EventBusIdentifier<String>("onUserName");
  static final onUserAge = EventBusIdentifier<int>("onUserAge");
  static final onLoginStatus = EventBusIdentifier<bool>("onLoginStatus");
}
