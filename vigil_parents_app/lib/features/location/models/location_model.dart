import 'package:latlong2/latlong.dart';

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

  const ChildLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.childId,
    required this.parentId,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// "22.7608, 75.8975" — a compact, fixed-precision coordinate label.
  String get coordinates =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

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
    );
  }
}

/// Paginated response wrapper for `/api/locations/get_locations`.
class LocationsResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<ChildLocation> locations;

  const LocationsResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.locations,
  });

  factory LocationsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['locations'];
    final list = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(ChildLocation.fromJson)
              .toList()
        : <ChildLocation>[];

    return LocationsResponse(
      status: (json['status'] as num?)?.toInt() ?? 200,
      total: (json['total'] as num?)?.toInt() ?? list.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? list.length,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      locations: list,
    );
  }
}
