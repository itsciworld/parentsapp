import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/features/live_status/repo/live_status_repo.dart';

/// Polls the child's live-status endpoint periodically so battery and
/// connectivity stay fresh even while the app is in the background.
class LiveStatusSyncJob implements BackgroundJob {
  @override
  String get name => 'live_status_sync';

  @override
  Duration get interval => const Duration(seconds: 40);

  /// Online state + battery level at the last poll, so an unchanged status
  /// doesn't ask the UI to re-fetch on resume.
  String? _lastSignature;

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

    final signature = '${res.isOnline}/${res.battery.level}';
    final changed = _lastSignature != null && signature != _lastSignature;
    _lastSignature = signature;

    reportSync(service, SyncFeature.liveStatus, changed: changed);
  }
}
