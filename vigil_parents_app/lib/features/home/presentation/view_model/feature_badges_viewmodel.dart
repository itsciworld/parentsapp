import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil_parents_app/core/utils/refresh_guard.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/calls/repo/call_repo.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/features/gallery/repo/gallery_repo.dart';
import 'package:vigil_parents_app/features/notifications/models/social_notification_model.dart';
import 'package:vigil_parents_app/features/notifications/repo/social_notification_repo.dart';
import 'package:vigil_parents_app/features/sms/models/sms_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Computes the home feature-tile badges as the number of *unseen* items per
/// feature (sms / contacts / calls) for the selected child, plus the unseen
/// count behind the notification bell. Opening a feature marks it seen (badge
/// clears) until new items arrive.
class FeatureBadgesViewModel extends ChangeNotifier with RefreshGuard {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final SmsRepository _sms = SmsRepository();
  final ContactsRepository _contacts = ContactsRepository();
  final CallLogRepository _calls = CallLogRepository();
  final GalleryRepository _gallery = GalleryRepository();
  final SocialNotificationRepository _notifications =
      SocialNotificationRepository();

  int smsUnseen = 0;
  int contactsUnseen = 0;
  int callsUnseen = 0;
  int galleryUnseen = 0;

  /// Drives the notification bell's dot. Stays at 0 while no child is linked,
  /// so the bell is never marked unread for an account with nothing to show.
  int notificationsUnseen = 0;

  int _smsTotal = 0;
  int _contactsTotal = 0;
  int _callsTotal = 0;
  int _galleryTotal = 0;
  int _notificationsTotal = 0;
  String _childId = '';

  static String _seenKey(String feature, String childId) =>
      'badge_seen_${feature}_$childId';

  /// Maps a home tile id to the unseen count (0 when none / untracked).
  ///
  /// Events are deliberately untracked: their badge needed the *full* event
  /// list on every refresh (the backend returns duplicates, so a count can't be
  /// taken from `total`), which made it by far the most expensive call here for
  /// the least useful badge. Events now load only when their screen is opened.
  int unseenFor(String tileId) {
    switch (tileId) {
      case 'sms':
        return smsUnseen;
      case 'Contacts':
        return contactsUnseen;
      case 'calls':
        return callsUnseen;
      case 'gallery':
        return galleryUnseen;
      default:
        return 0;
    }
  }

  Future<void> load() => guardedRefresh(_load);

  Future<void> _load() async {
    final ctx = await _sms.resolveContext();
    if (!ctx.isValid) {
      // No session or no linked child — nothing can be unseen, so every badge
      // (including the notification bell's dot) has to read zero.
      _childId = '';
      smsUnseen = contactsUnseen = callsUnseen = galleryUnseen = 0;
      notificationsUnseen = 0;
      notifyListeners();
      return;
    }
    _childId = ctx.childId;

    try {
      // limit:1 — we only need the totals, not the rows.
      final results = await Future.wait([
        _sms.getSms(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        ),
        _contacts.getContacts(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        ),
        _calls.getCallLogs(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        ),
        _gallery.getFiles(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        ),
        // Absorbed rather than propagated: a failure here would abandon the
        // whole batch below and freeze the other five badges. An empty result
        // just clears the bell, which is the safe direction to fail in.
        _notifications
            .getNotifications(childId: ctx.childId, parentId: ctx.parentId)
            .catchError(
              (_) => const SocialNotificationsResponse(
                total: 0,
                totalMessages: 0,
                windowSince: null,
                apps: [],
              ),
            ),
      ]);

      _smsTotal = (results[0] as SmsResponse).total;
      _contactsTotal = (results[1] as ContactsResponse).total;
      _callsTotal = (results[2] as CallLogsResponse).total;
      _galleryTotal = (results[3] as MediaResponse).total;
      _notificationsTotal =
          (results[4] as SocialNotificationsResponse).totalMessages;
    } catch (_) {
      return; // keep previous values on a transient failure
    }

    smsUnseen = await _computeUnseen('sms', _smsTotal);
    contactsUnseen = await _computeUnseen('contacts', _contactsTotal);
    callsUnseen = await _computeUnseen('calls', _callsTotal);
    galleryUnseen = await _computeUnseen('gallery', _galleryTotal);
    notificationsUnseen = await _computeUnseen(
      'notifications',
      _notificationsTotal,
    );
    notifyListeners();
  }

  /// Clears the notification bell's dot — call when the bell is opened.
  Future<void> markNotificationsSeen() async {
    if (_childId.isEmpty) return;
    await _prefs.setInt(
      _seenKey('notifications', _childId),
      _notificationsTotal,
    );
    notificationsUnseen = 0;
    notifyListeners();
  }

  Future<int> _computeUnseen(String feature, int total) async {
    final seen = await _prefs.getInt(_seenKey(feature, _childId)) ?? 0;
    final unseen = total - seen;
    return unseen > 0 ? unseen : 0;
  }

  /// Marks a feature as seen (clears its badge). [tileId] is the home tile id.
  Future<void> markSeenForTile(String tileId) async {
    final feature = switch (tileId) {
      'sms' => 'sms',
      'Contacts' => 'contacts',
      'calls' => 'calls',
      'gallery' => 'gallery',
      _ => null,
    };
    if (feature == null || _childId.isEmpty) return;

    final total = switch (feature) {
      'sms' => _smsTotal,
      'contacts' => _contactsTotal,
      'calls' => _callsTotal,
      'gallery' => _galleryTotal,
      _ => 0,
    };
    await _prefs.setInt(_seenKey(feature, _childId), total);

    switch (feature) {
      case 'sms':
        smsUnseen = 0;
      case 'contacts':
        contactsUnseen = 0;
      case 'calls':
        callsUnseen = 0;
      case 'gallery':
        galleryUnseen = 0;
    }
    notifyListeners();
  }
}

final featureBadgesProvider = ChangeNotifierProvider((ref) {
  return FeatureBadgesViewModel();
});
