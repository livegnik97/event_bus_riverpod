## 2.5.1

* All features from README sections 11 through 15:
* **11 — Sticky events**: cache the last emitted value and deliver it to new subscribers with `sticky: true` on all listen methods. New `clearSticky()` to clear the cache without removing listeners.
* **12 — Middleware pipeline**: intercept, transform, or cancel events before they reach listeners with `applyMiddleware()`. Each middleware can log, modify the value, or cancel by not calling `next()`. New `clearMiddlewares()` to remove all middlewares.
* **13 — Execution priority**: added `priority` parameter to all listen methods; higher values run first (default `0`), negative values supported.
* **14 — BusMetadata**: every emission carries an auto-generated `timestamp`; optionally attach a `source` and arbitrary `extraData` via `BusMetadataForEmit`. Access metadata with `*WithMeta` listener methods. `emit()` and `emitAsync()` accept an optional `metadata:` argument. Sticky cache preserves metadata.
* **15 — Listener filter with `where`**: all listen methods accept a `where` predicate `bool Function(T value, BusMetadata metadata)` to conditionally receive emissions. Errors in `where` are caught and logged per-listener. Sticky delivery respects the filter.
* Safer sticky delivery — all sticky callback invocations are wrapped in `try/catch`.
* Updated API documentation with examples for all new parameters.

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
