import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/live_status/repo/live_status_repo.dart';

/// Polls the child's live-status endpoint periodically so battery and
/// connectivity stay fresh even while the app is in the background.
class LiveStatusSyncJob implements BackgroundJob {
  @override
  String get name => 'live_status_sync';

  @override
  Duration get interval => const Duration(seconds: 60);

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = LiveStatusRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      debugPrint('LiveStatus: skip — no session/child yet');
      return;
    }

    final res = await repo.fetchLiveStatus(ctx.childId);
    debugPrint(
      'LiveStatus: ${res.isOnline ? "online" : "offline"} • '
      'battery ${res.battery.level ?? "?"}% • ${res.connectivity.label}',
    );

    // Let the UI isolate refresh if it's listening.
    service.invoke('live_status_update', {
      'childId': res.childId,
      'isOnline': res.isOnline,
      'batteryLevel': res.battery.level,
    });
  }
}
