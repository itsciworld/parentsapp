import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil_parents_app/core/utils/refresh_guard.dart';
import 'package:vigil_parents_app/features/calls/repo/call_repo.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';
import 'package:vigil_parents_app/features/gallery/repo/gallery_repo.dart';
import 'package:vigil_parents_app/features/notifications/repo/social_notification_repo.dart';
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
    // Switching child invalidates the cached counts: they are compared against
    // a per-child "seen" baseline, so carrying the previous child's numbers
    // across would badge the new one with someone else's history.
    if (ctx.childId != _childId) {
      _smsTotal = _contactsTotal = _callsTotal = _galleryTotal = 0;
      _notificationsTotal = 0;
    }
    _childId = ctx.childId;

    // Each count is fetched on its own so one sick endpoint can only blank its
    // own badge. The batch used to share a single try/catch that `return`ed on
    // the first failure, which left *every* tile on its previous value — zero
    // on a cold start. That is how a feature full of messages ended up behind
    // a bare tile: the data was there, the badge simply never got computed.
    // limit:1 — we only need the size of each collection, not the rows.
    final counts = await Future.wait([
      _probe('sms', () async {
        final r = await _sms.getSms(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        );
        return _sizeOf(total: r.total, pages: r.pages, rows: r.messages.length);
      }),
      _probe('contacts', () async {
        final r = await _contacts.getContacts(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        );
        return _sizeOf(total: r.total, pages: r.pages, rows: r.contacts.length);
      }),
      _probe('calls', () async {
        final r = await _calls.getCallLogs(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        );
        return _sizeOf(total: r.total, pages: r.pages, rows: r.callLogs.length);
      }),
      _probe('gallery', () async {
        final r = await _gallery.getFiles(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        );
        return _sizeOf(total: r.total, pages: r.pages, rows: r.items.length);
      }),
      _probe('notifications', () async {
        final r = await _notifications.getNotifications(
          childId: ctx.childId,
          parentId: ctx.parentId,
        );
        return r.totalMessages > 0 ? r.totalMessages : r.total;
      }),
    ]);

    // null means "that request failed" — keep the count we already had rather
    // than reporting an empty feature we have no evidence for.
    _smsTotal = counts[0] ?? _smsTotal;
    _contactsTotal = counts[1] ?? _contactsTotal;
    _callsTotal = counts[2] ?? _callsTotal;
    _galleryTotal = counts[3] ?? _galleryTotal;
    _notificationsTotal = counts[4] ?? _notificationsTotal;

    smsUnseen = await _computeUnseen('sms', _smsTotal);
    contactsUnseen = await _computeUnseen('contacts', _contactsTotal);
    callsUnseen = await _computeUnseen('calls', _callsTotal);
    galleryUnseen = await _computeUnseen('gallery', _galleryTotal);
    notificationsUnseen = await _computeUnseen(
      'notifications',
      _notificationsTotal,
    );

    if (kDebugMode) {
      print(
        '🔴 [Badges] child=$_childId '
        'sms=$smsUnseen/$_smsTotal contacts=$contactsUnseen/$_contactsTotal '
        'calls=$callsUnseen/$_callsTotal gallery=$galleryUnseen/$_galleryTotal '
        'bell=$notificationsUnseen/$_notificationsTotal',
      );
    }

    notifyListeners();
  }

  /// Runs one count request, returning null when it fails so the caller can
  /// keep the previous value for that feature alone.
  Future<int?> _probe(String feature, Future<int> Function() fetch) async {
    try {
      return await fetch();
    } catch (e) {
      if (kDebugMode) print('⚠️  [Badges] $feature count failed: $e');
      return null;
    }
  }

  /// Reads the size of a paginated collection.
  ///
  /// `total` is the intended source, but it is only as trustworthy as the
  /// endpoint sending it — a response that omits the key (or sends 0) while
  /// still serving rows would otherwise report an empty feature. These probes
  /// ask for a single row, so `pages` *is* the row count, and the rows
  /// themselves are the last resort.
  int _sizeOf({required int total, required int pages, required int rows}) {
    if (total > 0) return total;
    if (pages > 0) return pages;
    return rows;
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
    final key = _seenKey(feature, _childId);
    int seen;
    try {
      seen = await _prefs.getInt(key) ?? 0;
    } catch (_) {
      // A value stored under this key with another type would throw here and
      // take every badge down with it. Treating it as "nothing seen" is the
      // recoverable reading — the next tap rewrites the key correctly.
      seen = 0;
    }

    // The collection shrank: a retention window rolled over, items were
    // deleted, or the baseline was written from a count the backend no longer
    // reports. Left alone, that high-water mark sits above every future total
    // and silently swallows new items forever — a badge that never returns
    // once it has cleared. Re-baseline to what actually exists.
    if (seen > total) {
      await _prefs.setInt(key, total);
      return 0;
    }

    return total - seen;
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
