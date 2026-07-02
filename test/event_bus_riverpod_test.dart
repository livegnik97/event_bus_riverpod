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

    test('stream registers listener only on listen, not on stream creation', () async {
      final captured = <int>[];
      final container = ProviderContainer();

      late Ref globalRef;
      container.read(Provider<void>((ref) => globalRef = ref));

      // Crear stream sin escuchar
      final stream = globalRef
          .event(EventBusConstants.onSecureInt)
          .stream();

      // Should have no listeners
      expect(
        globalRef.event(EventBusConstants.onSecureInt).hasClients,
        false,
      );

      // Ahora suscribirse
      final sub = stream.listen((v) => captured.add(v));

      // Now there should be a listener
      expect(
        globalRef.event(EventBusConstants.onSecureInt).hasClients,
        true,
      );

      globalRef.event(EventBusConstants.onSecureInt).emit(1);
      await Future(() {});
      expect(captured, [1]);

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

    test('listenAsync and emitAsync basic', () async {
      final captured = <String>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onUserName).listenAsync(
          (name) async {
            await Future(() {});
            captured.add(name);
          },
        );
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
        ref.event(EventBusConstants.onSecureInt).listenAsync(
          (v) async {
            await Future.delayed(const Duration(milliseconds: 10));
            log.add(v);
          },
        );
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
        ref.event(EventBusConstants.onSecureInt).listenAsync(
          (v) async {
            await Future(() {});
            asyncLog.add(v);
          },
        );
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

      final disposable = action.listenManuallyAsync(
        (v) async {
          await Future(() {});
          captured.add(v);
        },
      );

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
        ref.event(EventBusConstants.onSecureInt).listenAsync(
          (v) async {
            await Future(() {});
            throw Exception('async fail: $v');
          },
          onError: (e, st) => capturedErrors.add(e),
        );
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

    test('emitAsync other listeners still run when one async listener fails', () async {
      final captured = <int>[];
      final capturedErrors = <Object>[];
      final container = ProviderContainer();

      final listenerProvider = Provider<void>((ref) {
        ref.event(EventBusConstants.onSecureInt).listenAsync(
          (v) async {
            await Future(() {});
            throw Exception('fail');
          },
          onError: (e, st) => capturedErrors.add(e),
        );
        ref.event(EventBusConstants.onSecureInt).listenAsync(
          (v) async {
            await Future(() {});
            captured.add(v);
          },
        );
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
    });

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
  });
}