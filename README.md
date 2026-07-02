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
- **Dual context** – extensions on both `Ref` and `WidgetRef`
- **Multiple listeners** – many listeners can subscribe to the same event
- **Error isolation** – a failing callback never breaks other listeners
- **Error handling** – catch errors per-listener with `onError` callback
- **Stream API** – consume events as a `Stream<T>` for composition and `StreamBuilder`
- **Robust key routing** – events are internally routed with `Type` hashing instead of string interpolation, ensuring platform-independent key generation

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
// Catch errors from the bus with onError parameter
ref.event(EventBusConstants.onUserAgeChanged).stream(
  onError: (error, stackTrace) {
    log('Bus error: $error', stackTrace: stackTrace);
  },
).listen((age) => print('Age: $age'));
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

## Reference

| Extension | Available on | `listen()` | `listenManually()` | Auto-dispose |
|-----------|-------------|------------|--------------------|--------------|
| `EventBusForRef` | `Ref` | ✅ | ✅ | ✅ (via `ref.onDispose`) |
| `EventBusForWidgetRef` | `WidgetRef` | ❌ | ✅ | Manual |
