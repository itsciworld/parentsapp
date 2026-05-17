// ══════════════════════════════════════════════════════════════
//  REPOSITORY
// ══════════════════════════════════════════════════════════════

import 'dart:ui';

import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';

class ContactsRepository {
  static final List<ContactModel> _data = [
    ContactModel(
      id: 1,
      name: 'Ananya Singh',
      phone: '+91 91234 56789',
      category: ContactCategory.friends,
      status: ContactStatus.saved,
      lastSeen: '10:45 AM',
      calls: 8,
      initials: 'AS',
      color: const Color(0xFFFF6B6B),
      tags: ['School', 'Friend'],
    ),
    ContactModel(
      id: 2,
      name: 'Rohit Verma',
      phone: '+91 98765 43210',
      category: ContactCategory.friends,
      status: ContactStatus.saved,
      lastSeen: '10:20 AM',
      calls: 5,
      initials: 'RV',
      color: const Color(0xFF845EF7),
      tags: ['Cricket'],
    ),
    ContactModel(
      id: 3,
      name: 'Mom',
      phone: '+91 99887 76655',
      category: ContactCategory.family,
      status: ContactStatus.saved,
      lastSeen: '09:15 AM',
      calls: 14,
      initials: 'M',
      color: const Color(0xFF51CF66),
      tags: ['Family', 'Trusted'],
    ),
    ContactModel(
      id: 4,
      name: 'Papa',
      phone: '+91 99876 54321',
      category: ContactCategory.family,
      status: ContactStatus.saved,
      lastSeen: '08:30 AM',
      calls: 11,
      initials: 'P',
      color: const Color(0xFFFF922B),
      tags: ['Family', 'Trusted'],
    ),
    ContactModel(
      id: 5,
      name: '+91 70000 12345',
      phone: '+91 70000 12345',
      category: ContactCategory.unknown,
      status: ContactStatus.unknown,
      lastSeen: '08:05 AM',
      calls: 1,
      initials: '?',
      color: const Color(0xFF868E96),
      tags: ['Unknown'],
    ),
    ContactModel(
      id: 6,
      name: 'Sneha Kapoor',
      phone: '+91 91234 00011',
      category: ContactCategory.friends,
      status: ContactStatus.saved,
      lastSeen: 'Yesterday',
      calls: 3,
      initials: 'SK',
      color: const Color(0xFF20C997),
      tags: ['School'],
    ),
    ContactModel(
      id: 7,
      name: 'Aarav Arora',
      phone: '+91 98888 76543',
      category: ContactCategory.friends,
      status: ContactStatus.saved,
      lastSeen: 'Yesterday',
      calls: 2,
      initials: 'AA',
      color: const Color(0xFF339AF0),
      tags: ['Classmate'],
    ),
    ContactModel(
      id: 8,
      name: 'Tuition Teacher',
      phone: '+91 90000 11122',
      category: ContactCategory.education,
      status: ContactStatus.saved,
      lastSeen: 'Yesterday',
      calls: 6,
      initials: 'T',
      color: const Color(0xFFF59F00),
      tags: ['Education', 'Trusted'],
    ),
    ContactModel(
      id: 9,
      name: '+91 88888 00001',
      phone: '+91 88888 00001',
      category: ContactCategory.unknown,
      status: ContactStatus.blocked,
      lastSeen: '2 days ago',
      calls: 3,
      initials: '!',
      color: const Color(0xFFFA5252),
      tags: ['Blocked'],
    ),
    ContactModel(
      id: 10,
      name: 'Priya Nair',
      phone: '+91 91111 22233',
      category: ContactCategory.friends,
      status: ContactStatus.saved,
      lastSeen: '3 days ago',
      calls: 4,
      initials: 'PN',
      color: const Color(0xFFCC5DE8),
      tags: ['Dance Class'],
    ),
  ];

  List<ContactModel> getAll() => List.unmodifiable(_data);

  List<ContactModel> filterByCategory(ContactCategory cat) {
    if (cat == ContactCategory.all) return getAll();
    return _data.where((c) => c.category == cat).toList();
  }

  List<ContactModel> filterByStatus(ContactStatus? status) {
    if (status == null) return getAll();
    return _data.where((c) => c.status == status).toList();
  }

  List<ContactModel> search(String query) {
    if (query.isEmpty) return getAll();
    final q = query.toLowerCase();
    return _data
        .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
  }

  List<ContactModel> filter({
    ContactCategory category = ContactCategory.all,
    ContactStatus? status,
    String query = '',
  }) {
    var list = getAll();
    if (category != ContactCategory.all) {
      list = list.where((c) => c.category == category).toList();
    }
    if (status != null) {
      list = list.where((c) => c.status == status).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list
          .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
    }
    return list;
  }

  ContactModel? getById(int id) {
    try {
      return _data.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  ContactsStats getStats() {
    return ContactsStats(
      total: _data.length,
      saved: _data.where((c) => c.status == ContactStatus.saved).length,
      unknown: _data.where((c) => c.status == ContactStatus.unknown).length,
      blocked: _data.where((c) => c.status == ContactStatus.blocked).length,
    );
  }
}
