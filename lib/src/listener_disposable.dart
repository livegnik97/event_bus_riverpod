class ListenerDisposable {
  final void Function() _dispose;

  ListenerDisposable(this._dispose);

  void dispose() => _dispose();
}
