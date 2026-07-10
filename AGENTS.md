# AGENTS.md — event_bus_riverpod

## Project structure

Single pub package (`pubspec.yaml`), not a monorepo. No codegen, build_runner, or CI workflows.

- **Entrypoint**: `lib/event_bus_riverpod.dart` — re-exports 7 files from `lib/src/`
- **Core bus**: `lib/src/event_bus_definitions.dart` (part of `event_bus_provider.dart`) contains `_EventBus` and `_ListenerEntry`
- **Provider**: `eventBusProvider` is `Provider<_EventBus>` in `event_bus_provider.dart`
- **Public API**: `EventBusAction` abstract class; two impls — `EventBusActionForRef` (auto-dispose via `ref.onDispose`) and `EventBusActionForWidgetRef` (manual only)
- **SubEvent API**: `SubEventAction` abstract class; two impls — `SubEventActionForRef` (auto-dispose via `ref.onDispose`) and `SubEventActionForWidgetRef` (manual only). No `emit()` / `emitAsync()` / `applyMiddleware()`.
- **Extensions** on `Ref` and `WidgetRef` provide the `.event()` and `.subEvent()` methods
- **Event routing**: `EventBusIdentifier<T>` uses `Object.hash(eventName, T)` as the internal key (not string interpolation)
- **SubEvents**: `SubEventIdentifier<T>` creates a filtered view of a parent event with a **mandatory** `where` predicate and its own `subEventName`. Accessed via `ref.subEvent(...)`. Has its own listener list and sticky cache (`_subEventLastValues`), independent from the parent. Auto-triggered when the parent emits. Backfills sticky cache from parent on first registration. Internal key: `Object.hash(parentKey, subEventName)`.

## Key API split

| Context | Auto-dispose listen | Manual listen |
|---------|-------------------|---------------|
| Inside a provider (`Ref`) — **event** | `.listen()` / `.listenAsync()` / `.listenWithMeta()` | `.listenManually*()` |
| Inside a provider (`Ref`) — **subEvent** | `.listen()` / `.listenAsync()` / `.listenWithMeta()` | `.listenManually*()` |
| Inside a widget (`WidgetRef`) — **event** | ❌ none | `.listenManually*()` only |
| Inside a widget (`WidgetRef`) — **subEvent** | ❌ none | `.listenManually*()` only |

`WidgetRef` has no `onDispose`, so auto-dispose methods are intentionally absent.

## Commands

```sh
flutter test                    # single test file: test/event_bus_riverpod_test.dart
flutter test --reporter expanded # verbose test output
flutter analyze                 # lint (uses flutter_lints default rules)
```

## Test conventions

- Single test file `test/event_bus_riverpod_test.dart` (~1838 lines) with shared `test/event_bus_constants.dart`
- Tests use `ProviderContainer` directly (not `WidgetTester`) — pure Riverpod, no widget tree
- Pattern: `container.read(Provider<EventBusActionForRef<T>>((ref) => ref.event(constant)))` to obtain the action, then `container.read(listenerProvider)` to register
- Stream tests require `await Future(() {})` to flush microtask-delivered events
- No integration tests, no service dependencies

## Notable conventions

- `FEATURE_request_*.md` files in root are feature proposals, not implemented code
- Error isolation is built-in: a failing listener never breaks others; use `onError` callback per-listener
- Sticky cache stores the value **post-middleware**; middleware cancellation also prevents caching
- `List.forEach().any()` in `hasClients` (not raw iterable `.any()`) — mutation safety
