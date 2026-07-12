import 'package:event_bus_riverpod/event_bus_riverpod.dart';

class EventBusConstants {
  static final onPossibleString = EventBusIdentifier<String?>(
    "onPossibleString",
  );
  static final onSecureInt = EventBusIdentifier<int>("onSecureInt");
  static final onUserName = EventBusIdentifier<String>("onUserName");
  static final onUserAge = EventBusIdentifier<int>("onUserAge");
  static final onLoginStatus = EventBusIdentifier<bool>("onLoginStatus");
  static final onHistoryInt = EventBusIdentifier<int>(
    "onHistoryInt",
    historySize: 5,
  );

  // SubEvents
  static final evenSecureInt = SubEventIdentifier<int>(
    'even',
    parentEvent: onSecureInt,
    where: (v, _) => v.isEven,
  );
  static final positiveInt = SubEventIdentifier<int>(
    'positive',
    parentEvent: onSecureInt,
    where: (v, _) => v > 0,
  );
  static final historyEvenInt = SubEventIdentifier<int>(
    'historyEven',
    parentEvent: onHistoryInt,
    where: (v, _) => v.isEven,
    historySize: 3,
  );
}
