import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/app_usage/repo/app_usage_repo.dart';

/// Periodically syncs the child's app-usage stats so the Home "Activity
/// Overview" card and detail view stay fresh even while the app is backgrounded.
class AppUsageSyncJob implements BackgroundJob {
  @override
  String get name => 'app_usage_sync';

  @override
  Duration get interval => const Duration(minutes: 2);

  /// Last seen app count, so we only report when the set actually changes.
  int _lastTotal = -1;

  /// Last seen total usage minutes — the part that actually moves.
  int _lastMinutes = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = AppUsageRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      debugPrint('AppUsage: skip — no session/child yet');
      return;
    }

    final apps = await repo.getApps(
      childId: ctx.childId,
      parentId: ctx.parentId,
    );

    final totalMinutes = apps.fold<int>(0, (sum, a) => sum + a.usageMinutes);

    // Usage minutes tick up constantly, so the *minutes* are what makes this
    // feature stale — not just the app list changing.
    final changed =
        _lastTotal >= 0 &&
        (apps.length != _lastTotal || totalMinutes != _lastMinutes);
    if (changed) debugPrint('AppUsage: usage changed (${apps.length} apps)');
    _lastTotal = apps.length;
    _lastMinutes = totalMinutes;

    reportSync(service, SyncFeature.appUsage, changed: changed);
  }
}
