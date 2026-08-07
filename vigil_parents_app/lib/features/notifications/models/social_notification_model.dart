// Maps GET /api/social/notifications — the social-app notifications captured
// on the child's device, grouped per app.

/// A single captured notification/message from a social app.
class SocialMessage {
  final String id;
  final String sender;
  final String body;
  final String groupName;
  final bool isGroup;
  final DateTime? postedAt;
  final DateTime? createdAt;

  const SocialMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.groupName,
    required this.isGroup,
    required this.postedAt,
    required this.createdAt,
  });

  factory SocialMessage.fromJson(Map<String, dynamic> json) {
    return SocialMessage(
      id: json['_id']?.toString() ?? '',
      sender: json['sender']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      isGroup: json['is_group'] == true,
      postedAt: DateTime.tryParse(json['posted_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  /// The moment used for sorting/display — prefers the original post time,
  /// falling back to when we captured it.
  DateTime? get timestamp => postedAt ?? createdAt;
}

/// A single conversation thread within an app — all notifications from one
/// person/group, SMS-inbox style.
class NotificationThread {
  final String conversation;
  final int count;
  final DateTime? lastTime;
  final String lastPreview;
  final List<SocialMessage> messages;

  const NotificationThread({
    required this.conversation,
    required this.count,
    required this.lastTime,
    required this.lastPreview,
    required this.messages,
  });

  factory NotificationThread.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(SocialMessage.fromJson)
              .toList()
        : <SocialMessage>[];

    return NotificationThread(
      conversation: json['conversation']?.toString() ?? 'Unknown',
      count: (json['count'] as num?)?.toInt() ?? messages.length,
      lastTime: DateTime.tryParse(json['lastTime']?.toString() ?? ''),
      lastPreview: json['lastPreview']?.toString() ?? '',
      messages: messages,
    );
  }
}

/// One social app and the notifications captured from it, grouped into
/// conversation [threads]. The flat [messages] list is kept for backward-compat.
class AppNotifications {
  final String app;
  final String package;
  final int count;
  final List<NotificationThread> threads;
  final List<SocialMessage> messages;

  const AppNotifications({
    required this.app,
    required this.package,
    required this.count,
    required this.threads,
    required this.messages,
  });

  factory AppNotifications.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'];
    final messages = rawMsgs is List
        ? rawMsgs
              .whereType<Map<String, dynamic>>()
              .map(SocialMessage.fromJson)
              .toList()
        : <SocialMessage>[];

    final rawThreads = json['threads'];
    var threads = rawThreads is List
        ? rawThreads
              .whereType<Map<String, dynamic>>()
              .map(NotificationThread.fromJson)
              .toList()
        : <NotificationThread>[];

    // Backward-compat: derive threads from the flat list when absent.
    if (threads.isEmpty && messages.isNotEmpty) {
      threads = _threadsFrom(messages);
    }

    return AppNotifications(
      app: json['app']?.toString() ?? 'Unknown',
      package: json['package']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? messages.length,
      threads: threads,
      messages: messages,
    );
  }

  /// Groups a flat notification list into conversation threads (newest first),
  /// keyed by group name for group chats, else the sender.
  static List<NotificationThread> _threadsFrom(List<SocialMessage> messages) {
    final byConversation = <String, List<SocialMessage>>{};
    for (final m in messages) {
      final key = m.isGroup && m.groupName.isNotEmpty
          ? m.groupName
          : (m.sender.isNotEmpty ? m.sender : 'Unknown');
      byConversation.putIfAbsent(key, () => []).add(m);
    }

    final threads = byConversation.entries.map((e) {
      final msgs = [...e.value]
        ..sort((a, b) => _cmpDesc(a.timestamp, b.timestamp));
      final latest = msgs.first;
      return NotificationThread(
        conversation: e.key,
        count: msgs.length,
        lastTime: latest.timestamp,
        lastPreview: latest.body,
        messages: msgs,
      );
    }).toList()..sort((a, b) => _cmpDesc(a.lastTime, b.lastTime));
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

/// A flattened notification tied to its owning app — used to render a single
/// time-ordered feed (the "All" tab) and per-app filters.
class SocialNotificationItem {
  final String app;
  final String package;
  final SocialMessage message;

  const SocialNotificationItem({
    required this.app,
    required this.package,
    required this.message,
  });
}

/// A conversation thread tied to its owning app — used to render the SMS-style
/// inbox across apps (the "All" tab) and per-app filters.
class NotificationThreadItem {
  final String app;
  final String package;
  final NotificationThread thread;

  const NotificationThreadItem({
    required this.app,
    required this.package,
    required this.thread,
  });
}

/// Full response wrapper for /api/social/notifications.
class SocialNotificationsResponse {
  final int total;
  final int totalMessages;

  /// Oldest timestamp included by the server's day/hour window, if provided.
  final DateTime? windowSince;
  final List<AppNotifications> apps;

  const SocialNotificationsResponse({
    required this.total,
    required this.totalMessages,
    required this.windowSince,
    required this.apps,
  });

  factory SocialNotificationsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['apps'];
    final apps = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(AppNotifications.fromJson)
              .toList()
        : <AppNotifications>[];

    return SocialNotificationsResponse(
      total: (json['total'] as num?)?.toInt() ?? apps.length,
      totalMessages: (json['totalMessages'] as num?)?.toInt() ?? 0,
      windowSince: DateTime.tryParse(json['windowSince']?.toString() ?? ''),
      apps: apps,
    );
  }
}
