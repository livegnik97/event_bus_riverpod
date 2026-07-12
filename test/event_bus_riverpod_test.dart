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
        ref
            .event(EventBusConstants.onSecureInt)
            .listen(
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
        ref
            .event(EventBusConstants.onSecureInt)
            .listen(
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

    test('clearListeners removes all listeners for an event', () {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      globalRef.event(EventBusConstants.onSecureInt).listen((v) {
        captured.add(v);
      });

      expect(globalRef.event(EventBusConstants.onSecureInt).hasClients, true);

      globalRef.event(EventBusConstants.onSecureInt).clearListeners();

      expect(globalRef.event(EventBusConstants.onSecureInt).hasClients, false);

      globalRef.event(EventBusConstants.onSecureInt).emit(42);
      expect(captured, isEmpty);

      container.dispose();
    });

    test('clearListeners does not affect other events', () {
      final intCaptured = <int>[];
      final stringCaptured = <String?>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      globalRef.event(EventBusConstants.onSecureInt).listen((v) {
        intCaptured.add(v);
      });
      globalRef.event(EventBusConstants.onPossibleString).listen((v) {
        stringCaptured.add(v);
      });

      globalRef.event(EventBusConstants.onSecureInt).clearListeners();

      globalRef.event(EventBusConstants.onSecureInt).emit(1);
      globalRef.event(EventBusConstants.onPossibleString).emit('still works');

      expect(intCaptured, isEmpty);
      expect(stringCaptured, ['still works']);

      container.dispose();
    });

    test('stream does not register listener if never subscribed', () async {
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      final hasClientsBefore = globalRef
          .event(EventBusConstants.onSecureInt)
          .hasClients;
      expect(hasClientsBefore, false);

      // Llamamos a stream() pero nunca a .listen()
      globalRef.event(EventBusConstants.onSecureInt).stream();

      // Should have no registered listeners
      final hasClientsAfter = globalRef
          .event(EventBusConstants.onSecureInt)
          .hasClients;
      expect(hasClientsAfter, false);

      // Emitting should not cause errors or deliver anything
      globalRef.event(EventBusConstants.onSecureInt).emit(42);

      container.dispose();
    });

    test(
      'stream registers listener only on listen, not on stream creation',
      () async {
        final captured = <int>[];
        final container = ProviderContainer();

        late Ref globalRef;
        container.read(Provider<void>((ref) => globalRef = ref));

        // Crear stream sin escuchar
        final stream = globalRef.event(EventBusConstants.onSecureInt).stream();

        // Should have no listeners
        expect(
          globalRef.event(EventBusConstants.onSecureInt).hasClients,
          false,
        );

        // Ahora suscribirse
        final sub = stream.listen((v) => captured.add(v));

        // Now there should be a listener
        expect(globalRef.event(EventBusConstants.onSecureInt).hasClients, true);

        globalRef.event(EventBusConstants.onSecureInt).emit(1);
        await Future(() {});
        expect(captured, [1]);

        await sub.cancel();
        container.dispose();
      },
    );

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

    test('listenAsync and emitAsync basic', () async {
      final captured = <String>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onUserName).listenAsync((name) async {
          await Future(() {});
          captured.add(name);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<String>>(
          (ref) => ref.event(EventBusConstants.onUserName),
        ),
      );

      container.read(listenerProvider);

      await action.emitAsync('Alice');
      expect(captured, ['Alice']);

      container.dispose();
    });

    test('emitAsync awaits all async listeners', () async {
      final log = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          await Future.delayed(const Duration(milliseconds: 10));
          log.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);

      await action.emitAsync(1);
      expect(log, [1]);

      container.dispose();
    });

    test('emitAsync also runs sync listeners', () async {
      final syncLog = <int>[];
      final asyncLog = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          syncLog.add(v);
        });
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          await Future(() {});
          asyncLog.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);

      await action.emitAsync(42);
      expect(syncLog, [42]);
      expect(asyncLog, [42]);

      container.dispose();
    });

    test('listenManuallyAsync with dispose', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      final disposable = action.listenManuallyAsync((v) async {
        await Future(() {});
        captured.add(v);
      });

      await action.emitAsync(1);
      expect(captured, [1]);

      disposable.dispose();

      await action.emitAsync(2);
      expect(captured, [1]);

      container.dispose();
    });

    test('emitAsync error in async listener is caught by onError', () async {
      final capturedErrors = <Object>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          await Future(() {});
          throw Exception('async fail: $v');
        }, onError: (e, st) => capturedErrors.add(e));
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);

      await action.emitAsync(42);
      expect(capturedErrors.length, 1);
      expect(capturedErrors[0].toString(), contains('async fail: 42'));

      container.dispose();
    });

    test(
      'emitAsync other listeners still run when one async listener fails',
      () async {
        final captured = <int>[];
        final capturedErrors = <Object>[];
        final container = ProviderContainer();

        final listenerProvider = Provider<void>((ref) {
          ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
            await Future(() {});
            throw Exception('fail');
          }, onError: (e, st) => capturedErrors.add(e));
          ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
            await Future(() {});
            captured.add(v);
          });
        });

        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        container.read(listenerProvider);

        await action.emitAsync(99);
        expect(capturedErrors.length, 1);
        expect(captured, [99]);

        container.dispose();
      },
    );

    test('sticky listen receives last value immediately', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(42);

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, [42]);

      container.dispose();
    });

    test('sticky listenManually receives last value immediately', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(42);

      final captured = <int>[];
      final disposable = action.listenManually((v) {
        captured.add(v);
      }, sticky: true);

      expect(captured, [42]);

      disposable.dispose();
      container.dispose();
    });

    test('sticky listenAsync receives last value immediately', () async {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(42);

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      await Future(() {});
      expect(captured, [42]);

      container.dispose();
    });

    test('sticky with null value is delivered to nullable event', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<String?>>(
          (ref) => ref.event(EventBusConstants.onPossibleString),
        ),
      );

      action.emit(null);

      final captured = <String?>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onPossibleString).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, [null]);

      container.dispose();
    });

    test('sticky without emit does not deliver anything', () {
      final container = ProviderContainer();

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, isEmpty);

      container.dispose();
    });

    test('clearSticky removes cached value', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(42);
      action.clearSticky();

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, isEmpty);

      container.dispose();
    });

    test('sticky receives latest value after multiple emits', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(1);
      action.emit(2);
      action.emit(3);

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, [3]);

      container.dispose();
    });

    test('middleware runs before listener and can transform value', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.applyMiddleware((value, next) {
        next(value * 2);
      });

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        });
      });
      container.read(listenerProvider);

      action.emit(21);
      expect(captured, [42]);

      container.dispose();
    });

    test('middleware can cancel event by not calling next', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.applyMiddleware((value, next) {
        // no llamar next → evento cancelado
      });

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        });
      });
      container.read(listenerProvider);

      action.emit(42);
      expect(captured, isEmpty);

      container.dispose();
    });

    test('multiple middlewares run in FIFO order', () {
      final log = <String>[];
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.applyMiddleware((value, next) {
        log.add('first');
        next(value + 1);
      });
      action.applyMiddleware((value, next) {
        log.add('second');
        next(value * 2);
      });

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        });
      });
      container.read(listenerProvider);

      action.emit(5);
      expect(log, ['first', 'second']);
      expect(captured, [12]); // (5 + 1) * 2

      container.dispose();
    });

    test('middleware can be removed via ListenerDisposable', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      final disposable = action.applyMiddleware((value, next) {
        next(value * 10);
      });

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        });
      });
      container.read(listenerProvider);

      action.emit(1);
      expect(captured, [10]);

      disposable.dispose();

      action.emit(2);
      expect(captured, [10, 2]);

      container.dispose();
    });

    test('middleware works with emitAsync', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.applyMiddleware((value, next) {
        next(value * 3);
      });

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          captured.add(v);
        });
      });
      container.read(listenerProvider);

      await action.emitAsync(7);
      expect(captured, [21]);

      container.dispose();
    });

    test('middleware affects sticky cached value', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.applyMiddleware((value, next) {
        next(value * 2);
      });

      action.emit(10);

      // Nuevo listener con sticky recibe el valor post-middleware
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, [20]);

      container.dispose();
    });

    test('middleware cancellation also prevents sticky cache', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.applyMiddleware((value, next) {
        // no llamar next → evento cancelado, no se cachea
      });

      action.emit(42);

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);

      expect(captured, isEmpty);

      container.dispose();
    });

    test('priority higher runs before lower', () {
      final log = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          log.add(1);
        }, priority: 10);
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          log.add(2);
        }, priority: 0);
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          log.add(3);
        }, priority: -10);
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(42);

      expect(log, [1, 2, 3]);

      container.dispose();
    });

    test('same priority preserves FIFO order', () {
      final log = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          log.add(1);
        });
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          log.add(2);
        });
        ref.event(EventBusConstants.onSecureInt).listen((v) {
          log.add(3);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(42);

      expect(log, [1, 2, 3]);

      container.dispose();
    });

    test('priority works with listenAsync and emitAsync', () async {
      final log = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          log.add(1);
        }, priority: 10);
        ref.event(EventBusConstants.onSecureInt).listenAsync((v) async {
          log.add(2);
        }, priority: 0);
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      await action.emitAsync(42);

      expect(log, [1, 2]);

      container.dispose();
    });

    test('priority works with listenManually', () {
      final log = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      final d1 = action.listenManually((v) => log.add(1), priority: 10);
      final d2 = action.listenManually((v) => log.add(2), priority: 0);

      action.emit(42);
      expect(log, [1, 2]);

      d1.dispose();
      d2.dispose();
      container.dispose();
    });

    group('metadata', () {
      test('emit without metadata delivers timestamp', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        BusMetadata? capturedMeta;
        action.listenWithMeta((v, meta) {
          capturedMeta = meta;
        });
        action.emit(42);

        expect(capturedMeta, isNotNull);
        expect(capturedMeta!.timestamp, isA<DateTime>());
        expect(capturedMeta!.source, isNull);
        expect(capturedMeta!.extraData, isNull);

        container.dispose();
      });

      test('emitWithMeta delivers source and extraData', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        BusMetadata? capturedMeta;
        action.listenWithMeta((v, meta) {
          capturedMeta = meta;
        });
        action.emit(
          42,
          source: 'test-screen',
            extraData: {'key': 123},
        );

        expect(capturedMeta!.source, 'test-screen');
        expect(capturedMeta!.extraData, {'key': 123});

        container.dispose();
      });

      test('non-meta listener still works unchanged', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        int? captured;
        action.listen((v) {
          captured = v;
        });
        action.emit(42);

        expect(captured, 42);

        container.dispose();
      });

      test('listenManuallyWithMeta works', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        BusMetadata? capturedMeta;
        final disposable = action.listenManuallyWithMeta((v, meta) {
          capturedMeta = meta;
        });
        action.emit(42, source: 'manual');

        expect(capturedMeta!.source, 'manual');
        disposable.dispose();
        container.dispose();
      });

      test('listenAsyncWithMeta delivers metadata', () async {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        BusMetadata? capturedMeta;
        action.listenAsyncWithMeta((v, meta) async {
          capturedMeta = meta;
        });
        await action.emitAsync(
          42,
          source: 'async',
        );

        expect(capturedMeta!.source, 'async');
        container.dispose();
      });

      test('listenManuallyAsyncWithMeta delivers metadata', () async {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        BusMetadata? capturedMeta;
        final disposable = action.listenManuallyAsyncWithMeta((v, meta) async {
          capturedMeta = meta;
        });
        await action.emitAsync(
          42,
          source: 'manual-async',
        );

        expect(capturedMeta!.source, 'manual-async');
        disposable.dispose();
        container.dispose();
      });

      test('sticky with metadata', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        // Emit with metadata, then subscribe sticky
        action.emit(42, source: 'sticky-source');

        BusMetadata? capturedMeta;
        action.listenWithMeta((v, meta) {
          capturedMeta = meta;
        }, sticky: true);

        expect(capturedMeta!.source, 'sticky-source');

        container.dispose();
      });

      test('metadata flows through middleware to listener', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        action.applyMiddleware((value, next) {
          next(value);
        });

        BusMetadata? capturedMeta;
        action.listenWithMeta((v, meta) {
          capturedMeta = meta;
        });
        action.emit(
          42,
          source: 'middleware-test',
        );

        expect(capturedMeta!.source, 'middleware-test');
        container.dispose();
      });
    });

    group('where', () {
      test('listener with where receives matching values', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final captured = <int>[];
        action.listen((v) {
          captured.add(v);
        }, where: (v, _) => v > 0);

        action.emit(1);
        action.emit(-1);
        action.emit(2);

        expect(captured, [1, 2]);

        container.dispose();
      });

      test('listener with where skips non-matching values', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final captured = <int>[];
        action.listen((v) {
          captured.add(v);
        }, where: (v, _) => v.isEven);

        action.emit(1);
        action.emit(2);
        action.emit(3);

        expect(captured, [2]);

        container.dispose();
      });

      test('where with listenWithMeta works', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final captured = <int>[];
        action.listenWithMeta((v, meta) {
          captured.add(v);
        }, where: (v, _) => v > 0);

        action.emit(5);
        action.emit(0);

        expect(captured, [5]);

        container.dispose();
      });

      test('where with listenAsync works', () async {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final captured = <int>[];
        action.listenAsync((v) async {
          captured.add(v);
        }, where: (v, _) => v > 0);

        await action.emitAsync(10);
        await action.emitAsync(-5);

        expect(captured, [10]);

        container.dispose();
      });

      test('where with listenManually works', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final captured = <int>[];
        final disposable = action.listenManually((v) {
          captured.add(v);
        }, where: (v, _) => v != 0);

        action.emit(0);
        action.emit(1);

        expect(captured, [1]);

        disposable.dispose();
        container.dispose();
      });

      test('where with sticky filters cached delivery', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        // Emit a value, then subscribe sticky with where
        action.emit(-1);

        final captured = <int>[];
        action.listen((v) {
          captured.add(v);
        }, sticky: true, where: (v, _) => v > 0);

        // Cached value (-1) doesn't match where, so nothing delivered
        expect(captured, isEmpty);

        // But new emissions that match do trigger
        action.emit(5);
        expect(captured, [5]);

        container.dispose();
      });

      test('where does not affect other listeners', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final all = <int>[];
        final filtered = <int>[];

        action.listen((v) {
          all.add(v);
        });
        action.listen((v) {
          filtered.add(v);
        }, where: (v, _) => v.isEven);

        action.emit(1);
        action.emit(2);

        expect(all, [1, 2]);
        expect(filtered, [2]);

        container.dispose();
      });

      test('where can filter by metadata source', () {
        final container = ProviderContainer();
        final action = container.read(
          Provider<EventBusActionForRef<int>>(
            (ref) => ref.event(EventBusConstants.onSecureInt),
          ),
        );

        final captured = <int>[];
        action.listenWithMeta((v, meta) {
          captured.add(v);
        }, where: (v, meta) => meta.source == 'trusted');

        action.emit(1, source: 'trusted');
        action.emit(2, source: 'untrusted');
        action.emit(3, source: 'trusted');

        expect(captured, [1, 3]);

        container.dispose();
      });
    });
  });

  group('SubEvent', () {
    test('subEvent receives only values that pass its where', () {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      globalRef.subEvent(EventBusConstants.evenSecureInt).listen((v) {
        captured.add(v);
      });

      globalRef.event(EventBusConstants.onSecureInt).emit(1);
      globalRef.event(EventBusConstants.onSecureInt).emit(2);
      globalRef.event(EventBusConstants.onSecureInt).emit(3);
      globalRef.event(EventBusConstants.onSecureInt).emit(4);

      expect(captured, [2, 4]);
      container.dispose();
    });

    test('subEvent with sticky receives last matching cached value', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(1);
      action.emit(2);

      final captured = <int>[];
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      }));

      expect(captured, [2]);
      container.dispose();
    });

    test('subEvent with sticky does not receive non-matching cached value',
        () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(1);
      action.emit(3);

      final captured = <int>[];
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      }));

      expect(captured, isEmpty);
      container.dispose();
    });

    test('subEvent has its own sticky cache independent from parent', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      // Register a first listener to populate the subEvent cache
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {});
      }));

      action.emit(2);
      action.emit(4);

      // Clear parent sticky — subEvent should still have its own cache
      action.clearSticky();

      final captured = <int>[];
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      }));

      expect(captured, [4]);
      container.dispose();
    });

    test('subEvent clearSticky removes only subEvent cached value', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      // Register a first listener to populate the subEvent cache
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {});
      }));

      action.emit(2);
      action.emit(4);

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      subAction.clearSticky();
      action.clearSticky(); // also clear parent so backfill doesn't interfere

      final captured = <int>[];
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {
          captured.add(v);
        }, sticky: true);
      }));

      expect(captured, isEmpty);
      container.dispose();
    });

    test('subEvent with listenManually and dispose', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      final disposable = subAction.listenManually((v) {
        captured.add(v);
      });

      container.read(Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).emit(2);
      }));

      expect(captured, [2]);

      disposable.dispose();

      container.read(Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).emit(4);
      }));

      expect(captured, [2]);
      container.dispose();
    });

    test('subEvent with listenManually and sticky', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(2);

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      final disposable = subAction.listenManually((v) {
        captured.add(v);
      }, sticky: true);

      expect(captured, [2]);

      disposable.dispose();
      container.dispose();
    });

    test('subEvent with listenAsync receives matching values', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listenAsync((v) async {
          captured.add(v);
        });
      }));

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      await action.emitAsync(1);
      await action.emitAsync(2);

      expect(captured, [2]);
      container.dispose();
    });

    test('subEvent stream receives filtered values', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      final sub = globalRef
          .subEvent(EventBusConstants.evenSecureInt)
          .stream()
          .listen((v) => captured.add(v));

      globalRef.event(EventBusConstants.onSecureInt).emit(1);
      globalRef.event(EventBusConstants.onSecureInt).emit(2);
      globalRef.event(EventBusConstants.onSecureInt).emit(3);
      globalRef.event(EventBusConstants.onSecureInt).emit(4);
      await Future(() {});

      expect(captured, [2, 4]);

      await sub.cancel();
      container.dispose();
    });

    test('subEvent with additional where in listen further narrows values', () {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      // even only
      globalRef.subEvent(EventBusConstants.evenSecureInt).listen((v) {
        captured.add(v);
      }, where: (v, _) => v > 2);

      globalRef.event(EventBusConstants.onSecureInt).emit(2);
      globalRef.event(EventBusConstants.onSecureInt).emit(4);
      globalRef.event(EventBusConstants.onSecureInt).emit(6);

      expect(captured, [4, 6]);
      container.dispose();
    });

    test('multiple subEvents of the same parent work independently', () {
      final evenCaptured = <int>[];
      final positiveCaptured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      globalRef.subEvent(EventBusConstants.evenSecureInt).listen((v) {
        evenCaptured.add(v);
      });
      globalRef.subEvent(EventBusConstants.positiveInt).listen((v) {
        positiveCaptured.add(v);
      });

      globalRef.event(EventBusConstants.onSecureInt).emit(-2);
      globalRef.event(EventBusConstants.onSecureInt).emit(0);
      globalRef.event(EventBusConstants.onSecureInt).emit(3);
      globalRef.event(EventBusConstants.onSecureInt).emit(4);

      expect(evenCaptured, [-2, 0, 4]);
      expect(positiveCaptured, [3, 4]);
      container.dispose();
    });

    test('subEvent clearListeners removes only subEvent listeners', () {
      final subEventCaptured = <int>[];
      final parentCaptured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      globalRef.subEvent(EventBusConstants.evenSecureInt).listen((v) {
        subEventCaptured.add(v);
      });
      globalRef.event(EventBusConstants.onSecureInt).listen((v) {
        parentCaptured.add(v);
      });

      container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      ).clearListeners();

      globalRef.event(EventBusConstants.onSecureInt).emit(2);
      globalRef.event(EventBusConstants.onSecureInt).emit(4);

      expect(subEventCaptured, isEmpty);
      expect(parentCaptured, [2, 4]);
      container.dispose();
    });

    test('subEvent hasClients works correctly', () {
      final container = ProviderContainer();

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      expect(subAction.hasClients, false);

      final disposable = subAction.listenManually((v) {});

      expect(subAction.hasClients, true);

      disposable.dispose();
      expect(subAction.hasClients, false);

      container.dispose();
    });

    test('subEvent auto-dispose cleans up when provider invalidated', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listen((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(2);
      expect(captured, [2]);

      container.invalidate(listenerProvider);
      action.emit(4);
      expect(captured, [2]);

      container.dispose();
    });

    test('lastValue returns null before emission', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );
      expect(action.lastValue, isNull);
      container.dispose();
    });

    test('lastValue returns emitted value', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );
      action.emit(42);
      expect(action.lastValue, 42);
      action.emit(100);
      expect(action.lastValue, 100);
      container.dispose();
    });

    test('lastValue returns null after clearSticky', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );
      action.emit(42);
      expect(action.lastValue, 42);
      action.clearSticky();
      expect(action.lastValue, isNull);
      container.dispose();
    });

    test('subEvent lastValue returns null before emission', () {
      final container = ProviderContainer();
      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );
      expect(subAction.lastValue, isNull);
      container.dispose();
    });

    test('subEvent lastValue returns matching value after emission', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );
      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );
      action.emit(1); // odd, shouldn't reach subEvent
      expect(subAction.lastValue, isNull);

      action.emit(2); // even, should reach subEvent
      expect(subAction.lastValue, 2);

      action.emit(4); // even, should update
      expect(subAction.lastValue, 4);

      container.dispose();
    });

    test('subEvent lastValue returns null after clearSticky', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );
      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );
      action.emit(2);
      expect(subAction.lastValue, 2);

      subAction.clearSticky();
      action.clearSticky(); // prevent backfill
      expect(subAction.lastValue, isNull);

      container.dispose();
    });
  });

  group('listenOnce — event', () {
    test('listenOnce fires once and auto-removes', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenOnce((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      action.emit(42);
      expect(captured, [42]);

      action.emit(99);
      expect(captured, [42]);

      container.dispose();
    });

    test('listenOnce with sticky receives cached value once', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(42);

      final captured = <int>[];
      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenOnce((v) {
          captured.add(v);
        }, sticky: true);
      });
      container.read(listenerProvider);
      expect(captured, [42]);

      action.emit(99);
      expect(captured, [42]);

      container.dispose();
    });

    test('listenOnce auto-dispose cleans up on provider invalidate', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenOnce((v) {
          captured.add(v);
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);
      container.invalidate(listenerProvider);

      action.emit(42);
      expect(captured, isEmpty);

      container.dispose();
    });

    test('listenOnceWithMeta fires once with metadata', () {
      final container = ProviderContainer();
      BusMetadata? capturedMeta;
      int? capturedValue;

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenOnceWithMeta((v, meta) {
          capturedMeta = meta;
          capturedValue = v;
        });
      });

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(listenerProvider);

      action.emit(42, source: 'once-source');
      expect(capturedValue, 42);
      expect(capturedMeta!.source, 'once-source');

      capturedValue = null;
      action.emit(99);
      expect(capturedValue, isNull);

      container.dispose();
    });

    test('listenOnceManually fires once and auto-removes', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.listenOnceManually((v) {
        captured.add(v);
      });

      action.emit(10);
      expect(captured, [10]);

      action.emit(20);
      expect(captured, [10]);

      container.dispose();
    });

    test('listenOnceManually with sticky receives cached value once', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(42);

      final captured = <int>[];
      action.listenOnceManually((v) {
        captured.add(v);
      }, sticky: true);

      expect(captured, [42]);

      action.emit(99);
      expect(captured, [42]);

      container.dispose();
    });

    test('listenOnceManually with where matches once then auto-removes', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.listenOnceManually((v) {
        captured.add(v);
      }, where: (v, _) => v > 0);

      action.emit(-1);
      expect(captured, isEmpty);

      action.emit(5);
      expect(captured, [5]);

      action.emit(10);
      expect(captured, [5]);

      container.dispose();
    });

    test('listenOnceManually with onError catches error once', () {
      final capturedErrors = <Object>[];
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.listenOnceManually((v) {
        captured.add(v);
        throw Exception('boom: $v');
      }, onError: (e, st) => capturedErrors.add(e));

      action.emit(1);
      expect(captured, [1]);
      expect(capturedErrors.length, 1);

      action.emit(2);
      expect(captured, [1]);

      container.dispose();
    });

    test('listenOnceManually dispose prevents listener from firing', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      final disposable = action.listenOnceManually((v) {
        captured.add(v);
      });

      disposable.dispose();

      action.emit(42);
      expect(captured, isEmpty);

      container.dispose();
    });

    test('listenOnceManuallyWithMeta fires once', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      BusMetadata? capturedMeta;
      int? capturedValue;
      action.listenOnceManuallyWithMeta((v, meta) {
        capturedValue = v;
        capturedMeta = meta;
      });

      action.emit(7, source: 'manual-once');
      expect(capturedValue, 7);
      expect(capturedMeta!.source, 'manual-once');

      capturedValue = null;
      action.emit(8);
      expect(capturedValue, isNull);

      container.dispose();
    });
  });

  group('listenOnce — subEvent', () {
    test('listenOnce fires only on first matching emission', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listenOnce((v) {
          captured.add(v);
        });
      }));

      action.emit(1);
      expect(captured, isEmpty);

      action.emit(2);
      expect(captured, [2]);

      action.emit(4);
      expect(captured, [2]);

      container.dispose();
    });

    test('listenOnce with sticky receives cached matching value once', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(1);
      action.emit(2);

      final captured = <int>[];
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listenOnce((v) {
          captured.add(v);
        }, sticky: true);
      }));

      expect(captured, [2]);

      action.emit(4);
      expect(captured, [2]);

      container.dispose();
    });

    test('listenOnce with additional where filter', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listenOnce((v) {
          captured.add(v);
        }, where: (v, _) => v > 2);
      }));

      action.emit(2);
      expect(captured, isEmpty);

      action.emit(4);
      expect(captured, [4]);

      action.emit(6);
      expect(captured, [4]);

      container.dispose();
    });

    test('listenOnceManually fires once then auto-removes', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      subAction.listenOnceManually((v) {
        captured.add(v);
      });

      action.emit(2);
      expect(captured, [2]);

      action.emit(4);
      expect(captured, [2]);

      container.dispose();
    });

    test('listenOnceManually with sticky receives cached value once', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      action.emit(2);

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      final captured = <int>[];
      subAction.listenOnceManually((v) {
        captured.add(v);
      }, sticky: true);

      expect(captured, [2]);

      action.emit(4);
      expect(captured, [2]);

      container.dispose();
    });

    test('listenOnceManually dispose prevents listener from firing', () {
      final captured = <int>[];
      final container = ProviderContainer();

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      final disposable = subAction.listenOnceManually((v) {
        captured.add(v);
      });

      disposable.dispose();

      action.emit(2);
      expect(captured, isEmpty);

      container.dispose();
    });

    test('listenOnceManuallyWithMeta fires once', () {
      final container = ProviderContainer();

      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.evenSecureInt),
        ),
      );

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      BusMetadata? capturedMeta;
      int? capturedValue;
      subAction.listenOnceManuallyWithMeta((v, meta) {
        capturedValue = v;
        capturedMeta = meta;
      });

      action.emit(2, source: 'sub-once');
      expect(capturedValue, 2);
      expect(capturedMeta!.source, 'sub-once');

      capturedValue = null;
      action.emit(4);
      expect(capturedValue, isNull);

      container.dispose();
    });

    test('listenOnceWithMeta fires once', () {
      final container = ProviderContainer();

      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );

      BusMetadata? capturedMeta;
      int? capturedValue;
      container.read(Provider<void>((ref) {
        ref.subEvent(EventBusConstants.evenSecureInt).listenOnceWithMeta((v, meta) {
          capturedValue = v;
          capturedMeta = meta;
        });
      }));

      action.emit(2, source: 'sub-once-meta');
      expect(capturedValue, 2);
      expect(capturedMeta!.source, 'sub-once-meta');

      capturedValue = null;
      action.emit(4);
      expect(capturedValue, isNull);

      container.dispose();
    });
  });

  group('history', () {
    test('history vacío antes de emitir', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      expect(action.history, isEmpty);
      container.dispose();
    });

    test('history captura valores emitidos en orden', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      action.emit(10);
      action.emit(20);
      action.emit(30);

      final h = action.history;
      expect(h.length, 3);
      expect(h[0].value, 10);
      expect(h[1].value, 20);
      expect(h[2].value, 30);
      container.dispose();
    });

    test('history respeta historySize', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      for (int i = 1; i <= 10; i++) {
        action.emit(i);
      }

      final h = action.history;
      expect(h.length, 5);
      expect(h[0].value, 6);
      expect(h[4].value, 10);
      container.dispose();
    });

    test('history guarda metadata', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      action.emit(1, source: 'test', extraData: {'key': 42});

      final h = action.history;
      expect(h.length, 1);
      expect(h[0].value, 1);
      expect(h[0].metadata.source, 'test');
      expect(h[0].metadata.extraData, {'key': 42});
      container.dispose();
    });

    test('history guarda valor post-middleware', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      action.applyMiddleware((value, next) => next(value * 10));
      action.emit(5);

      final h = action.history;
      expect(h.length, 1);
      expect(h[0].value, 50);
      container.dispose();
    });

    test('clearHistory vacía el buffer', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      action.emit(1);
      action.emit(2);
      expect(action.history.length, 2);

      action.clearHistory();
      expect(action.history, isEmpty);

      action.emit(3);
      expect(action.history.length, 1);
      expect(action.history[0].value, 3);
      container.dispose();
    });

    test('historySize 0 no captura nada', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onSecureInt),
        ),
      );
      action.emit(1);
      action.emit(2);
      expect(action.history, isEmpty);
      container.dispose();
    });

    test('subEvent history independiente del padre', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.historyEvenInt),
        ),
      );
      // Register the subEvent so it fires on parent emit
      subAction.listen((v) {});

      action.emit(1);
      action.emit(2);
      action.emit(3);
      action.emit(4);

      final parentHistory = action.history;
      expect(parentHistory.length, 4);

      final subHistory = subAction.history;
      expect(subHistory.length, 2);
      expect(subHistory[0].value, 2);
      expect(subHistory[1].value, 4);
      container.dispose();
    });

    test('subEvent history respeta su historySize', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.historyEvenInt),
        ),
      );
      subAction.listen((v) {});
      for (int i = 1; i <= 10; i++) {
        action.emit(i);
      }

      final subHistory = subAction.history;
      expect(subHistory.length, 3);
      expect(subHistory[0].value, 6);
      expect(subHistory[1].value, 8);
      expect(subHistory[2].value, 10);
      container.dispose();
    });

    test('clearHistory en subEvent', () {
      final container = ProviderContainer();
      final action = container.read(
        Provider<EventBusActionForRef<int>>(
          (ref) => ref.event(EventBusConstants.onHistoryInt),
        ),
      );
      final subAction = container.read(
        Provider<SubEventActionForRef<int>>(
          (ref) => ref.subEvent(EventBusConstants.historyEvenInt),
        ),
      );
      subAction.listen((v) {});
      action.emit(2);
      action.emit(4);
      expect(subAction.history.length, 2);

      subAction.clearHistory();
      expect(subAction.history, isEmpty);

      action.emit(6);
      expect(subAction.history.length, 1);
      expect(subAction.history[0].value, 6);
      container.dispose();
    });
  });
}
