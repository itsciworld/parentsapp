// Maps the GET /api/children/{childId}/device-info response.

class DeviceInfoResponse {
  final String childId;
  final String name;
  final String deviceName;
  final DeviceDetails deviceInfo;
  final int? batteryLevel;
  final bool isOnline;
  final String? lastSeen;

  const DeviceInfoResponse({
    required this.childId,
    required this.name,
    required this.deviceName,
    required this.deviceInfo,
    required this.batteryLevel,
    required this.isOnline,
    required this.lastSeen,
  });

  factory DeviceInfoResponse.fromJson(Map<String, dynamic> json) {
    return DeviceInfoResponse(
      childId: (json['childId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      deviceInfo: DeviceDetails.fromJson(
        json['deviceInfo'] as Map<String, dynamic>? ?? const {},
      ),
      batteryLevel: json['batteryLevel'] is num
          ? (json['batteryLevel'] as num).toInt()
          : null,
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen']?.toString(),
    );
  }
}

class DeviceDetails {
  final String deviceId;
  final String model;
  final String manufacturer;
  final String osVersion;
  final String appVersion;
  final String sdkVersion;
  final String? lastUpdated;

  const DeviceDetails({
    required this.deviceId,
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.appVersion,
    required this.sdkVersion,
    required this.lastUpdated,
  });

  /// True when the backend has no real device info linked yet.
  bool get isEmpty => model.isEmpty && manufacturer.isEmpty && deviceId.isEmpty;

  factory DeviceDetails.fromJson(Map<String, dynamic> json) {
    return DeviceDetails(
      deviceId: (json['deviceId'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      manufacturer: (json['manufacturer'] ?? '').toString(),
      osVersion: (json['osVersion'] ?? '').toString(),
      appVersion: (json['appVersion'] ?? '').toString(),
      sdkVersion: (json['sdkVersion'] ?? '').toString(),
      lastUpdated: json['lastUpdated']?.toString(),
    );
  }
}
