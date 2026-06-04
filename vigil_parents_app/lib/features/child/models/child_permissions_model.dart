import 'package:flutter/material.dart';

/// Maps the GET /api/children/{childId}/permissions response. The full payload
/// is preserved on the backend; for now the UI only surfaces `dataAccess`.
class ChildPermissions {
  final bool messages;
  final bool contacts;
  final bool callLog;
  final bool calendar;
  final bool location;

  const ChildPermissions({
    required this.messages,
    required this.contacts,
    required this.callLog,
    required this.calendar,
    required this.location,
  });

  factory ChildPermissions.fromJson(Map<String, dynamic> json) {
    // The flags arrive either under a `dataAccess` object or at the top level.
    final data = (json['dataAccess'] is Map)
        ? Map<String, dynamic>.from(json['dataAccess'] as Map)
        : json;
    return ChildPermissions(
      messages: data['messages'] == true,
      contacts: data['contacts'] == true,
      callLog: data['call_log'] == true,
      calendar: data['calendar'] == true,
      location: data['location'] == true,
    );
  }

  /// Flattened list for rendering, in display order.
  List<PermissionItem> get items => [
    PermissionItem(
      label: 'Messages',
      icon: Icons.sms_outlined,
      granted: messages,
    ),
    PermissionItem(
      label: 'Contacts',
      icon: Icons.contacts_outlined,
      granted: contacts,
    ),
    PermissionItem(
      label: 'Call Logs',
      icon: Icons.call_outlined,
      granted: callLog,
    ),
    PermissionItem(
      label: 'Calendar',
      icon: Icons.calendar_today_outlined,
      granted: calendar,
    ),
    PermissionItem(
      label: 'Location',
      icon: Icons.location_on_outlined,
      granted: location,
    ),
  ];
}

/// A single permission row for the UI.
class PermissionItem {
  final String label;
  final IconData icon;
  final bool granted;

  const PermissionItem({
    required this.label,
    required this.icon,
    required this.granted,
  });
}
