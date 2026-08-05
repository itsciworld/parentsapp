import 'package:vigil_parents_app/core/utils/api_date.dart';

// Maps the /api/logs/calllogs response:
// { status, total, page, limit, pages, callLogs: [ {name, number, callType, duration, timestamp} ] }

enum CallType { incoming, outgoing, missed }

class CallLogModel {
  final String id;
  final String name;
  final String number;
  final CallType callType;
  final int durationSeconds;
  final DateTime? timestamp;
  final String childId;
  final String parentId;

  const CallLogModel({
    required this.id,
    required this.name,
    required this.number,
    required this.callType,
    required this.durationSeconds,
    required this.timestamp,
    required this.childId,
    required this.parentId,
  });

  bool get hasName {
    final n = name.trim();
    return n.isNotEmpty && n.toLowerCase() != 'unknown';
  }

  /// Display label — name when known, otherwise the number.
  String get label => hasName ? name.trim() : (number.isEmpty ? 'Unknown' : number);

  bool get isUnknown => !hasName;

  /// e.g. "4m 32s" / "45s" / "—" for missed.
  String get formattedDuration {
    if (callType == CallType.missed || durationSeconds <= 0) return '—';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  String get formattedTime {
    final dt = timestamp;
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get initials {
    if (hasName) {
      final parts = name
          .trim()
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isEmpty) return '#';
      if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
      return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
          .toUpperCase();
    }
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return '#';
  }

  factory CallLogModel.fromJson(Map<String, dynamic> json) {
    return CallLogModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      callType: _parseType((json['callType'] ?? '').toString()),
      durationSeconds: _toInt(json['duration']),
      timestamp: _toDate(json['timestamp']),
      childId: (json['child_id'] ?? '').toString(),
      parentId: (json['parent_id'] ?? '').toString(),
    );
  }

  static CallType _parseType(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('miss') || t.contains('reject')) return CallType.missed;
    if (t.contains('out')) return CallType.outgoing;
    return CallType.incoming;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _toDate(dynamic v) => parseApiDate(v);
}

class CallLogsResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<CallLogModel> callLogs;

  const CallLogsResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.callLogs,
  });

  factory CallLogsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['callLogs'];
    final logs = raw is List
        ? raw
              .whereType<Map>()
              .map((c) => CallLogModel.fromJson(Map<String, dynamic>.from(c)))
              .toList()
        : <CallLogModel>[];

    return CallLogsResponse(
      status: _toInt(json['status'], fallback: 200),
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      limit: _toInt(json['limit'], fallback: 20),
      pages: _toInt(json['pages']),
      callLogs: logs,
    );
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

class CallSummaryModel {
  final int totalCalls;
  final int incomingCalls;
  final int outgoingCalls;
  final int missedCalls;

  const CallSummaryModel({
    required this.totalCalls,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.missedCalls,
  });

  factory CallSummaryModel.fromLogs(List<CallLogModel> logs) {
    return CallSummaryModel(
      totalCalls: logs.length,
      incomingCalls: logs.where((l) => l.callType == CallType.incoming).length,
      outgoingCalls: logs.where((l) => l.callType == CallType.outgoing).length,
      missedCalls: logs.where((l) => l.callType == CallType.missed).length,
    );
  }
}
