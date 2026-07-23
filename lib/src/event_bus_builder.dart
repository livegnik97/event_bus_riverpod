import 'package:event_bus_riverpod/src/event_bus_extension.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier.dart';
import 'package:event_bus_riverpod/src/event_bus_identifier_base.dart';
import 'package:event_bus_riverpod/src/event_bus_provider.dart';
import 'package:event_bus_riverpod/src/listener_disposable.dart';
import 'package:event_bus_riverpod/src/sub_event_identifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A widget that rebuilds whenever an event is emitted.
///
/// Accepts both [EventBusIdentifier] and [SubEventIdentifier] via the
/// common [EventBusIdentifierBase] type.
///
/// ```dart
/// EventBusBuilder<int>(
///   event: onCounter,
///   builder: (context, value) => Text('${value ?? 0}'),
///   sticky: true,
/// )
/// ```
class EventBusBuilder<T> extends ConsumerStatefulWidget {
  final EventBusIdentifierBase<T> event;
  final Widget Function(BuildContext context, T? value) builder;
  final bool sticky;
  final ListenerWhere<T>? where;
  final int priority;
  final T? initialData;

  const EventBusBuilder({
    super.key,
    required this.event,
    required this.builder,
    this.sticky = false,
    this.where,
    this.priority = 0,
    this.initialData,
  });

  @override
  ConsumerState<EventBusBuilder<T>> createState() =>
      _EventBusBuilderState<T>();
}

class _EventBusBuilderState<T> extends ConsumerState<EventBusBuilder<T>> {
  T? _value;
  ListenerDisposable? _disposable;

  @override
  void initState() {
    super.initState();
    _tryDeliverInitial();
    _subscribe();
  }

  T? _tryGetSticky() {
    if (widget.event is SubEventIdentifier<T>) {
      return ref
          .subEvent(widget.event as SubEventIdentifier<T>)
          .lastValue;
    }
    return ref
        .event(widget.event as EventBusIdentifier<T>)
        .lastValue;
  }

  void _tryDeliverInitial() {
    if (widget.sticky) {
      final stickyValue = _tryGetSticky();
      if (stickyValue != null) {
        _value = stickyValue;
        return;
      }
    }
    if (widget.initialData != null) {
      _value = widget.initialData;
    }
  }

  void _onValue(T value) {
    if (mounted) setState(() => _value = value);
  }

  void _subscribe() {
    _disposable?.dispose();
    if (widget.event is SubEventIdentifier<T>) {
      _disposable = ref
          .subEvent(widget.event as SubEventIdentifier<T>)
          .listenManually(
            _onValue,
            where: widget.where,
            priority: widget.priority,
          );
    } else {
      _disposable = ref
          .event(widget.event as EventBusIdentifier<T>)
          .listenManually(
            _onValue,
            where: widget.where,
            priority: widget.priority,
          );
    }
  }

  @override
  void didUpdateWidget(EventBusBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final eventChanged = widget.event.key != oldWidget.event.key;
    final paramsChanged = widget.where != oldWidget.where ||
        widget.priority != oldWidget.priority;
    if (eventChanged || paramsChanged) {
      _subscribe();
    }
    if (eventChanged ||
        widget.sticky != oldWidget.sticky ||
        widget.initialData != oldWidget.initialData) {
      _value = null;
      _tryDeliverInitial();
    }
  }

  @override
  void dispose() {
    _disposable?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value);
  }
}
