import 'package:vigil_parents_app/features/calls/models/calls_model.dart';

abstract class CallLogRepository {
  Future<List<CallLogModel>> getCallLogs({
    required String childId,
    required DateTime date,
    CallType? filterType,
    String? searchQuery,
  });

  Future<List<ChildModel>> getChildren();

  Future<CallSummaryModel> getCallSummary({
    required String childId,
    required DateTime date,
  });
}

class CallLogRepositoryImpl implements CallLogRepository {
  // Static data — replace with API calls when backend is ready
  static final List<ChildModel> _children = [
    const ChildModel(id: 'child_1', name: 'Aryan Sharma'),
  ];

  static final List<CallLogModel> _staticCallLogs = [
    // Today — 21 May 2025
    CallLogModel(
      id: 'c1',
      contactName: 'Ananya Singh',
      phoneNumber: '+91 91234 56789',
      callType: CallType.incoming,
      callTime: DateTime(2025, 5, 21, 10, 45),
      duration: const Duration(minutes: 4, seconds: 32),
      avatarColor: '#F4A460',
    ),
    CallLogModel(
      id: 'c2',
      contactName: 'Rohit Verma',
      phoneNumber: '+91 98765 43210',
      callType: CallType.outgoing,
      callTime: DateTime(2025, 5, 21, 10, 20),
      duration: const Duration(minutes: 2, seconds: 18),
      avatarInitials: 'RV',
      avatarColor: '#7B68EE',
    ),
    CallLogModel(
      id: 'c3',
      contactName: 'Mom',
      phoneNumber: '+91 99887 76655',
      callType: CallType.incoming,
      callTime: DateTime(2025, 5, 21, 9, 15),
      duration: const Duration(minutes: 6, seconds: 45),
      avatarInitials: 'M',
      avatarColor: '#FF69B4',
    ),
    CallLogModel(
      id: 'c4',
      contactName: 'Papa',
      phoneNumber: '+91 99876 54321',
      callType: CallType.outgoing,
      callTime: DateTime(2025, 5, 21, 8, 30),
      duration: const Duration(minutes: 3, seconds: 11),
      avatarInitials: 'P',
      avatarColor: '#FFA500',
    ),
    CallLogModel(
      id: 'c5',
      contactName: 'Unknown Number',
      phoneNumber: '+91 70000 12345',
      callType: CallType.missed,
      callTime: DateTime(2025, 5, 21, 8, 5),
      duration: null,
      isUnknownContact: true,
      avatarColor: '#9E9E9E',
    ),
    // Yesterday — 20 May 2025
    CallLogModel(
      id: 'c6',
      contactName: 'Sneha Kapoor',
      phoneNumber: '+91 91234 00011',
      callType: CallType.incoming,
      callTime: DateTime(2025, 5, 20, 21, 40),
      duration: const Duration(minutes: 5, seconds: 21),
      avatarInitials: 'S',
      avatarColor: '#4CAF50',
    ),
    CallLogModel(
      id: 'c7',
      contactName: 'Aarav Arora',
      phoneNumber: '+91 98888 76543',
      callType: CallType.missed,
      callTime: DateTime(2025, 5, 20, 20, 15),
      duration: null,
      avatarInitials: 'AA',
      avatarColor: '#26C6DA',
    ),
    CallLogModel(
      id: 'c8',
      contactName: 'Tuition Teacher',
      phoneNumber: '+91 90000 11122',
      callType: CallType.outgoing,
      callTime: DateTime(2025, 5, 20, 19, 30),
      duration: const Duration(minutes: 1, seconds: 45),
      avatarInitials: 'T',
      avatarColor: '#FF7043',
    ),
    // More calls for summary count (not shown in list but counted)
    CallLogModel(
      id: 'c9',
      contactName: 'Class Friend',
      phoneNumber: '+91 91111 22222',
      callType: CallType.incoming,
      callTime: DateTime(2025, 5, 21, 7, 0),
      duration: const Duration(minutes: 1, seconds: 10),
      avatarInitials: 'CF',
      avatarColor: '#AB47BC',
    ),
    CallLogModel(
      id: 'c10',
      contactName: 'Grandma',
      phoneNumber: '+91 91111 33333',
      callType: CallType.incoming,
      callTime: DateTime(2025, 5, 21, 6, 30),
      duration: const Duration(minutes: 2, seconds: 5),
      avatarInitials: 'G',
      avatarColor: '#EC407A',
    ),
  ];

  @override
  Future<List<ChildModel>> getChildren() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _children;
  }

  @override
  Future<List<CallLogModel>> getCallLogs({
    required String childId,
    required DateTime date,
    CallType? filterType,
    String? searchQuery,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    var logs = List<CallLogModel>.from(_staticCallLogs);

    if (filterType != null) {
      logs = logs.where((l) => l.callType == filterType).toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      logs = logs
          .where(
            (l) =>
                l.contactName.toLowerCase().contains(q) ||
                l.phoneNumber.contains(q),
          )
          .toList();
    }

    return logs;
  }

  @override
  Future<CallSummaryModel> getCallSummary({
    required String childId,
    required DateTime date,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const CallSummaryModel(
      totalCalls: 22,
      incomingCalls: 12,
      outgoingCalls: 8,
      missedCalls: 2,
    );
  }
}
