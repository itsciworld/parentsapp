// Models for the grouped SMS endpoint:
// /api/sms/get_sms?child_id=..&parent_id=..&grouped=true
//
// The response groups messages into threads (one per address), each carrying
// its full message list and a count.

class SmsMessage {
  final String id;
  final int smsId;
  final int threadId;
  final String address;
  final String body;
  final DateTime? date;
  final String kind; // inbox / sent
  final String state; // received / sent
  final String type; // inbox / sent

  const SmsMessage({
    required this.id,
    required this.smsId,
    required this.threadId,
    required this.address,
    required this.body,
    required this.date,
    required this.kind,
    required this.state,
    required this.type,
  });

  /// Outgoing message — shown as a right-aligned bubble.
  bool get isSent {
    final t = type.toLowerCase();
    final k = kind.toLowerCase();
    return t == 'sent' || t == 'outbox' || t == 'out' || k == 'sent';
  }

  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    return SmsMessage(
      id: (json['_id'] ?? '').toString(),
      smsId: _toInt(json['sms_id']),
      threadId: _toInt(json['thread_id']),
      address: (json['address'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      date: _toDate(json['date'] ?? json['date_sent'] ?? json['createdAt']),
      kind: (json['kind'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class SmsThread {
  final int threadId;
  final String address;
  final List<SmsMessage> messages; // sorted oldest → newest
  final int count;
  final DateTime? lastMessageAt;

  const SmsThread({
    required this.threadId,
    required this.address,
    required this.messages,
    required this.count,
    required this.lastMessageAt,
  });

  /// Newest message in the thread (used for the list preview).
  SmsMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  String get preview => lastMessage?.body ?? '';

  factory SmsThread.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = raw is List
        ? raw
              .whereType<Map>()
              .map((m) => SmsMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList()
        : <SmsMessage>[];

    // Oldest → newest so the conversation reads top to bottom and
    // [lastMessage] is the most recent.
    messages.sort((a, b) {
      final ad = a.date, bd = b.date;
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1;
      if (bd == null) return 1;
      return ad.compareTo(bd);
    });

    return SmsThread(
      threadId: _toInt(json['thread_id']),
      address: (json['address'] ?? '').toString(),
      messages: messages,
      count: _toInt(json['count'], fallback: messages.length),
      lastMessageAt: _toDate(json['last_message_at']) ??
          (messages.isEmpty ? null : messages.last.date),
    );
  }
}

class SmsThreadsResponse {
  final int status;
  final String childId;
  final String parentId;
  final int totalThreads;
  final List<SmsThread> threads;

  const SmsThreadsResponse({
    required this.status,
    required this.childId,
    required this.parentId,
    required this.totalThreads,
    required this.threads,
  });

  factory SmsThreadsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['threads'];
    final threads = raw is List
        ? raw
              .whereType<Map>()
              .map((t) => SmsThread.fromJson(Map<String, dynamic>.from(t)))
              .toList()
        : <SmsThread>[];

    // Most recently active thread first.
    threads.sort((a, b) {
      final ad = a.lastMessageAt, bd = b.lastMessageAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return SmsThreadsResponse(
      status: _toInt(json['status'], fallback: 200),
      childId: (json['child_id'] ?? '').toString(),
      parentId: (json['parent_id'] ?? '').toString(),
      totalThreads: _toInt(json['total_threads'], fallback: threads.length),
      threads: threads,
    );
  }
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}
