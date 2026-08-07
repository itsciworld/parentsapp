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
  final bool appUsage;
  final bool networkWifi;
  final bool readNotification;
  final bool readChat;

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
    required this.appUsage,
    required this.networkWifi,
    required this.readNotification,
    required this.readChat,
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
      appUsage: data['app_usage'] == true,
      networkWifi: data['network_wifi'] == true,
      readNotification: data['read_notification'] == true,
      readChat: data['read_chat'] == true,
    );
  }

  /// Whether the child's device is sharing the data behind [feature].
  ///
  /// A screen with a `false` here has nothing to show and never will until the
  /// child turns the permission back on — so it says that instead of rendering
  /// an "empty" list that looks like a bug.
  bool allows(ChildFeature feature) {
    switch (feature) {
      case ChildFeature.messages:
        return messages;
      case ChildFeature.calls:
        return callLog;
      case ChildFeature.contacts:
        return contacts;
      case ChildFeature.calendar:
        return calendar;
      case ChildFeature.location:
        return location;
      case ChildFeature.appUsage:
        return appUsage;
      case ChildFeature.notifications:
        return readNotification;
      case ChildFeature.chats:
        return readChat;
    }
  }

  /// All permissions in display order with labels + icons.
  List<PermissionItem> get _all => [
    // Data access
    PermissionItem('Messages', Icons.sms_outlined, messages),
    PermissionItem('Contacts', Icons.contacts_outlined, contacts),
    PermissionItem('Call Logs', Icons.call_outlined, callLog),
    PermissionItem('Calendar', Icons.calendar_today_outlined, calendar),
    PermissionItem('Location', Icons.location_on_outlined, location),
    PermissionItem('App Usage', Icons.apps_rounded, appUsage),
    PermissionItem('Network & Wi-Fi', Icons.wifi_rounded, networkWifi),
    PermissionItem(
      'Read Notifications',
      Icons.notifications_outlined,
      readNotification,
    ),
    PermissionItem('Read Chats', Icons.chat_bubble_outline_rounded, readChat),
    // Notification access
    // PermissionItem('SOS Alerts', Icons.sos_rounded, sosNotification),
    // PermissionItem('Secure Folder', Icons.folder_outlined, secureFolder),
    // PermissionItem('Workspace', Icons.work_outline_rounded, workspace),
    PermissionItem(
      'Update Notifications',
      Icons.notifications_active_outlined,
      notifSystemUpdateService,
    ),
    // Device / security
    // PermissionItem(
    //   'Security Scan',
    //   Icons.security_rounded,
    //   scanDeviceForSecurity,
    // ),
    // PermissionItem(
    //   'Harmful Detection',
    //   Icons.shield_outlined,
    //   improveHarmfulDetection,
    // ),
    // PermissionItem(
    //   'System Updates',
    //   Icons.system_update_rounded,
    //   systemUpdateService,
    // ),
    PermissionItem(
      'Usage Tracking',
      Icons.bar_chart_rounded,
      allowUsageTracking,
    ),
    // PermissionItem(
    //   'Administrator',
    //   Icons.admin_panel_settings_outlined,
    //   administratorAccess,
    // ),
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

/// A monitoring screen, paired with the child permission that feeds it.
///
/// [what] completes the sentence "… so `what` can't be shown here".
enum ChildFeature {
  messages(label: 'Messages', icon: Icons.sms_outlined, what: 'messages'),
  calls(label: 'Call Logs', icon: Icons.call_outlined, what: 'call history'),
  contacts(label: 'Contacts', icon: Icons.contacts_outlined, what: 'contacts'),
  calendar(
    label: 'Calendar',
    icon: Icons.calendar_today_outlined,
    what: 'calendar events',
  ),
  location(
    label: 'Location',
    icon: Icons.location_on_outlined,
    what: 'location history',
  ),
  appUsage(
    label: 'App Usage',
    icon: Icons.apps_rounded,
    what: 'app usage stats',
  ),
  notifications(
    label: 'Read Notifications',
    icon: Icons.notifications_outlined,
    what: 'notifications',
  ),
  chats(
    label: 'Read Chats',
    icon: Icons.chat_bubble_outline_rounded,
    what: 'chat messages',
  );

  const ChildFeature({
    required this.label,
    required this.icon,
    required this.what,
  });

  /// The permission's name as the child sees it in the Vigil Child app.
  final String label;
  final IconData icon;
  final String what;
}

/// A single permission for the UI.
class PermissionItem {
  final String label;
  final IconData icon;
  final bool granted;

  const PermissionItem(this.label, this.icon, this.granted);
}
