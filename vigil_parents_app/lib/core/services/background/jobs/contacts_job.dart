import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';

/// Polls the contacts endpoint periodically and reports new contacts.
class ContactsSyncJob implements BackgroundJob {
  @override
  String get name => 'contacts_sync';

  @override
  Duration get interval => const Duration(seconds: 30);

  /// Last seen total, so we only announce genuinely new contacts.
  int _lastTotal = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = ContactsRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      debugPrint('Contacts: skip — no session/child yet');
      return;
    }

    final res = await repo.getContacts(
      childId: ctx.childId,
      parentId: ctx.parentId,
    );

    final changed = _lastTotal >= 0 && res.total > _lastTotal;
    debugPrint(changed ? 'Contacts: new contact' : 'Contacts: no new contact');
    _lastTotal = res.total;

    reportSync(service, SyncFeature.contacts, changed: changed);
  }
}
