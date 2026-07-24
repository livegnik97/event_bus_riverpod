## 3.0.0

* **16 — SubEvents**: `SubEventIdentifier.subEventName` renamed to `eventName` for consistency with the new `EventBusIdentifierBase<T>` they both extend. **Breaking change**.
* **20 — Global API**: use the event bus from anywhere without Riverpod — plain Dart classes, services, or repositories. `EventBusGlobal.event()` and `EventBusGlobal.subEvent()` work with the same singleton bus as `ref.event()`, so emits and listeners are shared across both worlds.
* **21 — EventBusBuilder**: new widget that rebuilds whenever an event or subEvent fires. Accepts both identifier types polymorphically. No subscription management needed — handles `initState`, `dispose`, and re-subscription on changes automatically.
* **19 — Logger interceptor**: `logEvents()` now supports **multiple independent callbacks** — each registration adds to a stack instead of replacing the previous one. Providers, widgets, and the global API can all log concurrently without overwriting each other. Each logger is cleaned up individually on dispose.
* **22 — `waitFor()`**: await the next emission as a `Future<T>` — ideal for navigation after login, waiting for a specific status, or any one-shot coordination. Available on events, subEvents, and the global API. Built-in 30-second timeout prevents hanging futures; supports `where` filter for conditional matching. Includes a `waitForWithMeta()` variant that returns `Future<(T, BusMetadata)>`.
* **Bug fixes**:
  * Fixed `SubEventAction.lastValue` and `SubEventAction.history` silently registering the subEvent as a side effect — reads are now pure lookups.
  * Fixed `emitAsync()` dropping events when an async middleware calls `next()` after an `await` — the middleware chain now awaits completion correctly.
  * Fixed `_subEventBackfilledNoMatch` not being cleaned up when a later parent emission matches the subEvent's `where` filter, preventing new sticky listeners from receiving the cached value.
  * Fixed `_tryDeliverSticky` and related methods silently swallowing all errors — now logged in debug mode, consistent with `_invokeListeners`.
  * Fixed `_removeSubEventListener` and `clearSubEvent` scanning all parent events to find a subKey — O(n) → O(1) via a reverse `_subKeyToParentKey` map.
  * Fixed `setHistorySize` being called on every `emit()` and `history` read — now no-op if the size is already set.
  * Fixed `EventBusBuilder` not passing `sticky` to `listenManually` on re-subscriptions, causing the `where` filter to be ignored for sticky delivery.
  * Fixed `EventBusCore.waitFor` and friends missing a default timeout — now consistent with the abstract class (30s default).
  * Removed unused `autoDispose` parameter from all `listen`/`listenAsync`/`listenWithMeta`/`listenAsyncWithMeta` methods in `EventBusCore` and their subEvent counterparts — always disposes on `ref.onDispose`.

## 2.9.3

* **Shortened package description** to stay within pub.dev's 180-character limit.
* **Added example directory** with a working Flutter app demonstrating event bus usage.
* **Fixed lint warnings** (`curly_braces_in_flow_control_structures`) in `_fireSubEvents` and `_fireSubEventsAsync`.

## 2.9.2

* **Logger interceptor**: global `ref.logEvents()` callback fires for every event emission before middlewares — value, name, and metadata included. Error-isolated. Auto-dispose for `Ref`, manual for `WidgetRef`. Documented in section "19. Logger interceptor".
* **Broadcast streams**: added `broadcast` parameter (`false` by default) to `stream()`, `streamWithMeta()`, `streamSubEvent()`, and `streamWithMetaSubEvent()`. When `true`, multiple subscribers can listen on the same stream without errors. Documented in section "8. Stream API — Broadcast mode".
* **`clearAllEvents()`**: new extension method on both `Ref` and `WidgetRef` that wipes all listeners, subEvent listeners, middlewares, sticky caches, and subEvent registrations in one call. Useful for fully resetting state during user logout or app teardown. Documented in section "9. Clear all listeners — Clear all events".
* **One-shot listeners (`listenOnce`)**: new `listenOnce()`/`listenOnceManually()` on events and subEvents — the listener fires on the next emission and immediately removes itself. Auto-dispose (`listenOnce`) for providers and manual (`listenOnceManually`) for widgets, both with sticky, where, metadata, priority, and error handling support.
* **Event history (last N values)**: new `history` getter on `EventBusAction<T>` and `SubEventAction<T>` that returns a circular buffer of the last N emitted values with their `BusMetadata`, configured via `EventBusIdentifier(historySize: N)`. `clearHistory()` empties the buffer without affecting listeners or sticky cache. SubEvents have their own independent history. Default is `0` (no history, zero overhead). Documented in section "18. Event history".
* **Better performance on default-priority listeners**: when every listener uses the default `priority: 0`, event delivery now runs in linear time instead of sorting — speeds up emissions for the vast majority of use cases.
* **Reduced code duplication and more consistent internals**: the action layer was refactored to share common logic via mixins, and the listener notification pipeline (sync, async, subEvents) was unified into a single internal function — less code, fewer bugs, and identical behavior across all event types.
* **Bug fixes**:
  * Fixed the `where` filter parameter being silently ignored when listening manually with metadata in async mode (`listenManuallyAsyncWithMeta`) — listeners would receive all events instead of only matching ones.
  * Fixed `emitAsync()` hanging forever when a middleware cancels the event by not calling `next()` — now resolves correctly without waiting for a cancelled event.
  * Fixed a rare edge case where removing listeners during cleanup could cause some internal entries to be skipped.
  * Fixed subEvents with a `where` filter that doesn't match the parent's last cached value repeatedly re-checking that same value on every new sticky subscription — now skips unnecessary checks when the parent value hasn't changed.

