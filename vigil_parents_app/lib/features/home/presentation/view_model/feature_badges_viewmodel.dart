import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/calls/repo/call_repo.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';
import 'package:vigil_parents_app/features/events/models/event_model.dart';
import 'package:vigil_parents_app/features/events/repo/events_repo.dart';
import 'package:vigil_parents_app/features/sms/models/sms_model.dart';
import 'package:vigil_parents_app/features/sms/repo/sms_repo.dart';

/// Computes the home feature-tile badges as the number of *unseen* items per
/// feature (sms / contacts / calls) for the selected child. Opening a feature
/// marks it seen (badge clears) until new items arrive.
class FeatureBadgesViewModel extends ChangeNotifier {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final SmsRepository _sms = SmsRepository();
  final ContactsRepository _contacts = ContactsRepository();
  final CallLogRepository _calls = CallLogRepository();
  final EventsRepository _events = EventsRepository();

  int smsUnseen = 0;
  int contactsUnseen = 0;
  int callsUnseen = 0;
  int eventsUnseen = 0;

  int _smsTotal = 0;
  int _contactsTotal = 0;
  int _callsTotal = 0;
  int _eventsTotal = 0;
  String _childId = '';

  static String _seenKey(String feature, String childId) =>
      'badge_seen_${feature}_$childId';

  /// Maps a home tile id to the unseen count (0 when none / untracked).
  int unseenFor(String tileId) {
    switch (tileId) {
      case 'sms':
        return smsUnseen;
      case 'Contacts':
        return contactsUnseen;
      case 'calls':
        return callsUnseen;
      case 'events':
        return eventsUnseen;
      default:
        return 0;
    }
  }

  Future<void> load() async {
    final ctx = await _sms.resolveContext();
    if (!ctx.isValid) {
      _childId = '';
      smsUnseen = contactsUnseen = callsUnseen = eventsUnseen = 0;
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
        _events.getEvents(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: 1,
        ),
      ]);

      _smsTotal = (results[0] as SmsResponse).total;
      _contactsTotal = (results[1] as ContactsResponse).total;
      _callsTotal = (results[2] as CallLogsResponse).total;
      _eventsTotal = (results[3] as EventsResponse).total;
    } catch (_) {
      return; // keep previous values on a transient failure
    }

    smsUnseen = await _computeUnseen('sms', _smsTotal);
    contactsUnseen = await _computeUnseen('contacts', _contactsTotal);
    callsUnseen = await _computeUnseen('calls', _callsTotal);
    eventsUnseen = await _computeUnseen('events', _eventsTotal);
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
      'events' => 'events',
      _ => null,
    };
    if (feature == null || _childId.isEmpty) return;

    final total = switch (feature) {
      'sms' => _smsTotal,
      'contacts' => _contactsTotal,
      'calls' => _callsTotal,
      'events' => _eventsTotal,
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
      case 'events':
        eventsUnseen = 0;
    }
    notifyListeners();
  }
}

final featureBadgesProvider = ChangeNotifierProvider((ref) {
  return FeatureBadgesViewModel();
});
