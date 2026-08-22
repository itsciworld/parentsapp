// Maps GET /api/social/screen — captured on-screen chat messages from the
// child's social apps, grouped per app.

import 'package:vigil_parents_app/core/utils/api_date.dart';

/// A single captured chat message (one conversation line).
class ScreenMessage {
  final String id;
  final String conversation;
  final String text;
  final DateTime? capturedAt;
  final DateTime? createdAt;

  /// Who wrote the line, when the capture carries it — used to label incoming
  /// messages in group threads. Empty when unknown.
  final String sender;

  /// True when the child sent this message, so it renders as a right-aligned
  /// bubble — the same treatment `SmsMessage.isSent` drives in the SMS
  /// conversation view.
  final bool isOutgoing;

  const ScreenMessage({
    required this.id,
    required this.conversation,
    required this.text,
    required this.capturedAt,
    required this.createdAt,
    required this.sender,
    required this.isOutgoing,
  });

  factory ScreenMessage.fromJson(Map<String, dynamic> json) {
    return ScreenMessage(
      id: json['_id']?.toString() ?? '',
      conversation: json['conversation']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      // parseApiDate, not DateTime.tryParse: the capture sends epoch values as
      // often as ISO strings, and tryParse reads those as "no date at all".
      capturedAt: parseApiDate(json['captured_at']),
      createdAt: parseApiDate(json['createdAt']),
      sender: (json['sender'] ?? json['from'] ?? '').toString(),
      isOutgoing: _outgoingFrom(json),
    );
  }

