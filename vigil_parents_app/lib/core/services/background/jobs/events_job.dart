import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/events/repo/events_repo.dart';

/// Polls the events endpoint periodically and reports new events.
class EventsSyncJob implements BackgroundJob {
  @override
  String get name => 'events_sync';

  @override
  Duration get interval => const Duration(minutes: 90);

  /// Last seen total, so we only report genuinely new events.
  int _lastTotal = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = EventsRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) return;

    // limit:1 — we only need the total to detect new events cheaply.
    final res = await repo.getEvents(
      childId: ctx.childId,
      parentId: ctx.parentId,
      page: 1,
      limit: 1,
    );

    final changed = _lastTotal >= 0 && res.total != _lastTotal;
    _lastTotal = res.total;

    reportSync(service, SyncFeature.events, changed: changed);
  }
}
