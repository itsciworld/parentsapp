import 'package:flutter/material.dart';

/// Maps the `permissions` object from
/// GET /api/children/{childId}/permissions. The UI only surfaces the
/// permissions the child has *granted* (true).
class ChildPermissions {
  // Device / security
  final bool scanDeviceForSecurity;
  final bool improveHarmfulDetection;
  final bool systemUpdateService;
  final bool allowUsageTracking;
  final bool administratorAccess;
  final bool batteryOptimizationAllowed;

  // Notification access
  final bool notifSystemUpdateService;
  final bool secureFolder;
  final bool sosNotification;
  final bool workspace;

  // Data access
  final bool messages;
  final bool contacts;
  final bool callLog;
  final bool calendar;
  final bool location;

  const ChildPermissions({
    required this.scanDeviceForSecurity,
    required this.improveHarmfulDetection,
    required this.systemUpdateService,
    required this.allowUsageTracking,
    required this.administratorAccess,
    required this.batteryOptimizationAllowed,
    required this.notifSystemUpdateService,
    required this.secureFolder,
    required this.sosNotification,
    required this.workspace,
    required this.messages,
    required this.contacts,
    required this.callLog,
    required this.calendar,
    required this.location,
  });

  factory ChildPermissions.fromJson(Map<String, dynamic> json) {
    final notif = json['notificationAccess'] is Map
        ? Map<String, dynamic>.from(json['notificationAccess'] as Map)
        : const <String, dynamic>{};
    final data = json['dataAccess'] is Map
        ? Map<String, dynamic>.from(json['dataAccess'] as Map)
        : const <String, dynamic>{};

    return ChildPermissions(
      scanDeviceForSecurity: json['scanDeviceForSecurity'] == true,
      improveHarmfulDetection: json['improveHarmfulDetection'] == true,
      systemUpdateService: json['systemUpdateService'] == true,
      allowUsageTracking: json['allowUsageTracking'] == true,
      administratorAccess: json['administratorAccess'] == true,
      batteryOptimizationAllowed: json['batteryOptimizationAllowed'] == true,
      notifSystemUpdateService: notif['systemUpdateService'] == true,
      secureFolder: notif['secureFolder'] == true,
      sosNotification: notif['sosNotification'] == true,
      workspace: notif['workspace'] == true,
      messages: data['messages'] == true,
      contacts: data['contacts'] == true,
      callLog: data['call_log'] == true,
      calendar: data['calendar'] == true,
      location: data['location'] == true,
    );
  }

  /// All permissions in display order with labels + icons.
  List<PermissionItem> get _all => [
    // Data access
    PermissionItem('Messages', Icons.sms_outlined, messages),
    PermissionItem('Contacts', Icons.contacts_outlined, contacts),
    PermissionItem('Call Logs', Icons.call_outlined, callLog),
    PermissionItem('Calendar', Icons.calendar_today_outlined, calendar),
    PermissionItem('Location', Icons.location_on_outlined, location),
    // Notification access
    PermissionItem('SOS Alerts', Icons.sos_rounded, sosNotification),
    PermissionItem('Secure Folder', Icons.folder_outlined, secureFolder),
    PermissionItem('Workspace', Icons.work_outline_rounded, workspace),
    PermissionItem(
      'Update Notifications',
      Icons.notifications_active_outlined,
      notifSystemUpdateService,
    ),
    // Device / security
    PermissionItem(
      'Security Scan',
      Icons.security_rounded,
      scanDeviceForSecurity,
    ),
    PermissionItem(
      'Harmful Detection',
      Icons.shield_outlined,
      improveHarmfulDetection,
    ),
    PermissionItem(
      'System Updates',
      Icons.system_update_rounded,
      systemUpdateService,
    ),
    PermissionItem(
      'Usage Tracking',
      Icons.bar_chart_rounded,
      allowUsageTracking,
    ),
    PermissionItem(
      'Administrator',
      Icons.admin_panel_settings_outlined,
      administratorAccess,
    ),
    PermissionItem(
      'Battery Optimization',
      Icons.battery_charging_full_rounded,
      batteryOptimizationAllowed,
    ),
  ];

  /// All permissions, including granted and denied.
  List<PermissionItem> get items => _all;

  /// Only the permissions the child has granted (true).
  List<PermissionItem> get grantedItems =>
      _all.where((p) => p.granted).toList();
}

/// A single permission for the UI.
class PermissionItem {
  final String label;
  final IconData icon;
  final bool granted;

  const PermissionItem(this.label, this.icon, this.granted);
}
