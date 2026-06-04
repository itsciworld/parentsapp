// Maps the /api/contacts/get_contacts response:
// { status, total, page, limit, pages, contacts: [ { _id, displayName, phones[] } ] }

class ContactModel {
  final String id;
  final String displayName;
  final List<String> phones;
  final String childId;
  final String childName;
  final String parentId;
  final String parentName;

  const ContactModel({
    required this.id,
    required this.displayName,
    required this.phones,
    required this.childId,
    required this.childName,
    required this.parentId,
    required this.parentName,
  });

  String get primaryPhone => phones.isEmpty ? '' : phones.first;

  bool get hasName => displayName.trim().isNotEmpty;

  /// Display label — falls back to the first number when there's no name.
  String get label => hasName ? displayName.trim() : primaryPhone;

  String get initials {
    if (hasName) {
      final parts = displayName
          .trim()
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isEmpty) return '#';
      if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
      return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
          .toUpperCase();
    }
    final digits = primaryPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return '#';
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    final rawPhones = json['phones'];
    final phones = rawPhones is List
        ? rawPhones
              .map((p) => p.toString())
              .where((p) => p.trim().isNotEmpty)
              .toList()
        : <String>[];

    return ContactModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['display_name'] ?? '')
          .toString(),
      phones: phones,
      childId: (json['child_id'] ?? '').toString(),
      childName: (json['child_name'] ?? '').toString(),
      parentId: (json['parent_id'] ?? '').toString(),
      parentName: (json['parent_name'] ?? '').toString(),
    );
  }
}

class ContactsResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<ContactModel> contacts;

  const ContactsResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.contacts,
  });

  factory ContactsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['contacts'];
    final contacts = raw is List
        ? raw
              .whereType<Map>()
              .map((c) => ContactModel.fromJson(Map<String, dynamic>.from(c)))
              .toList()
        : <ContactModel>[];

    return ContactsResponse(
      status: _toInt(json['status'], fallback: 200),
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      limit: _toInt(json['limit'], fallback: 20),
      pages: _toInt(json['pages']),
      contacts: contacts,
    );
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
