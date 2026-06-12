import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/app_usage/repo/app_usage_repo.dart';

/// Periodically syncs the child's app-usage stats so the Home "Activity
/// Overview" card and detail view stay fresh even while the app is backgrounded.
class AppUsageSyncJob implements BackgroundJob {
  @override
  String get name => 'app_usage_sync';

  @override
  Duration get interval => const Duration(minutes: 2);

  /// Last seen app count, so we only log when the set actually changes.
  int _lastTotal = -1;

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

    if (_lastTotal >= 0 && apps.length != _lastTotal) {
      debugPrint('AppUsage: app list changed (${apps.length} apps)');
    }
    _lastTotal = apps.length;

    // Let the UI isolate refresh if it's listening.
    service.invoke('app_usage_update', {
      'apps': apps.length,
      'minutes': totalMinutes,
    });
  }
}
