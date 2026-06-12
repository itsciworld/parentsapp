/// A single tracked app and how long the child used it.
class AppUsage {
  final String id;
  final String appName;
  final String packageName;
  final int usageMinutes;
  final DateTime? lastTimeUsed;

  const AppUsage({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.usageMinutes,
    required this.lastTimeUsed,
  });

  factory AppUsage.fromJson(Map<String, dynamic> json) {
    final usage = json['usageInfo'];
    final info = usage is Map<String, dynamic> ? usage : const {};
    return AppUsage(
      id: json['_id']?.toString() ?? '',
      appName: json['appName']?.toString() ?? 'Unknown app',
      packageName: json['packageName']?.toString() ?? '',
      usageMinutes: (info['usageMinutes'] as num?)?.toInt() ?? 0,
      lastTimeUsed: DateTime.tryParse(info['lastTimeUsed']?.toString() ?? ''),
    );
  }

  /// "1h 15m" / "45m" — a friendly duration label.
  String get usageLabel => formatMinutes(usageMinutes);

  static String formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

/// Paginated response wrapper for `/api/apps/get_apps`.
class AppUsageResponse {
  final int status;
  final int total;
  final int page;
  final int limit;
  final int pages;
  final List<AppUsage> apps;

  const AppUsageResponse({
    required this.status,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
    required this.apps,
  });

  factory AppUsageResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['apps'];
    final list = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(AppUsage.fromJson).toList()
        : <AppUsage>[];

    return AppUsageResponse(
      status: (json['status'] as num?)?.toInt() ?? 200,
      total: (json['total'] as num?)?.toInt() ?? list.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? list.length,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      apps: list,
    );
  }
}
