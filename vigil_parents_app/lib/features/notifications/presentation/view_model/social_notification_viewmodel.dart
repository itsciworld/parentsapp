import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/notifications/models/social_notification_model.dart';
import 'package:vigil_parents_app/features/notifications/repo/social_notification_repo.dart';

/// Loads social-app notifications for the selected child and owns the app
/// filter (null = "All"). Apps are kept in the API's order; the flattened feed
/// is sorted newest-first.
class SocialNotificationViewModel extends ChangeNotifier {
  SocialNotificationViewModel(this._repository);

  final SocialNotificationRepository _repository;

  List<AppNotifications> apps = const [];
  int totalMessages = 0;
  bool loading = false;
  String? error;

  /// History window in days (server default is 2). Options: 1 / 2 / 3 / 5.
  int _days = 2;
  int get days => _days;

  /// The child the current [apps] belong to.
  String? _childId;
  String? get childId => _childId;

  /// Package name of the app the user is filtering by; null shows all apps.
  String? _filterPackage;
  String? get filterPackage => _filterPackage;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Conversation threads (SMS-inbox style), most-recently-active first,
  /// filtered by the selected app (if any).
  List<NotificationThreadItem> get threadItems {
    final result = <NotificationThreadItem>[];
    for (final app in apps) {
      if (_filterPackage != null && app.package != _filterPackage) continue;
      for (final t in app.threads) {
        result.add(
          NotificationThreadItem(app: app.app, package: app.package, thread: t),
        );
      }
    }
    result.sort((a, b) => _cmpDesc(a.thread.lastTime, b.thread.lastTime));
    return result;
  }

  static int _cmpDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  /// The flattened, newest-first feed, filtered by the selected app (if any).
  List<SocialNotificationItem> get items {
    final result = <SocialNotificationItem>[];
    for (final app in apps) {
      if (_filterPackage != null && app.package != _filterPackage) continue;
      for (final m in app.messages) {
        result.add(
          SocialNotificationItem(
            app: app.app,
            package: app.package,
            message: m,
          ),
        );
      }
    }
    result.sort((a, b) {
      final at = a.message.timestamp;
      final bt = b.message.timestamp;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return result;
  }

  Future<void> load(String childId, {bool showLoader = true}) async {
    if (_childId != childId) {
      apps = const [];
      totalMessages = 0;
      error = null;
      _filterPackage = null;
    }
    _childId = childId;

    if (showLoader) {
      loading = true;
      error = null;
      _safeNotify();
    }

    try {
      final res = await _repository.getNotifications(
        childId: childId,
        days: _days,
      );
      if (_childId != childId) return; // selection changed mid-flight
      apps = res.apps;
      totalMessages = res.totalMessages;
      // Drop a stale filter if that app is no longer present.
      if (_filterPackage != null &&
          !apps.any((a) => a.package == _filterPackage)) {
        _filterPackage = null;
      }
      error = null;
    } catch (e) {
      if (_childId != childId) return;
      error = e.toString().replaceAll('Exception: ', '');
      if (kDebugMode) print('[Notifications] Load error: $error');
    } finally {
      if (_childId == childId) {
        loading = false;
        _safeNotify();
      }
    }
  }

  /// Silent reload of the current child — used for pull-to-refresh.
  Future<void> refresh() async {
    final id = _childId;
    if (id == null) return;
    await load(id, showLoader: false);
  }

  /// Set the app filter (pass null for "All").
  void setFilter(String? package) {
    if (_filterPackage == package) return;
    _filterPackage = package;
    _safeNotify();
  }

  /// Change the history window (in days) and reload the current child.
  Future<void> setDays(int days) async {
    if (_days == days) return;
    _days = days;
    _safeNotify();
    final id = _childId;
    if (id != null) await load(id);
  }
}

final socialNotificationRepositoryProvider =
    Provider<SocialNotificationRepository>((ref) {
      return SocialNotificationRepository();
    });

final socialNotificationViewModelProvider =
    ChangeNotifierProvider<SocialNotificationViewModel>((ref) {
      return SocialNotificationViewModel(
        ref.read(socialNotificationRepositoryProvider),
      );
    });