  /// Reads the message's direction out of whatever shape the capture sent.
  ///
  /// On-screen capture has expressed this as a boolean, as an SMS-style
  /// `direction`/`type` string, and as a `sender` of "me" — so all three are
  /// accepted. With none of them present the message is treated as received,
  /// which is exactly how the screen rendered before direction existed, so a
  /// capture that doesn't report it loses nothing.
  static bool _outgoingFrom(Map<String, dynamic> json) {
    for (final key in const [
      'is_outgoing',
      'isOutgoing',
      'from_me',
      'fromMe',
      'is_sent',
      'isSent',
    ]) {
      final v = json[key];
      if (v is bool) return v;
    }

    final direction = (json['direction'] ?? json['type'] ?? json['kind'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (direction.isNotEmpty) {
      return direction == 'sent' ||
          direction == 'outgoing' ||
          direction == 'out' ||
          direction == 'outbox';
    }

    final sender = (json['sender'] ?? json['from'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return sender == 'me' ||
        sender == 'self' ||
        sender == 'you' ||
        sender == 'child';
  }

  /// The moment used for sorting/display — prefers when the message was
  /// captured, falling back to when we stored it.
  DateTime? get timestamp => capturedAt ?? createdAt;
}

/// A single conversation thread within an app — all messages exchanged with
/// one person/group, SMS-inbox style.
class ScreenThread {
  final String conversation;
  final int count;
  final DateTime? lastTime;
  final String lastPreview;

  /// Sorted oldest → newest, so the chat view reads top to bottom exactly like
  /// the SMS conversation does. The screen used to sort these newest-first and
  /// still render them downwards, which made every conversation read backwards.
  final List<ScreenMessage> messages;

  const ScreenThread({
    required this.conversation,
    required this.count,
    required this.lastTime,
    required this.lastPreview,
    required this.messages,
  });

  factory ScreenThread.fromJson(Map<String, dynamic> json) {
    final messages = _mapsFrom(
      json['messages'],
    ).map(ScreenMessage.fromJson).toList();

    messages.sort((a, b) => _cmpAsc(a.timestamp, b.timestamp));

    final latest = messages.isEmpty ? null : messages.last;

    return ScreenThread(
      conversation: json['conversation']?.toString() ?? 'Unknown',
      count: (json['count'] as num?)?.toInt() ?? messages.length,
      // Fall back to the thread's own newest message when the server omits
      // these, so the inbox row still shows a time and a preview.
      lastTime: parseApiDate(json['lastTime']) ?? latest?.timestamp,
      lastPreview: json['lastPreview']?.toString() ?? latest?.text ?? '',
      messages: messages,
    );
  }
}

/// One social app and the chat messages captured from it, grouped into
/// conversation [threads]. The flat [messages] list is kept for backward-compat.
class SocialAppMessages {
  final String app;
  final String package;
  final int count;
  final List<ScreenThread> threads;
  final List<ScreenMessage> messages;

  const SocialAppMessages({
    required this.app,
    required this.package,
    required this.count,
    required this.threads,
    required this.messages,
  });

  /// Stable key for "which app is being viewed".
  ///
  /// The screen used to key that off [package] alone, which breaks completely
  /// when the server omits it: every app collapses onto the same empty string,
  /// so the selector marks them all active, `selectedApp` always resolves to
  /// the first one, and tapping any other chip is a no-op because the view
  /// model sees the selection as unchanged. Falling back to the app's name
  /// keeps each entry distinct whatever the payload carries.
  String get id {
    final pkg = package.trim();
    if (pkg.isNotEmpty) return pkg;
    return app.trim().toLowerCase();
  }

  factory SocialAppMessages.fromJson(Map<String, dynamic> json) {
    var threads = _mapsFrom(
      json['threads'],
    ).map(ScreenThread.fromJson).toList();

    // The flat list only exists as a fallback for responses that predate
    // `threads`. When the server sends both, parsing it too builds every
    // message object a second time for nobody — on a 200-message payload
    // that is half the parse work thrown away — so it is read only when
    // there are no threads to group from.
    var messages = <ScreenMessage>[];
    if (threads.isEmpty) {
      messages = _mapsFrom(
        json['messages'],
      ).map(ScreenMessage.fromJson).toList();
      if (messages.isNotEmpty) threads = _threadsFrom(messages);
    }

    return SocialAppMessages(
      app: json['app']?.toString() ?? 'Unknown',
      package: json['package']?.toString() ?? '',
      // With threads in hand the flat list is empty, so the count has to come
      // off the threads themselves rather than `messages.length`.
      count:
          (json['count'] as num?)?.toInt() ??
          threads.fold<int>(0, (sum, t) => sum + t.count),
      threads: threads,
      messages: messages,
    );
  }

  /// Groups a flat message list into conversation threads (newest activity
  /// first), used when the API only returns the flat list.
  static List<ScreenThread> _threadsFrom(List<ScreenMessage> messages) {
    final byConversation = <String, List<ScreenMessage>>{};
    for (final m in messages) {
      final key = m.conversation.isNotEmpty ? m.conversation : 'Unknown';
      byConversation.putIfAbsent(key, () => []).add(m);
    }

    final threads = byConversation.entries.map((e) {
      // Oldest → newest inside the thread, matching ScreenThread.fromJson, so
      // the chat view can render the list as-is either way.
      final msgs = [...e.value]
        ..sort((a, b) => _cmpAsc(a.timestamp, b.timestamp));
      final latest = msgs.last;
      return ScreenThread(
        conversation: e.key,
        count: msgs.length,
        lastTime: latest.timestamp,
        lastPreview: latest.text,
        messages: msgs,
      );
    }).toList()..sort((a, b) => _cmpDesc(a.lastTime, b.lastTime));
    return threads;
  }
}

/// Normalises a JSON array into a list of string-keyed maps.
///
/// The old code filtered with `whereType<Map<String, dynamic>>()`, which looks
/// equivalent but is not: anything that arrives as `Map<dynamic, dynamic>` —
/// which is what a re-encoded, cached or transformed Dio response hands back —
/// fails that test and is dropped **silently**, producing an empty screen with
/// no error while the server's payload was full. SMS and gallery already parse
/// the safe way; this brings social in line.
List<Map<String, dynamic>> _mapsFrom(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

/// Newest-first comparator tolerant of null timestamps.
int _cmpDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// Oldest-first comparator tolerant of null timestamps. Undated messages sort
/// to the top rather than breaking the run of real ones at the bottom.
int _cmpAsc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Full response wrapper for /api/social/screen.
class SocialScreenResponse {
  final int total;
  final int totalMessages;

  /// Oldest timestamp included by the server's day/hour window, if provided.
  final DateTime? windowSince;
  final List<SocialAppMessages> apps;

  const SocialScreenResponse({
    required this.total,
    required this.totalMessages,
    required this.windowSince,
    required this.apps,
  });

  factory SocialScreenResponse.fromJson(Map<String, dynamic> json) {
    // Some endpoints wrap the payload in `data`/`result` and some return it
    // flat. Reading only the flat shape meant a wrapped response parsed to
    // zero apps with no error at all — the screen just said "no messages"
    // while the body was full of them.
    final body = _unwrap(json);

    final apps = _mapsFrom(
      body['apps'],
    ).map(SocialAppMessages.fromJson).toList();

    return SocialScreenResponse(
      total: (body['total'] as num?)?.toInt() ?? apps.length,
      totalMessages:
          (body['totalMessages'] as num?)?.toInt() ??
          apps.fold<int>(0, (sum, a) => sum + a.count),
      windowSince: parseApiDate(body['windowSince']),
      apps: apps,
    );
  }

  /// Returns the object actually holding `apps`, looking one level into the
  /// common envelope keys before giving up and using the body as-is.
  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    if (json['apps'] is List) return json;
    for (final key in const ['data', 'result', 'payload']) {
      final inner = json[key];
      if (inner is Map && inner['apps'] is List) {
        return Map<String, dynamic>.from(inner);
      }
    }
    return json;
  }
}
