// Maps the GET /api/children/{childId}/live-status response.
//
// Example payload:
// {
//   "status": 200,
//   "childId": "...",
//   "name": "Ali",
//   "deviceName": "",
//   "isOnline": false,
//   "lastSeen": null,
//   "sessionActive": false,
//   "liveStatusUpdatedAt": null,
//   "batteryInfo": { "level": null, "state": null, "isInBatterySaveMode": false,
//                    "temperature": null, "voltage": null },
//   "connectivity": { "connectionType": [], "isConnected": false, "hasWifi": false,
//                     "hasMobile": false, "hasEthernet": false, "hasBluetooth": false,
//                     "hasVpn": false,
//                     "wifiInfo": { "ssid": null, "bssid": null, "ipAddress": null,
//                                   "linkSpeed": null } }
// }

class LiveStatusResponse {
  final String childId;
  final String name;
  final String deviceName;
  final bool isOnline;
  final String? lastSeen;
  final bool sessionActive;
  final String? liveStatusUpdatedAt;
  final BatteryInfo battery;
  final ConnectivityInfo connectivity;

  const LiveStatusResponse({
    required this.childId,
    required this.name,
    required this.deviceName,
    required this.isOnline,
    required this.lastSeen,
    required this.sessionActive,
    required this.liveStatusUpdatedAt,
    required this.battery,
    required this.connectivity,
  });

  factory LiveStatusResponse.fromJson(Map<String, dynamic> json) {
    return LiveStatusResponse(
      childId: (json['childId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen']?.toString(),
      sessionActive: json['sessionActive'] == true,
      liveStatusUpdatedAt: json['liveStatusUpdatedAt']?.toString(),
      battery: BatteryInfo.fromJson(
        json['batteryInfo'] as Map<String, dynamic>? ?? const {},
      ),
      connectivity: ConnectivityInfo.fromJson(
        json['connectivity'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class BatteryInfo {
  final int? level;
  final String? state;
  final bool isInBatterySaveMode;
  final double? temperature;
  final double? voltage;

  const BatteryInfo({
    required this.level,
    required this.state,
    required this.isInBatterySaveMode,
    required this.temperature,
    required this.voltage,
  });

  /// True when the device reports it is charging.
  bool get isCharging => (state ?? '').toLowerCase() == 'charging';

  factory BatteryInfo.fromJson(Map<String, dynamic> json) {
    return BatteryInfo(
      level: json['level'] is num ? (json['level'] as num).toInt() : null,
      state: json['state']?.toString(),
      isInBatterySaveMode: json['isInBatterySaveMode'] == true,
      temperature: json['temperature'] is num
          ? (json['temperature'] as num).toDouble()
          : null,
      voltage: json['voltage'] is num
          ? (json['voltage'] as num).toDouble()
          : null,
    );
  }
}

class ConnectivityInfo {
  final List<String> connectionType;
  final bool isConnected;
  final bool hasWifi;
  final bool hasMobile;
  final bool hasEthernet;
  final bool hasBluetooth;
  final bool hasVpn;
  final WifiInfo wifi;

  const ConnectivityInfo({
    required this.connectionType,
    required this.isConnected,
    required this.hasWifi,
    required this.hasMobile,
    required this.hasEthernet,
    required this.hasBluetooth,
    required this.hasVpn,
    required this.wifi,
  });

  /// A short human label for the active connection — e.g. "Wi-Fi", "Mobile".
  String get label {
    if (!isConnected) return 'No connection';
    if (hasWifi) return 'Wi-Fi';
    if (hasMobile) return 'Mobile';
    if (hasEthernet) return 'Ethernet';
    if (hasBluetooth) return 'Bluetooth';
    return 'Connected';
  }

  factory ConnectivityInfo.fromJson(Map<String, dynamic> json) {
    final types = json['connectionType'];
    return ConnectivityInfo(
      connectionType: types is List
          ? types.map((e) => e.toString()).toList()
          : const [],
      isConnected: json['isConnected'] == true,
      hasWifi: json['hasWifi'] == true,
      hasMobile: json['hasMobile'] == true,
      hasEthernet: json['hasEthernet'] == true,
      hasBluetooth: json['hasBluetooth'] == true,
      hasVpn: json['hasVpn'] == true,
      wifi: WifiInfo.fromJson(
        json['wifiInfo'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class WifiInfo {
  final String? ssid;
  final String? bssid;
  final String? ipAddress;
  final int? linkSpeed;

  const WifiInfo({
    required this.ssid,
    required this.bssid,
    required this.ipAddress,
    required this.linkSpeed,
  });

  factory WifiInfo.fromJson(Map<String, dynamic> json) {
    return WifiInfo(
      ssid: json['ssid']?.toString(),
      bssid: json['bssid']?.toString(),
      ipAddress: json['ipAddress']?.toString(),
      linkSpeed: json['linkSpeed'] is num
          ? (json['linkSpeed'] as num).toInt()
          : null,
    );
  }
}
