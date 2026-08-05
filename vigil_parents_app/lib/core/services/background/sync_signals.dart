import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

/// Feature keys shared between the background jobs and the screens.
abstract final class SyncFeature {
  static const String sms = 'sms';
  static const String calls = 'calls';
  static const String contacts = 'contacts';
  static const String events = 'events';
  static const String media = 'media';
  static const String appUsage = 'app_usage';
  static const String liveStatus = 'live_status';
}

/// The single channel every background job reports on.
const String kSyncUpdateEvent = 'sync_update';

/// Reports the outcome of one sync tick to the UI isolate.
void reportSync(
  ServiceInstance service,
  String feature, {
  required bool changed,
}) {
  service.invoke(kSyncUpdateEvent, {'feature': feature, 'changed': changed});
}

/// Records which features the background service saw change while the app was
/// away, so coming back only re-fetches what actually moved.
///
/// The background isolate can't hand Dart objects to the UI isolate — only
/// JSON over `service.invoke`. Rather than serialise whole payloads, each job
/// reports a one-bit "this feature changed" signal and the screens stay
/// authoritative about their own data. That keeps the jobs cheap and avoids
/// two copies of every model's parsing logic.
///
/// Before this existed the jobs did call `service.invoke`, but nothing in the
/// app ever subscribed, so every background fetch was discarded.
class SyncSignals {
  SyncSignals._();

  static final Set<String> _dirty = <String>{};

  /// Whether any signal has arrived since [markAwayPeriodStart].
  static bool _heardFromService = false;

  static StreamSubscription<Map<String, dynamic>?>? _subscription;

  /// Begins listening. Safe to call more than once.
  static void start() {
    if (_subscription != null) return;
    try {
      _subscription = FlutterBackgroundService()
          .on(kSyncUpdateEvent)
          .listen(_onSignal);
    } catch (e) {
      debugPrint('SyncSignals: could not subscribe → $e');
    }
  }

  static void _onSignal(Map<String, dynamic>? data) {
    _heardFromService = true;
    if (data == null) return;
    final feature = data['feature'];
    if (feature is String && data['changed'] == true) _dirty.add(feature);
  }

  /// Call when the app leaves the foreground, so the next return can tell
  /// "nothing changed" apart from "the service never ran".
  static void markAwayPeriodStart() {
    _heardFromService = false;
    _dirty.clear();
  }

  /// Whether [feature] should be re-fetched now that the app is back.
  ///
  /// True when the service reported a change — and also when it reported
  /// nothing at all. Android 15 stops a `dataSync` service after six hours a
  /// day, so silence from a service that may simply be dead must never be read
  /// as "nothing happened".
  ///
  /// Deliberately non-consuming. More than one listener can care about the same
  /// feature — an open SMS screen and Home's badges both watch `sms` — and a
  /// read that cleared the flag would let whichever ran first starve the other.
  /// The whole set is reset by [markAwayPeriodStart] instead, so flags never
  /// outlive the away period they describe.
  static bool shouldRefresh(String feature) =>
      !_heardFromService || _dirty.contains(feature);
}
