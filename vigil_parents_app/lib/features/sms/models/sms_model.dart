/// Wraps the /api/sms/get_sms response:
/// { status, total, page, limit, pages, messages: [] }
class SmsResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<SmsModel> messages;

  const SmsResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.messages,
  });

  factory SmsResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['messages'];
    final messages = rawList is List
        ? rawList
              .whereType<Map>()
              .map((m) => SmsModel.fromJson(Map<String, dynamic>.from(m)))
              .toList()
        : <SmsModel>[];

    return SmsResponse(
      status: _toInt(json['status'], fallback: 200),
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      limit: _toInt(json['limit'], fallback: 20),
      pages: _toInt(json['pages']),
      messages: messages,
    );
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

class SmsModel {
  final String id;
  final String name;
  final String phone;
  final String message;
  final String time;
  final String image;
  final bool isSent;
  final bool isUnknown;
  final bool isMedia;
  final bool isVoice;

  /// Original JSON kept so new/unknown fields can be surfaced later
  /// without changing this model.
  final Map<String, dynamic> raw;

  SmsModel({
    required this.name,
    required this.phone,
    required this.message,
    required this.time,
    this.id = '',
    this.image = '',
    this.isSent = false,
    this.isUnknown = false,
    this.isMedia = false,
    this.isVoice = false,
    this.raw = const {},
  });

  /// Tolerant parser — the exact message schema isn't finalized yet, so we
  /// probe the common key names and fall back gracefully.
  factory SmsModel.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    final address = pick(['address', 'phone', 'number', 'from', 'sender']);
    final name = pick([
      'name',
      'contact_name',
      'contactName',
      'display_name',
      'displayName',
      'sender_name',
    ]);
    final body = pick(['body', 'message', 'text', 'content']);

    final typeRaw = pick(['type', 'direction', 'message_type']).toLowerCase();
    final isSent =
        typeRaw.contains('sent') ||
        typeRaw.contains('out') ||
        typeRaw == '2';

    return SmsModel(
      id: pick(['_id', 'id']),
      // Show the saved name when present, otherwise fall back to the number.
      name: name.isNotEmpty ? name : (address.isEmpty ? 'Unknown' : address),
      phone: address,
      message: body,
      time: _formatTime(pick(['date', 'timestamp', 'createdAt', 'date_sent'])),
      image: pick(['image', 'avatar', 'photo']),
      isSent: isSent,
      // Only flag "Unknown Contact" when the API explicitly says so — never
      // infer it from a missing name (the contact may well be saved).
      isUnknown: _isUnknownFlag(json),
      isMedia: pick(['media', 'attachment', 'image_url']).isNotEmpty,
      raw: json,
    );
  }

  static bool _isUnknownFlag(Map<String, dynamic> json) {
    // Positive "unknown" flags
    for (final k in ['isUnknown', 'is_unknown', 'unknown']) {
      if (json[k] == true) return true;
    }
    // Negative "is this a known/saved contact" flags
    for (final k in [
      'is_known',
      'isKnown',
      'is_contact',
      'isContact',
      'is_saved',
      'contact_saved',
      'saved',
    ]) {
      if (json[k] == false) return true;
    }
    return false;
  }

  static String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    DateTime? dt = DateTime.tryParse(raw);
    // Epoch millis / seconds fallback
    dt ??= () {
      final n = int.tryParse(raw);
      if (n == null) return null;
      final ms = raw.length > 11 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }();
    if (dt == null) return raw;

    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
