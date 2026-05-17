// ══════════════════════════════════════════════════════════════
//  MODEL
// ══════════════════════════════════════════════════════════════

import 'dart:ui';

enum ContactStatus { saved, unknown, blocked }

enum ContactCategory { all, family, friends, education, unknown }

class ContactModel {
  final int id;
  final String name;
  final String phone;
  final ContactCategory category;
  final ContactStatus status;
  final String lastSeen;
  final int calls;
  final String initials;
  final Color color;
  final List<String> tags;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.status,
    required this.lastSeen,
    required this.calls,
    required this.initials,
    required this.color,
    required this.tags,
  });
}

class ContactsStats {
  final int total;
  final int saved;
  final int unknown;
  final int blocked;

  const ContactsStats({
    required this.total,
    required this.saved,
    required this.unknown,
    required this.blocked,
  });
}
