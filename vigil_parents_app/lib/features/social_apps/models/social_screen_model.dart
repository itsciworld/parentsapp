// Maps GET /api/social/screen — captured on-screen chat messages from the
// child's social apps, grouped per app.

/// A single captured chat message (one conversation line).
class ScreenMessage {
  final String id;
  final String conversation;
  final String text;
  final DateTime? capturedAt;
  final DateTime? createdAt;

  const ScreenMessage({
    required this.id,
    required this.conversation,
    required this.text,
    required this.capturedAt,
    required this.createdAt,
  });

  factory ScreenMessage.fromJson(Map<String, dynamic> json) {
    return ScreenMessage(
      id: json['_id']?.toString() ?? '',
      conversation: json['conversation']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      capturedAt: DateTime.tryParse(json['captured_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
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
  final List<ScreenMessage> messages;

  const ScreenThread({
    required this.conversation,
    required this.count,
    required this.lastTime,
    required this.lastPreview,
    required this.messages,
  });

  factory ScreenThread.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(ScreenMessage.fromJson)
              .toList()
        : <ScreenMessage>[];

    return ScreenThread(
      conversation: json['conversation']?.toString() ?? 'Unknown',
      count: (json['count'] as num?)?.toInt() ?? messages.length,
      lastTime: DateTime.tryParse(json['lastTime']?.toString() ?? ''),
      lastPreview: json['lastPreview']?.toString() ?? '',
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

  factory SocialAppMessages.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'];
    final messages = rawMsgs is List
        ? rawMsgs
              .whereType<Map<String, dynamic>>()
              .map(ScreenMessage.fromJson)
              .toList()
        : <ScreenMessage>[];

    final rawThreads = json['threads'];
    var threads = rawThreads is List
        ? rawThreads
              .whereType<Map<String, dynamic>>()
              .map(ScreenThread.fromJson)
              .toList()
        : <ScreenThread>[];

    // Backward-compat: if the API didn't send threads, derive them by grouping
    // the flat message list on its conversation.
    if (threads.isEmpty && messages.isNotEmpty) {
      threads = _threadsFrom(messages);
    }

    return SocialAppMessages(
      app: json['app']?.toString() ?? 'Unknown',
      package: json['package']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? messages.length,
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
      final msgs = [...e.value]
        ..sort((a, b) => _cmpDesc(a.timestamp, b.timestamp));
      final latest = msgs.first;
      return ScreenThread(
        conversation: e.key,
        count: msgs.length,
        lastTime: latest.timestamp,
        lastPreview: latest.text,
        messages: msgs,
      );
    }).toList()
      ..sort((a, b) => _cmpDesc(a.lastTime, b.lastTime));
    return threads;
  }
}

/// Newest-first comparator tolerant of null timestamps.
int _cmpDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
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
    final raw = json['apps'];
    final apps = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(SocialAppMessages.fromJson)
              .toList()
        : <SocialAppMessages>[];

    return SocialScreenResponse(
      total: (json['total'] as num?)?.toInt() ?? apps.length,
      totalMessages: (json['totalMessages'] as num?)?.toInt() ?? 0,
      windowSince: DateTime.tryParse(json['windowSince']?.toString() ?? ''),
      apps: apps,
    );
  }
}
