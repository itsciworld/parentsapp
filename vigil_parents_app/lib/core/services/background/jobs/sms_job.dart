import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Polls the SMS endpoint every 5 seconds and reports new messages.
class SmsSyncJob implements BackgroundJob {
  @override
  String get name => 'sms_sync';

  @override
  Duration get interval => const Duration(seconds: 5);

  /// Last seen total, so we only announce genuinely new messages.
  int _lastTotal = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = SmsRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      debugPrint('SMS: skip — no session/child yet');
      _setNotification(service, 'Waiting for sign-in…');
      return;
    }

    final res = await repo.getSms(childId: ctx.childId, parentId: ctx.parentId);

    if (_lastTotal >= 0 && res.total > _lastTotal) {
      debugPrint('SMS: new message received');
    } else {
      debugPrint('SMS: skip — no new msg');
    }
    _lastTotal = res.total;

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    _setNotification(service, 'Last sync: $hh:$mm • ${res.total} msgs');

    // Let the UI isolate refresh if it's listening.
    service.invoke('sms_update', {'total': res.total});
  }

  void _setNotification(ServiceInstance service, String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: 'Vigil', content: content);
    }
  }
}
