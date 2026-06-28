# event_bus_riverpod

[![pub package](https://img.shields.io/pub/v/event_bus_riverpod.svg)](https://pub.dev/packages/event_bus_riverpod)

A type-safe, Riverpod-integrated event bus for Flutter. It allows you to emit and listen to events anywhere in your app using Riverpod's dependency injection and lifecycle management.

## Features

- **Type-safe events** – each event carries a generic type `T`, preventing type mismatches
- **Auto-dispose** – listeners tied to a `Ref` are automatically cleaned up when the provider is destroyed
- **Manual lifecycle** – subscribe/unsubscribe manually with `ListenerDisposable`
- **Dual context** – extensions on both `Ref` and `WidgetRef`
- **Multiple listeners** – many listeners can subscribe to the same event
- **Error isolation** – a failing callback never breaks other listeners

## Installing

Add the package from [pub.dev](https://pub.dev/packages/event_bus_riverpod):

```yaml
dependencies:
  event_bus_riverpod: ^1.2.3
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

## Reference

| Extension | Available on | `listen()` | `listenManually()` | Auto-dispose |
|-----------|-------------|------------|--------------------|--------------|
| `EventBusForRef` | `Ref` | ✅ | ✅ | ✅ (via `ref.onDispose`) |
| `EventBusForWidgetRef` | `WidgetRef` | ❌ | ✅ | Manual |
