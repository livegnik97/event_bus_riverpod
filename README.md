# event_bus_riverpod

[![pub package](https://img.shields.io/pub/v/event_bus_riverpod.svg)](https://pub.dev/packages/event_bus_riverpod)

A type-safe, Riverpod-integrated event bus for Flutter. It allows you to emit and listen to events anywhere in your app using Riverpod's dependency injection and lifecycle management.

## What is the best use for this package?

Imagine you have an app that displays store products to the user. On the main page, you have three independent lists showing the most popular, best-selling, and newest products. Tapping a product takes you to the details screen.

**What happens if you add the product to the cart from that details screen, or from one of the lists?**

**What if, on the product details screen, you fetch updated product information that differs from what you currently have?**

**How would you update that product's information everywhere it appears?**

You might devise a solution that ends up creating dependencies between Riverpod providers or other classes. However, with this library, you simply need to have each provider listen for events—such as an update to product X or product Y being added to or removed from the cart—receiving the data needed to manually update your list or details screen. You emit these events whenever changes occur, and—magically—the product appears updated everywhere.

Easy, simple, and fast.

## Features

- **Type-safe events** – each event carries a generic type `T`, preventing type mismatches
- **Auto-dispose** – listeners tied to a `Ref` are automatically cleaned up when the provider is destroyed
- **Manual lifecycle** – subscribe/unsubscribe manually with `ListenerDisposable`
- **Async support** – `listenAsync()` / `emitAsync()` for listeners that need to await async work (API calls, DB operations)
- **Dual context** – extensions on both `Ref` and `WidgetRef`
- **Multiple listeners** – many listeners can subscribe to the same event
- **Error isolation** – a failing callback never breaks other listeners
- **Error handling** – catch errors per-listener with `onError` callback (sync and async)
- **Stream API** – consume events as a `Stream<T>` (or `Stream<(T, BusMetadata)>` with `streamWithMeta()`) for composition and `StreamBuilder`; supports broadcast mode for multiple subscribers via `stream(broadcast: true)`
- **Robust key routing** – events are internally routed with `Type` hashing instead of string interpolation, ensuring platform-independent key generation
- **Sticky events** – cache the last emitted value and deliver it to new subscribers with `sticky: true`; read it anytime via `lastValue` without subscribing
- **Middleware pipeline** – intercept, transform, or cancel events before they reach listeners with `applyMiddleware()`
- **Execution priority** – control listener order with the `priority` parameter (higher values run first); defaults to `0`
- **BusMetadata** – every emission carries an auto-generated `timestamp`; optionally attach a `source` identifier and arbitrary extra data; access via `*WithMeta` listener methods
- **Listener filter** – filter which emissions reach a listener with the `where` parameter, using the value and/or its metadata
- **SubEvents** – create filtered views of events with their own sticky cache and listener list using a mandatory `where` predicate; accessed via `ref.subEvent()`
- **Full reset** – wipe all listeners, sticky caches, middlewares, and subEvents at once with `ref.clearAllEvents()`
- **Global API** – use the event bus from anywhere without Riverpod with `EventBusGlobal.event()` / `EventBusGlobal.subEvent()`, backed by the same singleton bus that powers `ref.event()`
- **EventBusBuilder widget** – a `ConsumerStatefulWidget` that rebuilds whenever an event is emitted; accepts both `EventBusIdentifier` and `SubEventIdentifier` polymorphically via `EventBusIdentifierBase`

## Table of Contents

- [event\_bus\_riverpod](#event_bus_riverpod)
  - [What is the best use for this package?](#what-is-the-best-use-for-this-package)
  - [Features](#features)
  - [Table of Contents](#table-of-contents)
  - [Installing](#installing)
  - [Usage](#usage)
    - [1. Define an event identifier](#1-define-an-event-identifier)
    - [2. Listen and emit inside a provider](#2-listen-and-emit-inside-a-provider)
    - [3. Listen and emit inside a widget with `WidgetRef`](#3-listen-and-emit-inside-a-widget-with-widgetref)
    - [4. Manual subscription with `listenManually()`](#4-manual-subscription-with-listenmanually)
    - [5. Check if an event has active listeners](#5-check-if-an-event-has-active-listeners)
    - [6. Null-safe events](#6-null-safe-events)
    - [7. Error handling with `onError`](#7-error-handling-with-onerror)
    - [8. Stream API](#8-stream-api)
      - [Broadcast mode](#broadcast-mode)
      - [Recipe: event as a reactive Riverpod provider](#recipe-event-as-a-reactive-riverpod-provider)
    - [9. Clear all listeners of an event](#9-clear-all-listeners-of-an-event)
      - [Clear all events](#clear-all-events)
    - [10. Async listeners](#10-async-listeners)
    - [11. Sticky events (last value cache)](#11-sticky-events-last-value-cache)
      - [Last value (unsubscribed access)](#last-value-unsubscribed-access)
    - [12. Middleware pipeline](#12-middleware-pipeline)
    - [13. Execution priority](#13-execution-priority)
    - [14. BusMetadata (emission metadata)](#14-busmetadata-emission-metadata)
      - [Emitting with metadata](#emitting-with-metadata)
      - [Listening with metadata](#listening-with-metadata)
      - [Practical scenario: audit trail](#practical-scenario-audit-trail)
      - [Sticky + metadata](#sticky--metadata)
      - [Metadata API reference](#metadata-api-reference)
    - [15. Listener filter with `where`](#15-listener-filter-with-where)
    - [16. SubEvents](#16-subevents)
    - [17. One-shot listeners (`listenOnce`)](#17-one-shot-listeners-listenonce)
    - [18. Event history (last N values)](#18-event-history-last-n-values)
    - [19. Logger interceptor](#19-logger-interceptor)
      - [What gets logged](#what-gets-logged)
      - [Error isolation](#error-isolation)
      - [When used with SubEvents](#when-used-with-subevents)
    - [20. Global API (without Riverpod)](#20-global-api-without-riverpod)
    - [21. EventBusBuilder widget](#21-eventbusbuilder-widget)
    - [22. Await the next emission with `waitFor()`](#22-await-the-next-emission-with-waitfor)

## Installing

Add the package from [pub.dev](https://pub.dev/packages/event_bus_riverpod):

```yaml
dependencies:
  event_bus_riverpod: ^3.0.0
  flutter_riverpod: ^3.0.0
```

## Usage

### 1. Define an event identifier

Create a typed identifier for each event. The generic type `T` is the payload type.

```dart
import 'package:event_bus_riverpod/event_bus_riverpod.dart';

class EventBusConstants {
    static final onUserNameChanged = EventBusIdentifier<String>('onUserNameChanged');
    static final onUserAgeChanged = EventBusIdentifier<int>('onUserAgeChanged');
    static final onLoginStatusChanged = EventBusIdentifier<bool>('onLoginStatusChanged');
}
```

### 2. Listen and emit inside a provider

Use the `ref.event()` extension to get an action object, then call `listen()` or `emit()`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:event_bus_riverpod/event_bus_riverpod.dart';

// This provider listens for changes and updates state
final userListenerProvider = Provider<void>((ref) {
  ref.event(EventBusConstants.onUserNameChanged).listen((name) {
    // Update state
  });
});
```

```dart
class UserInputWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onSubmitted: (value) {
        // Emit the event — all active listeners will be notified
        ref.event(EventBusConstants.onUserNameChanged).emit(value);
      },
    );
  }
}
```

### 3. Listen and emit inside a widget with `WidgetRef`

The same API works directly in widgets via the `WidgetRef.event()` extension.

```dart
class UserNameDisplay extends ConsumerStatefulWidget {
  const UserNameDisplay({super.key});

  @override
  _UserNameDisplayState createState() => _UserNameDisplayState();
}

class _UserNameDisplayState extends ConsumerState<UserNameDisplay> {
  final String _name = '';

  @override
  void initState() {
    super.initState();

    // Use WidgetRef.event().listen() — lifecycle is NOT auto-managed here
    // because WidgetRef has no onDispose. Use listenManually instead.
  }

  @override
  Widget build(BuildContext context) {
    return Text('User: $_name');
  }
}
```

### 4. Manual subscription with `listenManually()`

When you are not inside a provider (e.g., in a widget or a plain Dart class), use `listenManually()`. It returns a `ListenerDisposable` you must call `dispose()` on to unsubscribe.

```dart
class _MyWidgetState extends ConsumerState<MyWidget> {
  ListenerDisposable? _disposable;

  @override
  void initState() {
    super.initState();
    _disposable = ref.event(EventBusConstants.onUserAgeChanged).listenManually((age) {
      print('Age changed to $age');
    });
  }

  @override
  void dispose() {
    _disposable?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => ref.event(EventBusConstants.onUserAgeChanged).emit(30),
      child: const Text('Set age to 30'),
    );
  }
}
```

### 5. Check if an event has active listeners

```dart
if (ref.event(EventBusConstants.onLoginStatusChanged).hasClients) {
  ref.event(EventBusConstants.onLoginStatusChanged).emit(true);
}
```

### 6. Null-safe events

Nullable types are fully supported.

```dart
final onNullable = EventBusIdentifier<String?>('onNullable');

ref.event(onNullable).listen((value) {
  print(value); // can be null or String
});

ref.event(onNullable).emit(null);
```

### 7. Error handling with `onError`

When a listener throws, other listeners are not affected. You can catch errors per-listener with `onError`:

```dart
ref.event(EventBusConstants.onUserAgeChanged).listen((age) {
  if (age < 0) throw Exception('Invalid age: $age');
}, onError: (error, stackTrace) {
  log('Listener failed: $error', stackTrace: stackTrace);
});
```

If no `onError` is provided, errors are logged to the console in debug mode via `log()`:

```dart
ref.event(EventBusConstants.onUserAgeChanged).listen((age) {
  // If this throws, a warning is printed in debug mode
});
```

The `onError` parameter is also available on `listenManually()`:

```dart
final disposable = ref.event(EventBusConstants.onUserAgeChanged).listenManually((age) {
  throw Exception('Oops');
}, onError: (error, stackTrace) {
  print('Caught: $error');
});
```

### 8. Stream API

Each event can be consumed as a `Stream<T>`, enabling stream composition and `StreamBuilder` widgets.

```dart
// StreamBuilder
StreamBuilder<int>(
  stream: ref.event(EventBusConstants.onUserAgeChanged).stream(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const Text('No data');
    return Text('Age: ${snapshot.data}');
  },
);
```

```dart
// Stream composition
ref.event(EventBusConstants.onUserAgeChanged).stream()
  .where((age) => age >= 18)
  .map((age) => 'Adult aged $age')
  .listen((msg) => print(msg));
```

```dart
// Inside a provider (memoized via Riverpod)
final ageStreamProvider = Provider<Stream<int>>((ref) {
  return ref.event(EventBusConstants.onUserAgeChanged).stream();
});
```

```dart
// Catch errors using standard stream error handling
ref.event(EventBusConstants.onUserAgeChanged).stream()
  .listen(
    (age) => print('Age: $age'),
    onError: (error, stackTrace) {
      log('Stream error: $error', stackTrace: stackTrace);
    },
  );

// Or use handleError for composition
ref.event(EventBusConstants.onUserAgeChanged).stream()
  .handleError((error) => log('Error: $error'))
  .listen((age) => print('Age: $age'));
```

#### Broadcast mode

By default, `stream()` returns a **single-subscription** stream — calling `.listen()` more than once throws a `BadState` error. The `broadcast` parameter (`false` by default) changes the underlying `StreamController` to broadcast mode, allowing multiple subscribers on the same stream.

```dart
final stream = ref.event(onCounter).stream(broadcast: true);

// Multiple subscribers — no error
stream.listen((v) => print('Listener 1: $v'));
stream.listen((v) => print('Listener 2: $v'));
```

Multiple subscribers share a single internal `_ListenerEntry` — only one entry is registered in the bus regardless of how many `.listen()` calls are made:

```dart
// Single-subscription — only one .listen() allowed
final single = ref.event(onCounter).stream();
single.listen(print);
single.listen(print); // 💥 Bad state

// Broadcast — multiple .listen() allowed
final multi = ref.event(onCounter).stream(broadcast: true);
multi.listen(print); // subscriber 1
multi.listen(print); // subscriber 2 — both receive events
```

The `broadcast` parameter is available on all stream methods:

| Method | `broadcast` param |
|--------|-------------------|
| `stream()` | ✅ |
| `streamWithMeta()` | ✅ |
| `streamSubEvent()` | ✅ |
| `streamWithMetaSubEvent()` | ✅ |

Stream methods also support `sticky`, `priority`, and `where` — see their respective sections for details.

#### Recipe: event as a reactive Riverpod provider

Wrap the stream in a `StreamProvider` to make any event a reactive provider:

```dart
final counterProvider = StreamProvider<int>((ref) {
  return ref.event(onCounter).stream(broadcast: true);
});
```

Consume it with `ref.watch()` — the widget rebuilds on every emission:

```dart
class CounterBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(counterProvider);
    return Badge(
      label: Text('${asyncValue.valueOrNull ?? 0}'),
    );
  }
}
```

Pass `sticky: true` on the stream and use `lastValue` as `initialData` to start with the cached value before the first emission arrives:

```dart
final counterProvider = StreamProvider<int>((ref) {
  return ref.event(onCounter).stream(sticky: true, broadcast: true);
}, initialData: ref.event(onCounter).lastValue);
```

### 9. Clear all listeners of an event

Use `clearListeners()` to remove all listeners registered for a specific event without affecting other events or the bus itself.

```dart
ref.event(EventBusConstants.onUserAgeChanged).listen((age) {
  print('Age: $age');
});

ref.event(EventBusConstants.onUserAgeChanged).listen((age) {
  print('Age again: $age');
});

// Remove all listeners for onUserAgeChanged
ref.event(EventBusConstants.onUserAgeChanged).clearListeners();

// Other events remain unaffected
ref.event(EventBusConstants.onUserNameChanged).listen((name) {
  print('Name: $name');
});
```

After calling `clearListeners()`, the event no longer has active listeners:

```dart
print(ref.event(EventBusConstants.onUserAgeChanged).hasClients); // false
```

#### Clear all events

To wipe the **entire bus** — all listeners, subEvent listeners, middlewares, sticky caches, and subEvent registrations — use `clearAllEvents()`. This is useful during user logout or full app reset.

```dart
class LogoutNotifier extends Notifier<void> {
  Future<void> logout() async {
    await _api.logout();
    ref.clearAllEvents();
    // Now every event and subEvent is clean: no listeners, no cached
    // values, no middlewares. Providers with auto-dispose will
    // re-register when rebuilt; manual listeners need re-subscription.
  }
}
```

```dart
// Available on both Ref and WidgetRef
ref.clearAllEvents();           // Ref
context.clearAllEvents();       // WidgetRef (inside a widget)
```

Internally `clearAllEvents()` clears listeners, sticky caches, middlewares, subEvent listeners, subEvent sticky caches, and subEvent registrations across all events.

### 10. Async listeners

When a listener needs to perform asynchronous work (e.g., API calls, database operations), use `listenAsync()` instead of `listen()`. The event bus tracks async listeners separately and exposes `emitAsync()` that **awaits all async listeners** before resolving.

**Scenario**: After a user logs in, multiple providers need to fetch data (cart, preferences, notifications) before navigating to the home screen.

```dart
// Define the event
final onUserLogin = EventBusIdentifier<User>('onUserLogin');

// Login provider — emit and wait
final loginProvider = Provider.notifier<LoginNotifier>((ref) {
  return LoginNotifier(ref);
});

class LoginNotifier {
  final Ref ref;
  LoginNotifier(this.ref);

  Future<void> login(String email, String password) async {
    final user = await _api.login(email, password);
    await ref.event(onUserLogin).emitAsync(user); // ✅ waits for all listeners
    navigateToHome(); // safe — data is ready
  }
}

// Cart provider — restore cart asynchronously
final cartProvider = NotifierProvider<CartNotifier, CartState>((ref) {
  ref.event(onUserLogin).listenAsync((user) async {
    final cart = await _api.restoreCart(user.id);
    ref.read(cartProvider.notifier).setCart(cart);
  });
  return CartNotifier();
});

// Preferences provider — load preferences asynchronously
final preferencesProvider = NotifierProvider<PrefsNotifier, PrefsState>((ref) {
  ref.event(onUserLogin).listenAsync((user) async {
    final prefs = await _api.fetchPreferences(user.id);
    ref.read(preferencesProvider.notifier).setPrefs(prefs);
  });
  return PrefsNotifier();
});
```

**Async API overview:**

| Context | Method | Auto-dispose | Returns |
|---------|--------|-------------|---------|
| `Ref` | `listenAsync(cb)` | ✅ (via `ref.onDispose`) | `void` |
| `Ref` | `listenManuallyAsync(cb)` | ❌ (manual) | `ListenerDisposable` |
| `WidgetRef` | `listenManuallyAsync(cb)` | ❌ (manual) | `ListenerDisposable` |
| Both | `emitAsync(value)` | — | `Future<void>` |

**Error handling**: Same `onError` callback works with async listeners:

```dart
ref.event(onUserLogin).listenAsync((user) async {
  throw Exception('Failed to process user');
}, onError: (error, stackTrace) {
  log('Async listener error: $error', stackTrace: stackTrace);
});
```

**Mixing sync and async listeners**: `emitAsync()` runs sync listeners first, then awaits all async listeners in parallel. Sync listeners are not awaited.

```dart
ref.event(onUserLogin).listen((user) {
  log('User logged in: ${user.name}'); // runs synchronously
});

ref.event(onUserLogin).listenAsync((user) async {
  await _fetchData(); // awaited by emitAsync
});

await ref.event(onUserLogin).emitAsync(user); // awaits only async listeners
```

### 11. Sticky events (last value cache)

When you emit an event, the last value is cached. New subscribers using `sticky: true` receive the cached value **immediately** upon subscription, without waiting for the next `emit()`.

This is useful when providers are created **after** the event already fired — for example, a user logs in and later a new screen/feature loads a provider that needs the current user.

**Scenario**: After login, the user object is emitted. A new provider loaded later receives the user immediately.

```dart
// Login screen — emit user on login
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        final user = await authenticate();
        ref.event(onUserLogin).emit(user); // cachea el user
      },
      child: const Text('Login'),
    );
  }
}

// Profile provider — created AFTER login (lazy, new route, etc.)
final profileProvider = Provider<Profile>((ref) {
  User? currentUser;

  // sticky: true → receives the last user immediately if one exists
  ref.event(onUserLogin).listen((user) {
    currentUser = user;
    // ...
  }, sticky: true);

  // ...
});
```

**Available on all listen and stream methods:**

| Method | `sticky` param |
|--------|---------------|
| `listen(cb, sticky: true)` | ✅ |
| `listenAsync(cb, sticky: true)` | ✅ |
| `listenManually(cb, sticky: true)` | ✅ |
| `listenManuallyAsync(cb, sticky: true)` | ✅ |
| `stream(sticky: true)` | ✅ |
| `streamWithMeta(sticky: true)` | ✅ |

**Nullable values**: Null is cached if the event type allows it (`EventBusIdentifier<String?>`).

```dart
final onNullable = EventBusIdentifier<String?>('onNullable');

ref.event(onNullable).emit(null);

ref.event(onNullable).listen((v) {
  print(v); // null — received immediately from sticky cache
}, sticky: true);
```

**Clear the sticky cache**:

```dart
ref.event(onUserLogin).clearSticky(); // next sticky subscriber won't receive anything
```

#### Last value (unsubscribed access)

Both `EventBusAction<T>` and `SubEventAction<T>` expose `T? get lastValue` to read the last emitted value **without subscribing** — useful to initialize a form field or show a snapshot.

```dart
// Read the last emitted value of an event
final lastUser = ref.event(onUserLogin).lastValue;
if (lastUser != null) {
  print('Last logged in user: ${lastUser.name}');
}
```

```dart
// After emitting, lastValue reflects the latest value
ref.event(onSecureInt).emit(42);
print(ref.event(onSecureInt).lastValue); // 42

ref.event(onSecureInt).emit(100);
print(ref.event(onSecureInt).lastValue); // 100
```

```dart
// Before any emission, lastValue is null
print(ref.event(onSecureInt).lastValue); // null
```

```dart
// After clearSticky(), lastValue returns null
ref.event(onSecureInt).emit(42);
ref.event(onSecureInt).clearSticky();
print(ref.event(onSecureInt).lastValue); // null
```

```dart
// Works on SubEvents too
final evenAction = ref.subEvent(evenSecureInt);
print(evenAction.lastValue); // null — nothing emitted yet

ref.event(onSecureInt).emit(2); // 2 is even, passes the where
print(evenAction.lastValue); // 2

ref.event(onSecureInt).emit(3); // 3 is odd, does not pass
print(evenAction.lastValue); // 2 — still the last matching value
```

```dart
// Use in a widget
class UserStatusBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.event(onUserOnline).lastValue;
    return Badge(
      color: online == true ? Colors.green : Colors.grey,
      child: const Icon(Icons.person),
    );
  }
}
```

| Context | Getter |
|---------|--------|
| `EventBusAction<T>` | `T? get lastValue` |
| `SubEventAction<T>` | `T? get lastValue` |

### 12. Middleware pipeline

Middleware intercepts events **before** they reach listeners. Each middleware can log, transform, or cancel the event by deciding whether to call `next()`.

**Scenario**: E-commerce app with logging, validation, and currency conversion on cart events.

```dart
final onAddToCart = EventBusIdentifier<CartItem>('onAddToCart');

final cartMiddlewareProvider = Provider<void>((ref) {
  // Middleware 1 — logging (does not modify the value)
  ref.event(onAddToCart).applyMiddleware((item, next) {
    log('[Cart] Adding: ${item.productId} x${item.quantity}');
    next(item);
  });

  // Middleware 2 — validation (cancels if user is banned)
  ref.event(onAddToCart).applyMiddleware((item, next) {
    if (userIsBanned) {
      log('[Cart] User banned, blocked');
      return; // does not call next → event cancelled
    }
    next(item);
  });

  // Middleware 3 — transformation (converts price to local currency)
  ref.event(onAddToCart).applyMiddleware((item, next) {
    final converted = item.copyWith(price: item.price * exchangeRate);
    next(converted);
  });
});

// Listeners receive the already processed value
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>((ref) {
  ref.event(onAddToCart).listen((item) {
    ref.read(cartProvider.notifier).add(item);
  });
  return CartNotifier();
});
```

**Removing a middleware**:

```dart
final disposable = ref.event(onAddToCart).applyMiddleware((item, next) {
  log('Temporary logging');
  next(item);
});

// Stop logging
disposable.dispose();

// Or remove all middlewares from the event.
ref.event(onAddToCart).clearMiddlewares();
```

**Middleware API reference**:

| Method | Description |
|--------|-------------|
| `applyMiddleware(middleware)` | Registers a middleware, returns `ListenerDisposable` |
| `clearMiddlewares()` | Removes all middlewares from the event. |

### 13. Execution priority

By default listeners run in FIFO order (default priority is `0`). Use the `priority` parameter to control execution order — higher values run first.

```dart
ref.event(onCounter).listen((v) {
  // runs first
}, priority: 10);

ref.event(onCounter).listen((v) {
  // runs after priority 10 — default is 0
}, priority: 0);
```

Negative values are also supported — listeners with lower priority run last:

```dart
ref.event(onCounter).listen((v) {
  // runs after all default-priority listeners
}, priority: -5);
```

**Available on all listen and stream methods:**

| Method | `priority` param |
|--------|-----------------|
| `listen(cb, priority: n)` | ✅ |
| `listenAsync(cb, priority: n)` | ✅ |
| `listenManually(cb, priority: n)` | ✅ |
| `listenManuallyAsync(cb, priority: n)` | ✅ |
| `stream(priority: n)` | ✅ |
| `streamWithMeta(priority: n)` | ✅ |

Listeners with the same priority execute in FIFO order:

```dart
ref.event(onCounter).listen((v) {
  print('first');
}, priority: 5);

ref.event(onCounter).listen((v) {
  print('second'); // same priority → FIFO
}, priority: 5);
```

### 14. BusMetadata (emission metadata)

Every call to `emit()` / `emitAsync()` automatically generates a `BusMetadata` object with a precise `timestamp`. The emitter can optionally pass `source` and `extraData` directly to carry extra context all the way to the listeners.

| Type | Purpose | Who creates it |
|------|---------|---------------|
| `BusMetadata` | Received by `*WithMeta` listeners; auto-generated by the bus | The bus |

#### Emitting with metadata

```dart
// Without metadata — timestamp is still generated
ref.event(onUserLogin).emit(user);

// With source
ref.event(onUserLogin).emit(user, source: 'login_screen');

// With source + arbitrary extra data
ref.event(onUserLogin).emit(
  user,
  source: 'login_screen',
  extraData: {'loginMethod': 'google', 'sessionId': 'abc123'},
);

// Also works with emitAsync
await ref.event(onUserLogin).emitAsync(user, source: 'login_screen');
```

#### Listening with metadata

Use the `*WithMeta` variants — the callback receives `BusMetadata` as the second argument:

```dart
// Auto-disposed (inside a provider)
ref.event(onUserLogin).listenWithMeta((user, meta) {
  print('User logged in at ${meta.timestamp}');
  print('From: ${meta.source}');
  print('Extra: ${meta.extraData}');
});

// Manual lifecycle
final disposable = ref.event(onUserLogin).listenManuallyWithMeta((user, meta) {
  log('Login event from ${meta.source}');
});

disposable.dispose();

// Async
ref.event(onUserLogin).listenAsyncWithMeta((user, meta) async {
  await analytics.track('login', {
    'source': meta.source,
    'timestamp': meta.timestamp.toIso8601String(),
  });
});

// Manual async
final d2 = ref.event(onUserLogin).listenManuallyAsyncWithMeta((user, meta) async {
  await saveToLog(user, meta);
});
```

#### Practical scenario: audit trail

Emit cart actions with context about who performed them:

```dart
ref.event(onAddToCart).emit(item,
  source: 'product_detail',
  extraData: {
    'userId': currentUser.id,
    'sessionId': sessionId,
    'device': 'mobile',
  },
);
```

The listener logs the full audit trail:

```dart
ref.event(onAddToCart).listenWithMeta((item, meta) {
  auditLog.add(AuditEntry(
    productId: item.productId,
    timestamp: meta.timestamp,
    source: meta.source,
    metadata: meta.extraData,
  ));
});
```

#### Sticky + metadata

The sticky cache stores the metadata alongside the value. A `*WithMeta` subscriber with `sticky: true` receives the original metadata from the moment the value was emitted:

```dart
ref.event(onUserLogin).emit(user, source: 'onboarding');

// Later, a new provider subscribes — receives the cached metadata too
ref.event(onUserLogin).listenWithMeta((user, meta) {
  print(meta.source); // "onboarding" — original metadata preserved
}, sticky: true);
```

#### Metadata API reference

| Method | `source` and `extraData` on emit |
|--------|----------------------------------|
| `emit(value)` | ✅ optional `source:` / `extraData:` |
| `emitAsync(value)` | ✅ optional `source:` / `extraData:` |

| Method | Receives `BusMetadata` |
|--------------|----------------------|
| `listen(cb)` | ❌ |
| `listenWithMeta(cb)` | ✅ |
| `listenAsync(cb)` | ❌ |
| `listenAsyncWithMeta(cb)` | ✅ |
| `listenManually(cb)` | ❌ |
| `listenManuallyWithMeta(cb)` | ✅ |
| `listenManuallyAsync(cb)` | ❌ |
| `listenManuallyAsyncWithMeta(cb)` | ✅ |
| `stream()` | ❌ |
| `streamWithMeta()` | ✅ (via `(T, BusMetadata)` record) |

### 15. Listener filter with `where`

Every listen method accepts an optional `where` parameter — a predicate `bool Function(T value, BusMetadata metadata)` that decides whether the listener should fire. If `where` returns `false`, the listener is skipped for that emission. The listener is still registered and will fire on future matching emissions.

**Filtering by value — your detail page update scenario:**

```dart
class UserDetailNotifier extends Notifier<User> {
  @override
  User build() {
    final userId = ...; // the id of this detail page
    ref.event(onUpdateUser).listen((updated) {
      state = updated;
    }, where: (u, _) => u.id == userId);
    return fetchUser(userId);
  }
}
```

Each detail page only reacts to updates for its own user, even though the event is broadcast to all.

**Filtering by metadata source:**

```dart
ref.event(onAddToCart).listen((item) {
  // only process events from trusted sources
}, where: (item, meta) => meta.source == 'payment_gateway');
```

**Filtering with complex logic (value + metadata):**

```dart
ref.event(onDataSync).listenWithMeta((data, meta) {
  await process(data);
}, where: (data, meta) {
  return data.version > currentVersion &&
         meta.source != 'legacy_system';
});
```

**Where + sticky:**

The predicate also applies to cached sticky values — a non-matching cached value is not delivered:

```dart
// Emit a value, then subscribe with where + sticky
action.emit(-1);

action.listen((v) {
  // never called — where filters out -1
}, sticky: true, where: (v, _) => v > 0);
```

**Available on all listen and stream methods:**

| Method | `where` param |
|--------|--------------|
| `listen(cb, where: ...)` | ✅ |
| `listenAsync(cb, where: ...)` | ✅ |
| `listenManually(cb, where: ...)` | ✅ |
| `listenManuallyAsync(cb, where: ...)` | ✅ |
| `listenWithMeta(cb, where: ...)` | ✅ |
| `listenAsyncWithMeta(cb, where: ...)` | ✅ |
| `listenManuallyWithMeta(cb, where: ...)` | ✅ |
| `listenManuallyAsyncWithMeta(cb, where: ...)` | ✅ |
| `stream(where: ...)` | ✅ |
| `streamWithMeta(where: ...)` | ✅ |

### 16. SubEvents

A SubEvent is a **filtered view** of a parent event. It has its own listener list and sticky cache, independent from the parent. Unlike the `where` parameter on regular listeners — which is per-listener and disposable — a SubEvent's `where` predicate is part of its identity and shared across all its listeners.

SubEvents are **listen-only**: they fire automatically when the parent event emits and the value matches the SubEvent's `where`. You never `emit()` to a SubEvent directly.

**Scenario**: A user‑management app has multiple detail pages open at the same time, each for a different user. When any page updates a user, only that user's detail page should react.

```dart
// Define the parent event
final onUpdateUser = EventBusIdentifier<User>('onUpdateUser');

// Factory: create a SubEvent per userId
SubEventIdentifier<User> onUpdateUserOf(String userId) =>
    SubEventIdentifier(
      userId,
      parentEvent: onUpdateUser,
      where: (user, _) => user.userId == userId,
    );
```

Each detail page creates its own SubEvent identity:

```dart
class UserDetailPage extends ConsumerStatefulWidget {
  final String userId;
  // ...
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  @override
  Widget build(BuildContext context) {
    // Only reacts to updates for widget.userId
    ref.subEvent(onUpdateUserOf(widget.userId)).listen((user) {
      ref.read(userDetailProvider(widget.userId).notifier).update(user);
    });

    return UserDetailContent(userId: widget.userId);
  }
}
```

**Sticky cache**: SubEvents have their own independent sticky cache. When a new subscriber joins with `sticky: true`, the last matching value is delivered immediately — even if the parent event has never been emitted after the SubEvent was created.

```dart
// Somewhere else: a user is updated
ref.event(onUpdateUser).emit(User('user-42', name: 'Alice'));

// Later, a new provider subscribes — receives user-42 immediately
final profileProvider = Provider<void>((ref) {
  ref.subEvent(onUpdateUserOf('user-42')).listen((user) {
    print(user.name); // 'Alice' — from SubEvent's sticky cache
  }, sticky: true);
});
```

**SubEvent API** — available on `Ref` (auto-dispose) and `WidgetRef` (manual only):

| Method | Available on `Ref` | Available on `WidgetRef` |
|--------|-------------------|------------------------|
| `listen(cb)` / `listenAsync(cb)` | ✅ auto-dispose | ❌ |
| `listenWithMeta(cb)` / `listenAsyncWithMeta(cb)` | ✅ auto-dispose | ❌ |
| `listenManually(cb)` / `listenManuallyAsync(cb)` | ✅ | ✅ |
| `listenManuallyWithMeta(cb)` / `listenManuallyAsyncWithMeta(cb)` | ✅ | ✅ |
| `stream()` / `streamWithMeta()` | ✅ | ✅ |
| `hasClients` | ✅ | ✅ |
| `clearListeners()` / `clearSticky()` | ✅ | ✅ |
| `emit()` / `emitAsync()` | ❌ | ❌ |
| `applyMiddleware()` | ❌ (middleware on the parent) | ❌ |

**SubEvent reference table:**

| Feature | Behaviour |
|---------|-----------|
| Listen type | Listen‑only; triggered by parent emission |
| `where` | **Mandatory** — part of the SubEvent identity |
| Sticky cache | **Independent** of the parent event; backfills from parent on first subscription |
| `where` in listener | Optional — further narrows per‑listener, applied **after** the SubEvent `where` |
| Middleware | SubEvents inherit the **parent's** middleware pipeline |

| Extension | Available on | Sync | Async | Sticky | Auto-dispose |
|-----------|-------------|------|-------|--------|-------------|
| `EventBusForRef` | `Ref` | `listen()` · `listenManually()` | `listenAsync()` · `listenManuallyAsync()` | `clearSticky()` | ✅ (via `ref.onDispose`) |
| `EventBusForWidgetRef` | `WidgetRef` | `listenManually()` | `listenManuallyAsync()` | `clearSticky()` | Manual |

**Additional methods** (available on both extensions):

| Method | Description |
|--------|-------------|
| `stream()` / `streamWithMeta()` | Expose event as `Stream<T>` or `Stream<(T, BusMetadata)>`; supports `broadcast: true` for multiple subscribers |
| `streamSubEvent()` / `streamWithMetaSubEvent()` | Same for subEvents; supports `broadcast: true` |
| `clearAllEvents()` | Wipe all listeners, sticky caches, middlewares, and subEvents |

### 17. One-shot listeners (`listenOnce`)

Use `listenOnce()` to react to the **next** emission only — the listener removes itself automatically after firing:

```dart
// Inside a provider (auto-dispose via ref.onDispose)
ref.event(onUserLogin).listenOnce((user) {
  navigateToHome(); // fires once, then auto-removes
});
```

Inside a widget or anywhere without `Ref`, use `listenOnceManually()` — it returns a `ListenerDisposable` for manual cleanup:

```dart
class _MyWidgetState extends ConsumerState<MyWidget> {
  ListenerDisposable? _disposable;

  @override
  void initState() {
    super.initState();
    _disposable = ref.event(EventBusConstants.onUserLogin).listenOnceManually((user) {
      navigateToHome(); // fires once, then auto-removes
    });
  }

  @override
  void dispose() {
    _disposable?.dispose(); // optional: clean up if event never fires
    super.dispose();
  }
}
```

One-shot listeners support all the same options as regular listeners — `sticky`, `where`, `priority`, `onError`, and `*WithMeta` variants:

```dart
// One-shot with sticky — fires with the cached value, removes itself
ref.event(onCounter).listenOnce((v) {
  print('First emission was $v');
}, sticky: true);

// One-shot with metadata
ref.event(onUserLogin).listenOnceWithMeta((user, meta) {
  print('Logged in at ${meta.timestamp}');
});

// One-shot with where filter
ref.event(onData).listenOnce((data) {
  process(data);
}, where: (data, _) => data.isReady);

// One-shot manual with error handling
final d = ref.event(onApiCall).listenOnceManually((result) {
  handleResult(result);
}, onError: (e, st) => log('API failed: $e'));

// Manual one-shot for subEvents
ref.subEvent(evenSecureInt).listenOnce((v) {
  print('First even number: $v');
}, where: (v, _) => v > 10);
```

| Method | Context | Auto-dispose | Returns |
|--------|---------|-------------|---------|
| `listenOnce(cb)` | `Ref` | ✅ | `void` |
| `listenOnceWithMeta(cb)` | `Ref` | ✅ | `void` |
| `listenOnceManually(cb)` | Both | ❌ | `ListenerDisposable` |
| `listenOnceManuallyWithMeta(cb)` | Both | ❌ | `ListenerDisposable` |

All methods are also available on subEvents via `ref.subEvent(...)`.`listenOnce(...)` / `listenOnceManually(...)`.

### 18. Event history (last N values)

Each event can optionally keep a circular buffer of the last N emitted values. Configure the buffer size at identifier creation time:

```dart
final onCounter = EventBusIdentifier<int>('onCounter', historySize: 20);
```

The history stores **post-middleware** values with their `BusMetadata`. Read it at any time without subscribing:

```dart
final recent = ref.event(onCounter).history;
// => List<ValueWithMeta<int>> — [ValueWithMeta(1, meta), ValueWithMeta(2, meta), ...]

print('Last value: ${recent.last.value}');
print('At: ${recent.last.metadata.timestamp}');
```

The buffer is circular — older values are dropped when the size is exceeded:

```dart
final onCounter = EventBusIdentifier<int>('onCounter', historySize: 3);

ref.event(onCounter).emit(1);
ref.event(onCounter).emit(2);
ref.event(onCounter).emit(3);
ref.event(onCounter).emit(4);
ref.event(onCounter).emit(5);

print(ref.event(onCounter).history.map((e) => e.value).toList());
// => [3, 4, 5]  (1 and 2 were dropped)
```

**Real-world example**: track whether a value actually changed. Set `historySize: 2` and compare the previous and current values inside a listener:

```dart
final onBatteryLevel = EventBusIdentifier<double>('onBatteryLevel', historySize: 2);

final batteryProvider = Provider<void>((ref) {
  ref.event(onBatteryLevel).listen((level) {
    final h = ref.event(onBatteryLevel).history;
    if (h.length >= 2) {
      final prev = h[h.length - 2].value;
      if ((level - prev).abs() > 0.05) {
        log('Battery changed significantly: $prev → $level');
        // Update UI, trigger alerts, etc.
      }
    } else {
      log('First battery reading: $level');
    }
  });
});
```

Clear the history without affecting listeners or sticky cache:

```dart
ref.event(onCounter).clearHistory();
print(ref.event(onCounter).history); // []
```

**SubEvents** have their own independent history, populated only with values that pass their `where`:

```dart
final onCounter = EventBusIdentifier<int>('onCounter', historySize: 10);
final evens = SubEventIdentifier<int>(
  'evens',
  parentEvent: onCounter,
  where: (v, _) => v.isEven,
  historySize: 5,
);

// ... subscribe to evens, then emit
for (int i = 1; i <= 10; i++) {
  ref.event(onCounter).emit(i);
}

print(ref.event(onCounter).history.length);   // 10
print(ref.subEvent(evens).history.length);     // 5  (only evens)
```

**Rules:**

| Setting | Default | Behaviour |
|---------|---------|-----------|
| `historySize` | `0` | No history kept. Overhead is zero. |
| `assert` | `historySize >= 0` | Negative values throw at construction time. |
| Storage | Post-middleware | Coherent with sticky cache and listener delivery. |
| `clearHistory()` | — | Empties the buffer; next emission starts fresh. |
| `clearSticky()` | — | Does **not** affect history. |
| `clearAllEvents()` | — | Also clears all history. |
| `clearListeners()` | — | Does **not** affect history. |

---

### 19. Logger interceptor

Register a global callback that fires for **every event emission**, before middlewares are applied. Useful for logging, analytics, or debugging.

```dart
// Inside a provider — auto-disposed when the provider is invalidated
ref.logEvents((entry) {
  log('[${entry.eventName}] ${entry.value}');
});
```

Inside a `ConsumerWidget` (manual disposal):

```dart
final disposable = ref.logEvents((entry) {
  log('[${entry.eventName}] ${entry.value}');
});
// later: disposable.dispose();
```

#### What gets logged

Every call to `emit()` / `emitAsync()` fires the callback with a `LogEntry<Object?>` containing:
- `eventName` — the name of the `EventBusIdentifier`
- `value` — the raw value before middlewares
- `metadata` — the `BusMetadata` (timestamp, source, extraData)

The callback runs **before** middleware, so you always see the original value even if middleware transforms or cancels the event.

#### Error isolation

If the callback throws, the error is silently caught — it never crashes the bus or affects listeners.

#### When used with SubEvents

The logger fires for the parent event, **not** for each subEvent. SubEvents are derived views and do not emit independently.

### 20. Global API (without Riverpod)

Use `EventBusGlobal` to interact with the event bus from **anywhere** — plain Dart classes, services, repositories, or any code that doesn't have access to a `Ref` or `WidgetRef`. No Riverpod dependency required.

The global API is backed by `EventBusSingleton`, which is the **same** singleton instance used by `ref.event()` / `ref.subEvent()`. Emits and listeners work seamlessly across both APIs.

```dart
import 'package:event_bus_riverpod/event_bus_riverpod.dart';

class AnalyticsService {
  void trackScreen(String screenName) {
    // Emit from a plain Dart service — no Ref needed
    EventBusGlobal.event(onScreenView).emit(screenName);
  }
}
```

```dart
class CartRepository {
  ListenerDisposable? _disposable;

  void startListening() {
    _disposable = EventBusGlobal.event(onAddToCart).listenManually((item) {
      _saveToLocalDb(item);
    });
  }

  void stopListening() {
    _disposable?.dispose();
  }
}
```

**API reference:**

| Method | Description |
|--------|-------------|
| `EventBusGlobal.event(id)` | Returns an `EventBusActionForGlobal<T>` for the given event |
| `EventBusGlobal.subEvent(id)` | Returns a `SubEventActionForGlobal<T>` for the given subEvent |
| `EventBusGlobal.clearAll()` | Wipes all listeners, sticky caches, middlewares, and subEvents |
| `EventBusGlobal.logEvents(cb)` | Registers a global logger; returns `ListenerDisposable` |

`EventBusActionForGlobal<T>` supports all the manual methods: `listenManually()`, `listenManuallyWithMeta()`, `listenManuallyAsync()`, `listenManuallyAsyncWithMeta()`, `emit()`, `emitAsync()`, `stream()`, `streamWithMeta()`, `hasClients`, `lastValue`, `history`, `clearListeners()`, `clearSticky()`, `applyMiddleware()`, `clearMiddlewares()`, `listenOnceManually()`, `listenOnceManuallyWithMeta()`.

`SubEventActionForGlobal<T>` supports: `listenManually()`, `listenManuallyWithMeta()`, `listenManuallyAsync()`, `listenManuallyAsyncWithMeta()`, `stream()`, `streamWithMeta()`, `hasClients`, `lastValue`, `history`, `clearListeners()`, `clearSticky()`, `listenOnceManually()`, `listenOnceManuallyWithMeta()`.

**Shared bus example:**

```dart
// Inside a provider — auto-disposed
ref.event(onUserLogin).listen((user) {
  print('Provider heard: ${user.name}');
});

// From a global service — same bus
EventBusGlobal.event(onUserLogin).emit(User('Alice'));
// Provider listener prints: Provider heard: Alice
```

```dart
// Global listener
EventBusGlobal.event(onUserLogin).listenManually((user) {
  print('Global heard: ${user.name}');
});

// Emit from a provider — global listener receives it
ref.event(onUserLogin).emit(User('Bob'));
// Global listener prints: Global heard: Bob
```

`EventBusGlobal` also exposes `logEvents()` and `clearAll()` with the same behavior as their `Ref` / `WidgetRef` counterparts.

### 21. EventBusBuilder widget

`EventBusBuilder` is a `ConsumerStatefulWidget` that rebuilds whenever an event is emitted. It accepts both `EventBusIdentifier` and `SubEventIdentifier` polymorphically through a common `EventBusIdentifierBase` type — no need to worry about which type you pass.

```dart
EventBusBuilder<int>(
  event: onCounter,
  builder: (context, value) => Text('${value ?? 0}'),
)
```

The widget manages its own subscription lifecycle automatically — it subscribes in `initState`, unsubscribes in `dispose`, and re-subscribes if the event identifier or filter parameters change.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `event` | `EventBusIdentifierBase<T>` | The event or subEvent to listen to |
| `builder` | `Widget Function(BuildContext, T?)` | Called on each emission with the new value (`T?` — `null` before any emission) |
| `sticky` | `bool` | If `true`, deliver the last cached value immediately **(has priority over `initialData`)** |
| `initialData` | `T?` | Initial value shown before the first emission (only used when there's no sticky cached value) |
| `where` | `ListenerWhere<T>?` | Optional predicate to filter which emissions trigger a rebuild |
| `priority` | `int` | Listener execution priority (default `0`, higher runs first) |


**Sticky + initialData:**

When `sticky: true` and there's a cached value, the sticky value takes precedence. `initialData` is only used when there's no sticky cache:

```dart
// Sticky value (42) overrides initialData (0)
EventBusGlobal.event(onCounter).emit(42);

EventBusBuilder<int>(
  event: onCounter,
  builder: (ctx, value) => Text('${value ?? 0}'),
  sticky: true,
  initialData: 0,
);
// Shows "42", not "0"
```

**With SubEvent:**

```dart
EventBusBuilder<int>(
  event: evenSecureInt, // SubEventIdentifier — only fires for even values
  builder: (ctx, value) => Text('Even: $value'),
);
```

**With where filter:**

```dart
EventBusBuilder<int>(
  event: onCounter,
  builder: (ctx, value) => Text('${value ?? 0}'),
  where: (v, _) => v > 0, // only rebuilds for positive values
);
```

**Shared bus with `EventBusGlobal` and `ref.event()`:**

The widget uses `ref.event()` / `ref.subEvent()` internally, which shares the same `EventBusSingleton` as `EventBusGlobal`. This means emissions from `EventBusGlobal` or from any provider using `ref.event()` will trigger the widget to rebuild.

### 22. Await the next emission with `waitFor()`

`waitFor()` returns a `Future<T>` that completes with the value of the **next matching emission**. Think of it as a one-shot listener wrapped in a `Future` — useful for inline async coordination.

**Scenario: navigation after login**

A login screen emits a `User` event. Multiple providers start fetching data asynchronously (cart, preferences, notifications). The navigation code needs to wait for all providers to finish before pushing the home screen:

```dart
final loginProvider = Provider.notifier<LoginNotifier>((ref) {
  return LoginNotifier(ref);
});

class LoginNotifier {
  final Ref ref;
  LoginNotifier(this.ref);

  Future<void> login(String email, String password) async {
    final user = await _api.login(email, password);

    // emitAsync waits for all async listeners
    await ref.event(onUserLogin).emitAsync(user);

    // Now wait for a specific event that signals data is ready
    await ref.event(onDataReady).waitFor(
      timeout: Duration(seconds: 10),
    );

    navigateToHome(); // safe — data is loaded
  }
}
```

**Scenario: handling timeout gracefully**

When `waitFor` times out, it throws a `TimeoutException`. Catch it to handle the failure case — retry, show feedback, or fall back:

```dart
try {
  await ref.event(onPaymentConfirmation).waitFor(
    timeout: Duration(seconds: 15),
    where: (status, _) => status == PaymentStatus.confirmed,
  );
  showSuccessToast('Payment confirmed!');
} on TimeoutException {
  ref.event(onShowSnackbar).emit('Payment is taking longer than expected. Check your transactions later.');
  // Optionally: poll status, log to analytics, or navigate away
}
```

**Scenario: wait for a filtered value**

A payment screen emits order status events. Wait for the order to reach `confirmed` status before showing the success toast:

```dart
Future<void> placeOrder() async {
  ref.event(onPlaceOrder).emit(order);

  final confirmed = await ref.event(onOrderStatus).waitFor(
    where: (status, _) => status == OrderStatus.confirmed,
    timeout: Duration(seconds: 30),
  );

  showSuccessToast('Order $confirmed is confirmed!');
}
```

**Scenario: subEvent + waitFor**

Only wait for even counter values:

```dart
final evenCount = await ref.subEvent(evenSecureInt).waitFor(
  timeout: Duration(seconds: 5),
);
print('First even number: $evenCount');
```

**Scenario: from a plain Dart service with `EventBusGlobal`**

```dart
class PaymentService {
  Future<PaymentResult> processPayment(Payment payment) async {
    EventBusGlobal.event(onPaymentInitiated).emit(payment);

    final result = await EventBusGlobal.event(onPaymentResult).waitFor(
      where: (result, _) => result.paymentId == payment.id,
      timeout: Duration(seconds: 60),
    );

    return result;
  }
}
```

**Behaviour reference:**

| Aspect | Behaviour |
|--------|-----------|
| Returns | `Future<T>` — completes with the value of the **first** emission after the call |
| Timeout | Defaults to **30 seconds**; pass `null` to wait indefinitely (not recommended) |
| Where | Optional per-call filter — same signature as the existing `where` parameter on listen methods |
| Sticky | **Not supported** — `waitFor` explicitly waits for a *future* emission. For the cached value, use `lastValue`. |
| Cleanup | Internal listener is auto-removed when the future completes (value or error). |
| Middleware | Runs normally — the future receives the **post-middleware** value. |
