/// Models for the media/gallery endpoint `/api/files/get_files`.
///
/// Response shape:
/// {
///   status, total, page, limit, pages, child_id, parent_id,
///   media: [ {...} ],   // canonical list we render
///   files: [ {...} ]    // mirror of `media` kept for backwards-compat
/// }
library;

/// The kind of media a tile represents.
enum MediaType { image, video, unknown }

/// Filter applied to the gallery (maps to the `file_type` query param).
enum MediaFilter {
  all,
  image,
  video;

  /// Value sent as `file_type`, or null for "all".
  String? get queryValue => switch (this) {
    MediaFilter.all => null,
    MediaFilter.image => 'image',
    MediaFilter.video => 'video',
  };

  String get label => switch (this) {
    MediaFilter.all => 'All',
    MediaFilter.image => 'Photos',
    MediaFilter.video => 'Videos',
  };
}

/// Wraps the paged `/api/files/get_files` response.
class MediaResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final String childId;
  final String parentId;
  final List<MediaItem> items;

  const MediaResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.childId,
    required this.parentId,
    required this.items,
  });

  /// True if there is at least one more page after the current one.
  bool get hasMore => page < pages;

  factory MediaResponse.fromJson(Map<String, dynamic> json) {
    // Prefer `media`; fall back to `files` if the backend only sends that.
    final raw = json['media'] ?? json['files'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((m) => MediaItem.fromJson(Map<String, dynamic>.from(m)))
              .toList()
        : <MediaItem>[];

    return MediaResponse(
      status: _toInt(json['status'], fallback: 200),
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      limit: _toInt(json['limit'], fallback: 20),
      pages: _toInt(json['pages']),
      childId: (json['child_id'] ?? '').toString(),
      parentId: (json['parent_id'] ?? '').toString(),
      items: items,
    );
  }

  static const empty = MediaResponse(
    status: 200,
    total: 0,
    page: 1,
    limit: 20,
    pages: 0,
    childId: '',
    parentId: '',
    items: [],
  );

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

class MediaItem {
  final String id;
  final String mediaId;
  final String url;
  final String originalFilename;
  final String title;
  final String fileType;
  final MediaType type;
  final String mimeType;
  final int width;
  final int height;
  final int sizeBytes;
  final int durationSeconds;
  final bool isFavorite;
  final String albumName;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;

  const MediaItem({
    required this.id,
    required this.mediaId,
    required this.url,
    required this.originalFilename,
    required this.title,
    required this.fileType,
    required this.type,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.durationSeconds,
    required this.isFavorite,
    required this.albumName,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
  });

  bool get isVideo => type == MediaType.video;
  bool get isImage => type == MediaType.image;
  bool get hasLocation => latitude != null && longitude != null;

  /// Best display name for the item.
  String get displayName => title.isNotEmpty
      ? title
      : (originalFilename.isNotEmpty ? originalFilename : mediaId);

  /// Human-readable file size, e.g. "3.7 MB".
  String get formattedSize {
    if (sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = sizeBytes.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final value = size >= 10 || size == size.roundToDouble()
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$value ${units[unit]}';
  }

  /// Video duration as "m:ss" (empty for non-videos / unknown duration).
  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Capture time as "10:30 AM" in the device's local timezone.
  String get formattedTime {
    final dt = capturedAt;
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// "Today", "Yesterday" or "2 Jun 2026".
  String get formattedDate {
    final dt = capturedAt?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    final typeRaw = pick(['type', 'media_type']).toLowerCase();
    final mime = pick(['mime_type', 'file_type']).toLowerCase();
    final type = switch (true) {
      _ when typeRaw == 'video' || mime.startsWith('video') => MediaType.video,
      _ when typeRaw == 'image' || mime.startsWith('image') => MediaType.image,
      _ => MediaType.unknown,
    };

    return MediaItem(
      id: pick(['_id', 'id']),
      mediaId: pick(['media_id', 'mediaId']),
      url: pick(['url', 'secure_url', 'download_url']),
      originalFilename: pick([
        'original_filename',
        'originalFilename',
        'filename',
      ]),
      title: pick(['title', 'name']),
      fileType: pick(['file_type', 'fileType']),
      type: type,
      mimeType: pick(['mime_type', 'mimeType', 'file_type']),
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      sizeBytes: _toInt(
        json['size_bytes'] ?? json['sizeBytes'] ?? json['size'],
      ),
      durationSeconds: _toInt(
        json['duration_seconds'] ?? json['durationSeconds'],
      ),
      isFavorite: json['is_favorite'] == true || json['isFavorite'] == true,
      albumName: pick(['album_name', 'albumName']),
      capturedAt: _toDate(
        json['captured_at'] ?? json['capturedAt'] ?? json['createdAt'],
      ),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
