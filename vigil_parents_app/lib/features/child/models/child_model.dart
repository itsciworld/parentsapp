// Maps /api/children response. Full fields preserved; UI uses a subset.

class ChildModel {
  final String id;
  final String name;
  final int age;
  final String parentId;
  final String status;
  final String deviceName;
  final bool scanDeviceForSecurity;
  final bool improveHarmfulDetection;
  final bool systemUpdateService;
  final bool allowUsageTracking;
  final bool administratorAccess;
  final bool batteryOptimizationAllowed;
  final int? batteryLevel;
  final bool isOnline;
  final String? lastSeen;
  final int version;

  final ChildNotificationAccess notificationAccess;
  final ChildDataAccess dataAccess;

  const ChildModel({
    required this.id,
    required this.name,
    required this.age,
    required this.parentId,
    required this.status,
    required this.deviceName,
    required this.scanDeviceForSecurity,
    required this.improveHarmfulDetection,
    required this.systemUpdateService,
    required this.allowUsageTracking,
    required this.administratorAccess,
    required this.batteryOptimizationAllowed,
    required this.batteryLevel,
    required this.isOnline,
    required this.lastSeen,
    required this.version,
    required this.notificationAccess,
    required this.dataAccess,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      age: _toInt(json['age']),
      parentId: (json['parentId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      scanDeviceForSecurity: json['scanDeviceForSecurity'] == true,
      improveHarmfulDetection: json['improveHarmfulDetection'] == true,
      systemUpdateService: json['systemUpdateService'] == true,
      allowUsageTracking: json['allowUsageTracking'] == true,
      administratorAccess: json['administratorAccess'] == true,
      batteryOptimizationAllowed: json['batteryOptimizationAllowed'] == true,
      batteryLevel: json['batteryLevel'] is num
          ? (json['batteryLevel'] as num).toInt()
          : null,
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen']?.toString(),
      version: _toInt(json['__v']),
      notificationAccess: ChildNotificationAccess.fromJson(
        json['notificationAccess'] as Map<String, dynamic>? ?? const {},
      ),
      dataAccess: ChildDataAccess.fromJson(
        json['dataAccess'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class ChildNotificationAccess {
  final bool systemUpdateService;
  final bool secureFolder;
  final bool sosNotification;
  final bool workspace;

  const ChildNotificationAccess({
    required this.systemUpdateService,
    required this.secureFolder,
    required this.sosNotification,
    required this.workspace,
  });

  factory ChildNotificationAccess.fromJson(Map<String, dynamic> json) {
    return ChildNotificationAccess(
      systemUpdateService: json['systemUpdateService'] == true,
      secureFolder: json['secureFolder'] == true,
      sosNotification: json['sosNotification'] == true,
      workspace: json['workspace'] == true,
    );
  }
}

class ChildDataAccess {
  final bool messages;
  final bool contacts;
  final bool callLog;
  final bool calendar;
  final bool location;

  const ChildDataAccess({
    required this.messages,
    required this.contacts,
    required this.callLog,
    required this.calendar,
    required this.location,
  });

  factory ChildDataAccess.fromJson(Map<String, dynamic> json) {
    return ChildDataAccess(
      messages: json['messages'] == true,
      contacts: json['contacts'] == true,
      callLog: json['call_log'] == true,
      calendar: json['calendar'] == true,
      location: json['location'] == true,
    );
  }
}
