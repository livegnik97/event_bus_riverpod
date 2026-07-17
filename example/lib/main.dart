import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:event_bus_riverpod/event_bus_riverpod.dart';

final counterEvent = EventBusIdentifier<int>('counter');

class _Counter extends Notifier<int> {
  @override
  int build() {
    ref.event(counterEvent).listen((value) {
      state = state + value;
    }, sticky: true);
    return 0;
  }
}

final counterProvider = NotifierProvider<_Counter, int>(_Counter.new);

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('event_bus_riverpod')),
        body: Center(
          child: Text('$count', style: const TextStyle(fontSize: 48)),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => ref.event(counterEvent).emit(1),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
