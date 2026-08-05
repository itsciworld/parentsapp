import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';

/// Drives a screen's polling timer and ties it to the app's lifecycle.
///
/// Previously each screen started a bare `Timer.periodic` in `initState` and
/// cancelled it in `dispose`. Because nothing paused it, a screen left open
/// while the app was minimised kept polling — at the same time as the
/// background service, which resumes exactly then. Both hit the same endpoints,
/// which is precisely the duplication the foreground/background handover was
/// built to avoid.
///
/// Use it on a `State` that also mixes in [WidgetsBindingObserver]:
///
/// ```dart
/// class _FooViewState extends ConsumerState<FooView>
///     with WidgetsBindingObserver, PollingScreen<FooView> {
///   @override
///   Duration get pollInterval => const Duration(seconds: 5);
///
///   @override
///   String? get pollFeature => SyncFeature.sms;
///
///   @override
///   void onPoll() => ref.read(fooViewModelProvider).refresh();
/// }
/// ```
mixin PollingScreen<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _pollTimer;

  /// How often [onPoll] runs while the app is in the foreground.
  Duration get pollInterval;

  /// One polling tick.
  void onPoll();

  /// The [SyncFeature] this screen shows, when a background job covers it.
  ///
  /// On resume the catch-up poll is skipped if the background service already
  /// confirmed this feature didn't change. Leave it null for features with no
  /// background job (location, AI insights, social) — those always catch up,
  /// since nothing was keeping them fresh while we were away.
  String? get pollFeature => null;

  /// Start polling and observing lifecycle. Call from `initState`.
  void startPolling() {
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  /// Stop polling and unregister. Call from `dispose`.
  void stopPolling() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel();
  }

  void _schedule() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => onPoll());
  }

  void _cancel() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final feature = pollFeature;
      if (feature == null || SyncSignals.shouldRefresh(feature)) onPoll();
      _schedule();
    } else {
      // paused / inactive / hidden / detached — the background service takes
      // over from here, so this screen must stop competing with it.
      _cancel();
    }
  }
}
