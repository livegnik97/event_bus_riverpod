## 1.2.0

* Initial release of the event_bus_riverpod package.
* Typed event bus system integrated with Riverpod.
* `EventBusForRef` and `EventBusForWidgetRef` extensions for `Ref` and `WidgetRef`.
* `EventBusIdentifier<T>` to define type-safe events.
* Auto-dispose subscription via `autoDispose` and manual subscription with `ListenerDisposable`.
* `emit` method to fire events and `hasClients` to check for active subscribers.
