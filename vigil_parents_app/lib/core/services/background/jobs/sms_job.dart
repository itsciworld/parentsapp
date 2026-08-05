import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Polls the SMS endpoint every 5 seconds and reports new messages.
class SmsSyncJob implements BackgroundJob {
  @override
  String get name => 'sms_sync';

  @override
  Duration get interval => const Duration(seconds: 30);

  /// Last seen total, so we only announce genuinely new messages.
  int _lastTotal = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = SmsRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      // Two different situations, and they used to share one (wrong) message:
      // a signed-in parent with nothing linked was told to sign in.
      if (!ctx.hasSession) {
        debugPrint('SMS: skip — no session yet');
        _setNotification(service, 'Waiting for sign-in…');
      } else {
        debugPrint('SMS: skip — signed in, no child linked yet');
        _setNotification(
          service,
          'No child linked yet — set up the Vigil Child app',
        );
      }
      return;
    }

    final res = await repo.getSms(childId: ctx.childId, parentId: ctx.parentId);

    final changed = _lastTotal >= 0 && res.total > _lastTotal;
    debugPrint(changed ? 'SMS: new message received' : 'SMS: no new msg');
    _lastTotal = res.total;

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    _setNotification(service, 'Last sync: $hh:$mm • ${res.total} msgs');

    reportSync(service, SyncFeature.sms, changed: changed);
  }

  void _setNotification(ServiceInstance service, String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: 'Vigil', content: content);
    }
  }
}