## 2.6.1

* **17 — `lastValue` getter on events and SubEvents**: read the last emitted value directly without subscribing. `EventBusAction<T>.lastValue` and `SubEventAction<T>.lastValue` return `T?` — the sticky-cached value or `null` if nothing has been emitted yet (or after `clearSticky()`). SubEvents auto-register and backfill on first access. See section 17 in README for examples.

## 2.6.0

* **16 — SubEvents**: filtered views of events with their own listener list, sticky cache, and a mandatory `where` predicate. Access via `ref.subEvent()` on both `Ref` and `WidgetRef`. Listen-only — no `emit()` or `emitAsync()` — auto-triggered when the parent event emits. Sticky cache is independent of the parent; backfills from the parent on first subscription. See section 16 in README for details and examples.

## 2.5.2

* **Removed `BusMetadataForEmit`**: `emit()` and `emitAsync()` now accept `source` and `extraData` as direct optional parameters instead of requiring a `BusMetadataForEmit` wrapper.

## 2.5.1

* **10 — Async listeners**: `listenAsync()` for async callbacks (API calls, DB ops) and `emitAsync()` that awaits all async listeners before resolving. Sync and async listeners can coexist.
* **11 — Sticky events**: cache the last emitted value and deliver it to new subscribers with `sticky: true` on all listen methods. New `clearSticky()` to clear the cache without removing listeners.
* **12 — Middleware pipeline**: intercept, transform, or cancel events before they reach listeners with `applyMiddleware()`. Each middleware can log, modify the value, or cancel by not calling `next()`. New `clearMiddlewares()` to remove all middlewares.
* **13 — Execution priority**: added `priority` parameter to all listen methods; higher values run first (default `0`, negative values supported).
* **14 — BusMetadata**: every emission carries an auto-generated `timestamp`; optionally attach a `source` and arbitrary `extraData` via `BusMetadataForEmit`. Access metadata with `*WithMeta` listener methods. Sticky cache preserves metadata alongside the value.
* **15 — Listener filter with `where`**: all listen methods accept a `where` predicate `bool Function(T value, BusMetadata metadata)` to conditionally receive emissions. Errors in `where` are caught and logged per-listener. Sticky delivery respects the filter.
* **Bugs fixed**:
  * Fixed memory leak in `stream()` — `_ListenerEntry` was added to `_listeners` immediately even if no one subscribed to the stream; now added only on `onListen` of `StreamController`.
  * Removed dead `onError` parameter from `stream()` — the callback never throws (`controller.add`), so the parameter was misleading.
  * Fixed `hasClients` getter mutating internal state — disposed listener cleanup moved out of the getter.
* **Improvements**:
  * `ListenerDisposable` replaced `dart:ui` `VoidCallback` with `void Function()` — removes unnecessary dependency.
  * Added `toString()` to `EventBusIdentifier<T>` — easier debugging and logging.
  * Cached `_key` in `EventBusIdentifier` — `_buildKey` no longer recalculates the hash on every call.
  * Updated API documentation with examples for all new parameters.

## 1.6.2

* **Error handling**: added `onError` callback to `listen()`, `listenManually()`, and `stream()` for per-listener error handling. Errors are logged via `log()` in debug mode when no `onError` is provided.
* **Stream API**: added `stream()` method to expose events as `Stream<T>` for `StreamBuilder`, stream composition (`.where()`, `.map()`), and Riverpod memoization.
* **Key routing**: stored `Type` in `EventBusIdentifier<T>` and switched to `Object.hash(eventName, T)` for robust, platform-independent key generation (replaced fragile `T.toString()`).
* **Clear listeners**: added `clearListeners()` to remove all listeners of a specific event without affecting others.
* Updated README with documentation and examples for all new features.

## 1.2.5

* Updated README with additional information.

## 1.2.4

* Added API documentation comments with example code above every function in `EventBusAction`, `EventBusActionForRef`, and `EventBusActionForWidgetRef`.

## 1.2.3

* **Internal reorganization**: moved implementation files to `lib/src/` to make them package-private. Only `event_bus_riverpod.dart` is now importable from outside the package.

## 1.2.2

* Bumped minimum required `flutter_riverpod` version down to `>=3.0.0`.

## 1.2.1

* Added pub.dev link to README.

## 1.2.0

* Initial release of the `event_bus_riverpod` package.
* **Typed event bus**: `EventBusIdentifier<T>` to define type-safe events.
* **Dual context**: `EventBusForRef` and `EventBusForWidgetRef` extensions for `Ref` and `WidgetRef`.
* **Lifecycle management**: auto-dispose subscription via `ref.onDispose` and manual subscription with `ListenerDisposable`.
* **Emit and inspect**: `emit()` to fire events and `hasClients` to check for active subscribers.
