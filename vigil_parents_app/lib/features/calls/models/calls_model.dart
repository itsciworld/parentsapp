enum CallType { incoming, outgoing, missed }

class CallLogModel {
  final String id;
  final String contactName;
  final String phoneNumber;
  final CallType callType;
  final DateTime callTime;
  final Duration? duration; // null for missed calls
  final bool isUnknownContact;
  final String? avatarInitials;
  final String? avatarColor; // hex color string

  const CallLogModel({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.callType,
    required this.callTime,
    this.duration,
    this.isUnknownContact = false,
    this.avatarInitials,
    this.avatarColor,
  });

  String get formattedDuration {
    if (duration == null) return '–';
    final minutes = duration!.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration!.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedTime {
    final hour = callTime.hour % 12 == 0 ? 12 : callTime.hour % 12;
    final minute = callTime.minute.toString().padLeft(2, '0');
    final period = callTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class ChildModel {
  final String id;
  final String name;
  final String? avatarUrl;

  const ChildModel({required this.id, required this.name, this.avatarUrl});
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
}
