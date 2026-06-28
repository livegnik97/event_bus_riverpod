## 1.2.3

* Reorganized internal structure: moved implementation files to `lib/src/` to make them package-private.
* Only `event_bus_riverpod.dart` is now importable from outside the package.

## 1.2.2

* Bumped down minimum required riverpod version to 3.0.0.

## 1.2.1

* Added pub.dev link to README.

## 1.2.0

* Initial release of the event_bus_riverpod package.
* Typed event bus system integrated with Riverpod.
* `EventBusForRef` and `EventBusForWidgetRef` extensions for `Ref` and `WidgetRef`.
* `EventBusIdentifier<T>` to define type-safe events.
* Auto-dispose subscription via `autoDispose` and manual subscription with `ListenerDisposable`.
* `emit` method to fire events and `hasClients` to check for active subscribers.
