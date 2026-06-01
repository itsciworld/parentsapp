// Maps the /api/auth/me response. Full fields preserved; UI uses a subset.

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String alternateMobile;
  final String country;
  final String city;
  final String address;
  final String status;
  final bool isVerified;
  final String registeredVia;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;

  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.alternateMobile,
    required this.country,
    required this.city,
    required this.address,
    required this.status,
    required this.isVerified,
    required this.registeredVia,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLogin,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      alternateMobile: (json['alternate_mobile'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      isVerified: json['is_verified'] == true,
      registeredVia: (json['registered_via'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
      updatedAt: _toDate(json['updatedAt']),
      lastLogin: _toDate(json['last_login']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
