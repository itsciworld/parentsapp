import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vigil_parents_app/core/services/background/jobs/background_job.dart';
import 'package:vigil_parents_app/features/gallery/repo/gallery_repo.dart';

/// Polls the media endpoint and reports when new files appear for the child.
class MediaSyncJob implements BackgroundJob {
  @override
  String get name => 'media_sync';

  @override
  Duration get interval => const Duration(minutes: 2);

  /// Last seen total, so we only announce genuinely new media.
  int _lastTotal = -1;

  @override
  Future<void> run(ServiceInstance service) async {
    final repo = GalleryRepository();
    final ctx = await repo.resolveContext();

    if (!ctx.isValid) {
      debugPrint('Media: skip — no session/child yet');
      return;
    }

    final res = await repo.getFiles(
      childId: ctx.childId,
      parentId: ctx.parentId,
    );

    if (_lastTotal >= 0 && res.total > _lastTotal) {
      debugPrint('Media: ${res.total - _lastTotal} new file(s) received');
    } else {
      debugPrint('Media: no new files');
    }
    _lastTotal = res.total;

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Vigil',
        content: 'Media sync: $hh:$mm • ${res.total} files',
      );
    }

    // Let the UI isolate refresh if it's listening.
    service.invoke('media_update', {'total': res.total});
  }
}
