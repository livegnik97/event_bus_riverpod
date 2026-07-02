## 1.6.2

* Added `onError` callback to `listen()`, `listenManually()`, and `stream()` for per-listener error handling.
  Errors are logged via `log()` in debug mode when no `onError` is provided.
* Added `stream()` method to expose events as `Stream<T>` for `StreamBuilder`, stream composition (`.where()`,
  `.map()`), and Riverpod memoization.
* Stored `Type` in `EventBusIdentifier<T>` and switched to `Object.hash(eventName, T)` for robust,
  platform-independent key routing (replaced fragile `T.toString()`).
* Added `clearListeners()` to remove all listeners of a specific event without affecting others.
* Updated README with documentation and examples for all new features.

## 1.2.5

* Added more information to README.

## 1.2.4

* Added API documentation comments with example code above every function in `EventBusAction`, `EventBusActionForRef`, and `EventBusActionForWidgetRef`.

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
