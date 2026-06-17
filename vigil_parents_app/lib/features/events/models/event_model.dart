// Maps the /api/events/get_events response:
// { status, total, page, limit, pages, events: [ {_id, title, start, end,
//   location, description, child_id, parent_id} ] }

/// High-level kind of event, derived from its description / meeting link.
/// Drives the accent color, icon and chip label on the UI.
enum EventCategory { meeting, holiday, observance, general }

class EventModel {
  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final String? description;
  final String childId;
  final String parentId;

  const EventModel({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.description,
    required this.childId,
    required this.parentId,
  });

  /// True when the event spans (almost) a full day or longer — holidays etc.
  bool get isAllDay {
    final e = end;
    if (e == null) return false;
    return e.difference(start).inHours >= 20;
  }

  String get displayTitle => title.trim().isEmpty ? 'Untitled event' : title.trim();

  bool get hasLocation => (location ?? '').trim().isNotEmpty;

  // ── Google Calendar / Meet cleanup ────────────────────────────────────────
  // The backend stores raw Google Calendar descriptions, which carry a lot of
  // boilerplate (Meet dial-in blocks, "Please do not edit this section", the
  // "-::~:~::-" separators, observance footers). We surface a clean description
  // and pull the Meet link out as a first-class "Join" action.

  static final RegExp _meetLinkRe =
      RegExp(r'https://meet\.google\.com/[^\s]+');

  /// The Google Meet URL embedded in the description, if any.
  String? get meetLink {
    final m = _meetLinkRe.firstMatch(description ?? '');
    return m?.group(0);
  }

  bool get isOnlineMeeting => meetLink != null;

  /// Description with all the Google Calendar/Meet noise stripped out. Empty
  /// when nothing meaningful remains (e.g. a pure Meet invite).
  String get cleanDescription {
    final d = description;
    if (d == null || d.trim().isEmpty) return '';
    final kept = <String>[];
    for (final raw in d.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // Separator rows made only of '-', ':' and '~'.
      if (RegExp(r'^[-~:]{6,}$').hasMatch(line.replaceAll(' ', ''))) continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('please do not edit')) continue;
      if (lower.startsWith('join with google meet')) continue;
      if (lower.startsWith('or dial')) continue;
      if (lower.startsWith('more phone numbers')) continue;
      if (lower.startsWith('learn more about meet')) continue;
      if (lower.startsWith('to hide observances')) continue;
      if (lower.contains('pin:') && lower.contains('+')) continue;
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  /// A short one-line summary for the list card — clean description, or a
  /// sensible fallback for meetings/holidays that carry no real text.
  String get summary {
    final clean = cleanDescription;
    if (clean.isNotEmpty) return clean.replaceAll('\n', ' ');
    if (isOnlineMeeting) return 'Google Meet';
    return '';
  }

  bool get hasDescription => cleanDescription.isNotEmpty;

  EventCategory get category {
    if (isOnlineMeeting) return EventCategory.meeting;
    final d = (description ?? '').toLowerCase();
    if (d.contains('holiday')) return EventCategory.holiday;
    if (d.contains('observance')) return EventCategory.observance;
    return EventCategory.general;
  }

  /// The calendar day this event belongs to (local time, time stripped).
  DateTime get day => DateTime(start.year, start.month, start.day);

  /// e.g. "Mon, 02 Oct 2025".
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = start;
    final wd = days[(d.weekday - 1) % 7];
    final dd = d.day.toString().padLeft(2, '0');
    return '$wd, $dd ${months[d.month - 1]} ${d.year}';
  }

  /// e.g. "9:30 AM" — empty for all-day events.
  String get formattedTime {
    if (isAllDay) return 'All day';
    final dt = start;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// "9:30 AM – 11:00 AM" or "All day" — used in the detail row.
  String get formattedRange {
    if (isAllDay) return 'All day';
    final e = end;
    final from = formattedTime;
    if (e == null) return from;
    final to = _clockLabel(e);
    return '$from – $to';
  }

  static String _clockLabel(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      start: _toDate(json['start']) ?? DateTime.now(),
      end: _toDate(json['end']),
      location: json['location']?.toString(),
      description: json['description']?.toString(),
      childId: (json['child_id'] ?? '').toString(),
      parentId: (json['parent_id'] ?? '').toString(),
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  /// Collapses events that are effectively the same (identical title, dates,
  /// location and description) but arrive with different `_id`s. The backend
  /// can return the same event many times, so the calendar, list and the home
  /// badge all rely on this to avoid double-counting.
  static List<EventModel> dedupe(List<EventModel> events) {
    final seen = <String>{};
    final out = <EventModel>[];
    for (final e in events) {
      final key = [
        e.displayTitle.toLowerCase(),
        e.start.toIso8601String(),
        e.end?.toIso8601String() ?? '',
        (e.location ?? '').trim().toLowerCase(),
        (e.description ?? '').trim().toLowerCase(),
      ].join('|');
      if (seen.add(key)) out.add(e);
    }
    return out;
  }
}

class EventsResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<EventModel> events;

  const EventsResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.events,
  });

  factory EventsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['events'];
    final events = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => EventModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <EventModel>[];

    return EventsResponse(
      status: _toInt(json['status'], fallback: 200),
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      limit: _toInt(json['limit'], fallback: 20),
      pages: _toInt(json['pages']),
      events: events,
    );
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
