import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/core/services/background/jobs/sms_job.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  GLOBAL BACKGROUND SERVICE
///  A single foreground/background isolate that drives many periodic jobs.
///  This is intentionally generic — to add future work (location, calls,
///  gallery, …) just implement a [BackgroundJob] and register it in [_jobs].
/// ─────────────────────────────────────────────────────────────────────────

/// Register every recurring background job here.
final List<BackgroundJob> _jobs = <BackgroundJob>[SmsSyncJob()];

/// Base tick resolution. Each job decides its own cadence via [BackgroundJob.interval].
const Duration _tick = Duration(seconds: 1);

const String _channelId = 'vigil_monitoring';
const String _channelName = 'Vigil Monitoring';

/// Call once from `main()` (after `dotenv.load`).
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  final notifications = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'Keeps Vigil monitoring active in the background',
    importance: Importance.low,
  );
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: _channelId,
      initialNotificationTitle: 'Vigil',
      initialNotificationContent: 'Monitoring is active',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// iOS background fetch — iOS schedules wake-ups itself, so we just run every
/// due job once per wake-up.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _ensureEnv();
  await _runDueJobs(service);
  return true;
}

/// Main entry point for the background isolate (Android + iOS foreground).
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _ensureEnv();

  service.on('stopService').listen((_) => service.stopSelf());

  await _runDueJobs(service);
  Timer.periodic(_tick, (_) => _runDueJobs(service));
}

/// Runs each registered job whose [BackgroundJob.interval] has elapsed.
final Map<String, DateTime> _lastRun = {};
Future<void> _runDueJobs(ServiceInstance service) async {
  final now = DateTime.now();
  for (final job in _jobs) {
    final last = _lastRun[job.name];
    if (last != null && now.difference(last) < job.interval) continue;
    _lastRun[job.name] = now;
    try {
      await job.run(service);
    } catch (e) {
      debugPrint('⚠️ Background job "${job.name}" failed → $e');
    }
  }
}

/// dotenv state isn't shared with the background isolate, so load it here too.
bool _envLoaded = false;
Future<void> _ensureEnv() async {
  if (_envLoaded) return;
  try {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env');
    }
    _envLoaded = true;
  } catch (e) {
    debugPrint('Background: failed to load .env → $e');
  }
}
