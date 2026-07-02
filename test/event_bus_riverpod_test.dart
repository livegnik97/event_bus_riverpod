import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:event_bus_riverpod/event_bus_riverpod.dart';
import 'event_bus_constants.dart';

void main() {
  group('EventBusForRef extension with EventBusConstants', () {
    test('listen and emit via extension', () {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      final listenerProvider = Provider<void>((ref) => globalRef = ref);
      container.read(listenerProvider);

      bool hasClients = globalRef
          .event(EventBusConstants.onSecureInt)
          .hasClients;
      expect(hasClients, false);

      globalRef.event(EventBusConstants.onSecureInt).listen((v) {
        captured.add(v);
      });

      hasClients = globalRef.event(EventBusConstants.onSecureInt).hasClients;
      expect(hasClients, true);

      globalRef.event(EventBusConstants.onSecureInt).emit(42);
      expect(captured, [42]);

      globalRef.event(EventBusConstants.onSecureInt).emit(43);
      expect(captured, [42, 43]);

      container.dispose();
    });

    test('listenManually and dispose via extension', () {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      final listenerProvider = Provider<void>((ref) => globalRef = ref);
      container.read(listenerProvider);

      final disposable = globalRef
          .event(EventBusConstants.onSecureInt)
          .listenManually((v) {
            captured.add(v);
          });

      bool hasClients = globalRef
          .event(EventBusConstants.onSecureInt)
          .hasClients;
      expect(hasClients, true);

      globalRef.event(EventBusConstants.onSecureInt).emit(42);
      expect(captured, [42]);

      disposable.dispose();

      hasClients = globalRef.event(EventBusConstants.onSecureInt).hasClients;
      expect(hasClients, false);

      globalRef.event(EventBusConstants.onSecureInt).emit(43);
      expect(captured, [42]);

      container.dispose();
    });

    test('null safety - emit null to String? listener', () {
      final captured = <String?>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onPossibleString).listen((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<String?>>(
          (ref) => ref.event(EventBusConstants.onPossibleString),
        ),
      );

      container.read(listenerProvider);
      action.emit(null);
      expect(captured, [null]);

      action.emit('hello');
      expect(captured, [null, 'hello']);

      container.dispose();
    });

    test('multiple listeners for same event', () {
      final captured1 = <int>[];
      final captured2 = <int>[];
      final container = ProviderContainer();

      final listenerProvider1 = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured1.add(v);
        });
      });

      final listenerProvider2 = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured2.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider1);
      container.read(listenerProvider2);
      action.emit(99);

      expect(captured1, [99]);
      expect(captured2, [99]);
      container.dispose();
    });

    test('event isolation between different constants', () {
      final intCaptured = <int>[];
      final stringCaptured = <String?>[];
      final container = ProviderContainer();

      final intListenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          intCaptured.add(v);
        });
      });

      final stringListenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onPossibleString).listen((v) {
          stringCaptured.add(v);
        });
      });

      final intAction = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      final stringAction = container.read(
        Provider<EventBusActionForRef<String?>>(
          (ref) => ref.event(EventBusConstants.onPossibleString),
        ),
      );

      container.read(intListenerProvider);
      container.read(stringListenerProvider);

      intAction.emit(1);
      expect(intCaptured, [1]);
      expect(stringCaptured, isEmpty);

      stringAction.emit('isolated');
      expect(intCaptured, [1]);
      expect(stringCaptured, ['isolated']);

      container.dispose();
    });

    test('autoDispose cleans up when provider is invalidated', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(1);
      expect(captured, [1]);

      container.invalidate(listenerProvider);
      action.emit(2);
      expect(captured, [1]);

      container.dispose();
    });

    test('listenManually with string event and dispose', () {
      final captured = <String>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<String>>(
          (ref) => ref.event(EventBusConstants.onUserName),
        ),
      );

      final disposable = action.listenManually((v) => captured.add(v));
      action.emit('Alice');
      expect(captured, ['Alice']);

      disposable.dispose();
      action.emit('Bob');
      expect(captured, ['Alice']);

      container.dispose();
    });

    test('onError is called when listener throws', () {
      final capturedErrors = <Object>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen(
          (v) => throw Exception('fail: $v'),
          onError: (e, st) => capturedErrors.add(e),
        );
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(42);

      expect(capturedErrors.length, 1);
      expect(capturedErrors[0].toString(), contains('fail: 42'));
      container.dispose();
    });

    test('other listeners receive event even when one listener throws', () {
      final captured = <int>[];
      final capturedErrors = <Object>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen(
          (v) => throw Exception('fail'),
          onError: (e, st) => capturedErrors.add(e),
        );
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(99);

      expect(capturedErrors.length, 1);
      expect(captured, [99]);
      container.dispose();
    });

    test('stream receives events from emit', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      final sub = globalRef
          .event(EventBusConstants.onSecureInt)
          .stream()
          .listen((v) => captured.add(v));

      globalRef.event(EventBusConstants.onSecureInt).emit(1);
      globalRef.event(EventBusConstants.onSecureInt).emit(2);
      await Future(() {});

      expect(captured, [1, 2]);

      await sub.cancel();
      container.dispose();
    });

    test('stream stops receiving after subscription is cancelled', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      final sub = globalRef
          .event(EventBusConstants.onSecureInt)
          .stream()
          .listen((v) => captured.add(v));

      globalRef.event(EventBusConstants.onSecureInt).emit(1);
      await Future(() {});
      expect(captured, [1]);

      await sub.cancel();

      globalRef.event(EventBusConstants.onSecureInt).emit(2);
      await Future(() {});
      expect(captured, [1]);

      container.dispose();
    });

    test('stream composition with where and map', () async {
      final captured = <String>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      final sub = globalRef
          .event(EventBusConstants.onSecureInt)
          .stream()
          .where((n) => n > 10)
          .map((n) => 'big: $n')
          .listen((v) => captured.add(v));

      globalRef.event(EventBusConstants.onSecureInt).emit(5);
      globalRef.event(EventBusConstants.onSecureInt).emit(15);
      globalRef.event(EventBusConstants.onSecureInt).emit(3);
      globalRef.event(EventBusConstants.onSecureInt).emit(20);
      await Future(() {});

      expect(captured, ['big: 15', 'big: 20']);

      await sub.cancel();
      container.dispose();
    });

    test('bool event type works correctly', () {
      final captured = <bool>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onLoginStatus).listen((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<bool>>(
          (ref) => ref.event(EventBusConstants.onLoginStatus),
        ),
      );

      container.read(listenerProvider);
      action.emit(true);
      expect(captured, [true]);

      action.emit(false);
      expect(captured, [true, false]);

      container.dispose();
    });
  });
}