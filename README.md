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
- **Stream API** – consume events as a `Stream<T>` for composition and `StreamBuilder`
- **Robust key routing** – events are internally routed with `Type` hashing instead of string interpolation, ensuring platform-independent key generation
- **Sticky events** – cache the last emitted value and deliver it to new subscribers with `sticky: true`
- **Middleware pipeline** – intercept, transform, or cancel events before they reach listeners with `applyMiddleware()`

## Installing

Add the package from [pub.dev](https://pub.dev/packages/event_bus_riverpod):

```yaml
dependencies:
  event_bus_riverpod: ^1.6.2
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

**Available on all listen methods:**

| Method | `sticky` param |
|--------|---------------|
| `listen(cb, sticky: true)` | ✅ |
| `listenAsync(cb, sticky: true)` | ✅ |
| `listenManually(cb, sticky: true)` | ✅ |
| `listenManuallyAsync(cb, sticky: true)` | ✅ |

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

// Or clear everything (listeners + sticky values)
ref.event(onUserLogin).clearListeners();
```

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

## Reference

| Extension | Available on | Sync | Async | Sticky | Auto-dispose |
|-----------|-------------|------|-------|--------|-------------|
| `EventBusForRef` | `Ref` | `listen()` · `listenManually()` | `listenAsync()` · `listenManuallyAsync()` | `clearSticky()` | ✅ (via `ref.onDispose`) |
| `EventBusForWidgetRef` | `WidgetRef` | `listenManually()` | `listenManuallyAsync()` | `clearSticky()` | Manual |
