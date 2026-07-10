import 'package:event_bus_riverpod/event_bus_riverpod.dart';

class EventBusConstants {
  static final onUpdateUser = EventBusIdentifier<User>("onUpdateUser");
  static SubEventIdentifier<User> onUpdateUserOf(String userId) =>
      SubEventIdentifier(
        userId,
        parentEvent: onUpdateUser,
        where: (user, _) => user.userId == userId,
      );
}

class User {
  final String userId;
  final String? name;
  User(this.userId, {this.name});
}
