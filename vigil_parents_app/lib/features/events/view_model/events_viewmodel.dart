import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/events/models/event_model.dart';
import 'package:vigil_parents_app/features/events/repo/events_repo.dart';

/// Drives the Events screen: loads every (de-duplicated) event for the selected
/// child. The Syncfusion calendar handles per-date markers + the agenda itself,
/// so this VM only needs the flat list (plus a "nearest first" ordering for the
/// All-Events list below the calendar).
class EventsViewModel extends ChangeNotifier {
  final EventsRepository repository;

  EventsViewModel(this.repository);

  List<EventModel> _all = [];
  bool loading = false;
  String? error;

  /// Every loaded event — handed to the calendar data source so it can render
  /// markers on the right days and power its agenda.
  List<EventModel> get allEvents => _all;

  int get totalEvents => _all.length;

  /// All events sorted with the nearest upcoming event first, then past events
  /// (most recent first). Feeds the scrollable list under the calendar.
  List<EventModel> get sortedEvents => _sortedNearestFirst(_all);

  /// Events that fall on [day], earliest first.
  ///
  /// Google Calendar API stores dates in UTC. When converted to local time
  /// (e.g. IST +5:30), a UTC midnight can shift to the previous/next local
  /// day. The Syncfusion calendar, however, uses the local dates from
  /// [getStartTime]/[getEndTime] for its indicator dots. We match broadly:
  /// an event matches [day] if:
  ///   1. Its local start day == [day], OR
  ///   2. Its UTC start day == [day] (catches timezone-shifted events), OR
  ///   3. [day] falls within the local start→end range (multi-day events).
  List<EventModel> eventsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final list = _all.where((e) {
      // Local-time start day
      final startLocal = DateTime(e.start.year, e.start.month, e.start.day);
      if (startLocal == d) return true;

      // UTC start day (handles timezone shift where local date ≠ UTC date)
      final utc = e.start.toUtc();
      final startUtc = DateTime(utc.year, utc.month, utc.day);
      if (startUtc == d) return true;

      // Multi-day / all-day range check
      final end = e.end;
      if (end != null) {
        final endLocal = DateTime(end.year, end.month, end.day);
        // Event spans this day if it starts before end-of-day AND ends on/after day
        if (!startLocal.isAfter(d) && !endLocal.isBefore(d)) return true;
        // Also check UTC range
        final endUtc = e.end!.toUtc();
        final endUtcDay = DateTime(endUtc.year, endUtc.month, endUtc.day);
        if (!startUtc.isAfter(d) && !endUtcDay.isBefore(d)) return true;
      }

      return false;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// Upcoming events first (soonest → latest), then past events (most recent
  /// first). "Latest near event shows first" in the user's words.
  List<EventModel> _sortedNearestFirst(List<EventModel> source) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final list = [...source];
    list.sort((a, b) {
      final aPast = a.start.isBefore(todayStart);
      final bPast = b.start.isBefore(todayStart);
      if (aPast != bPast) return aPast ? 1 : -1; // upcoming group first
      if (!aPast) return a.start.compareTo(b.start); // soonest upcoming first
      return b.start.compareTo(a.start); // most recent past first
    });
    return list;
  }

  Future<void> loadEvents({bool showLoader = true}) async {
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) {
        _all = [];
        error = ctx.childId.isEmpty
            ? 'No child linked to this account yet'
            : 'Missing account information';
      } else {
        final fetched = await repository.fetchAllEvents(
          childId: ctx.childId,
          parentId: ctx.parentId,
        );
        _all = EventModel.dedupe(fetched);
        error = null;
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Reloads from scratch — used when the selected child changes.
  Future<void> reload() async {
    _all = [];
    await loadEvents();
  }

  Future<void> refresh() => loadEvents(showLoader: false);
}

final eventsViewModelProvider = ChangeNotifierProvider((ref) {
  return EventsViewModel(EventsRepository());
});
