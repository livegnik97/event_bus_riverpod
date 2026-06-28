import 'dart:ui';

class ListenerDisposable {
  final VoidCallback _dispose;

  ListenerDisposable(this._dispose);

  void dispose() => _dispose();
}
