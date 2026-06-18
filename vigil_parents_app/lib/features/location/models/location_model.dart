/// A single recorded location point for a child.
///
/// The API returns `latitude`/`longitude` as strings, so they're parsed to
/// doubles here once for the UI/map to consume.
class ChildLocation {
  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final String childId;
  final String parentId;
  final DateTime? date;

  const ChildLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.childId,
    required this.parentId,
    this.date,
  });

  /// "22.7608, 75.8975" — a compact, fixed-precision coordinate label.
  String get coordinates =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "10:57 AM" — clock time in the device's local zone.
  String get timeLabel {
    final d = date?.toLocal();
    if (d == null) return '';
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// "17 Jun, 10:57 AM" — date + clock time, local zone.
  String get dateTimeLabel {
    final d = date?.toLocal();
    if (d == null) return '';
    return '${d.day} ${_months[d.month]}, $timeLabel';
  }

  /// "Just now" / "5m ago" / "2h ago" / "3d ago" relative to now.
  String get relativeLabel {
    final d = date?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  factory ChildLocation.fromJson(Map<String, dynamic> json) {
    return ChildLocation(
      id: json['_id']?.toString() ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      address: json['address']?.toString() ?? '',
      childId: json['child_id']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
    );
  }
}

/// Response wrapper for `/api/locations/latest/{childId}` — a single object
/// holding the child's most recent fix (or none if nothing recorded yet).
class LatestLocationResponse {
  final int status;
  final ChildLocation? location;

  const LatestLocationResponse({required this.status, required this.location});

  factory LatestLocationResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['location'];
    return LatestLocationResponse(
      status: (json['status'] as num?)?.toInt() ?? 200,
      location: raw is Map<String, dynamic>
          ? ChildLocation.fromJson(raw)
          : null,
    );
  }
}

/// Response wrapper for `/api/locations/history/{childId}?hours=N` — every fix
/// recorded within the requested time window, newest first.
class LocationHistoryResponse {
  final int status;
  final int windowHours;
  final DateTime? since;
  final int total;
  final List<ChildLocation> locations;

  const LocationHistoryResponse({
    required this.status,
    required this.windowHours,
    required this.since,
    required this.total,
    required this.locations,
  });

  factory LocationHistoryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['locations'];
    final list = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(ChildLocation.fromJson)
              .toList()
        : <ChildLocation>[];

    // Newest first — most recent whereabouts at the top of the list.
    list.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null || db == null) return b.id.compareTo(a.id);
      return db.compareTo(da);
    });

    return LocationHistoryResponse(
      status: (json['status'] as num?)?.toInt() ?? 200,
      windowHours: (json['windowHours'] as num?)?.toInt() ?? 0,
      since: DateTime.tryParse(json['since']?.toString() ?? ''),
      total: (json['total'] as num?)?.toInt() ?? list.length,
      locations: list,
    );
  }
}
