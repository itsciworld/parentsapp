/// Serialises a view-model's polling refreshes so only one runs at a time.
///
/// Every polled screen fires its timer on a fixed interval regardless of
/// whether the previous request has come back. On a slow connection that
/// stacked requests — a 5s timer against a 30s timeout can leave six in flight
/// at once — and whichever response landed last won, so an *older* payload
/// could overwrite a newer one on screen.
///
/// Dropping the tick is the right behaviour for polling: the data is about to
/// be re-requested anyway, seconds later. This deliberately does not apply to
/// user-initiated loads (opening a screen, pull-to-refresh, switching child) —
/// those must always run.
mixin RefreshGuard {
  bool _refreshInFlight = false;

  /// True while a [guardedRefresh] is running.
  bool get isRefreshing => _refreshInFlight;

  /// Runs [task] unless one is already in flight, in which case this call is
  /// dropped.
  Future<void> guardedRefresh(Future<void> Function() task) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      await task();
    } finally {
      _refreshInFlight = false;
    }
  }
}
