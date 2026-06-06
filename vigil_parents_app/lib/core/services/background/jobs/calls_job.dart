import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/calls/repo/call_repo.dart';

/// Polls the call-logs endpoint periodically and reports new calls.
class CallsSyncJob implements BackgroundJob {
  @override
  String get name => 'calls_sync';

  @override
  Duration get interval => const Duration(seconds: 30);

  /// Last seen total, so we only announce genuinely new calls.
  int _lastTotal = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = CallLogRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      debugPrint('Calls: skip — no session/child yet');
      return;
    }

    final res = await repo.getCallLogs(
      childId: ctx.childId,
      parentId: ctx.parentId,
    );

    if (_lastTotal >= 0 && res.total > _lastTotal) {
      debugPrint('Calls: new call logged');
    } else {
      debugPrint('Calls: skip —  parent no new call');
    }
    _lastTotal = res.total;

    // Let the UI isolate refresh if it's listening.
    service.invoke('calls_update', {'total': res.total});
  }
}
