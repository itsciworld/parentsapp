import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/core/utils/refresh_guard.dart';
import 'package:vigil_parents_app/features/gallery/models/media_model.dart';
import 'package:vigil_parents_app/features/gallery/repo/gallery_repo.dart';

/// Drives the media/gallery screen: loads paged media for the selected child,
/// supports an All / Photos / Videos filter, pull-to-refresh and infinite
/// scroll. Designed to live behind a [ChangeNotifierProvider] like the SMS VM.
class GalleryViewModel extends ChangeNotifier with RefreshGuard {
  GalleryViewModel(this.repository);

  final GalleryRepository repository;

  static const int _pageSize = 20;

  final List<MediaItem> _items = [];
  List<MediaItem> get items => List.unmodifiable(_items);

  MediaFilter _filter = MediaFilter.all;
  MediaFilter get filter => _filter;

  bool loading = false; // full-screen loader (first page / filter change)
  bool loadingMore = false; // footer loader (next page)
  String? error;

  int _page = 1;
  int _pages = 0;
  int _total = 0;
  String _childId = '';

  /// Total items reported by the backend for the active filter.
  int get total => _total;

  int get imageCount => _items.where((m) => m.isImage).length;
  int get videoCount => _items.where((m) => m.isVideo).length;

  bool get hasMore => _page < _pages;
  bool get isEmpty => _items.isEmpty;

  /// Loads the first page for the current filter / selected child.
  Future<void> load({bool showLoader = true}) async {
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) {
        _items.clear();
        _total = 0;
        _pages = 0;
        error = ctx.childId.isEmpty
            ? 'No child linked to this account yet'
            : 'Missing account information';
      } else {
        _childId = ctx.childId;
        final res = await repository.getFiles(
          childId: ctx.childId,
          parentId: ctx.parentId,
          filter: _filter,
          page: 1,
          limit: _pageSize,
        );
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.page;
        _pages = res.pages;
        _total = res.total;
        error = null;
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Loads the next page and appends it. No-op when already loading or done.
  Future<void> loadMore() async {
    if (loadingMore || loading || !hasMore || _childId.isEmpty) return;

    loadingMore = true;
    notifyListeners();

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) return;

      final res = await repository.getFiles(
        childId: ctx.childId,
        parentId: ctx.parentId,
        filter: _filter,
        page: _page + 1,
        limit: _pageSize,
      );
      // Guard against duplicates if the same id arrives twice.
      final existing = _items.map((e) => e.id).toSet();
      _items.addAll(res.items.where((m) => !existing.contains(m.id)));
      _page = res.page;
      _pages = res.pages;
      _total = res.total;
    } catch (_) {
      // Keep the current list; a failed "load more" shouldn't wipe the screen.
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  /// Switches the All / Photos / Videos filter and reloads from page 1.
  Future<void> setFilter(MediaFilter value) async {
    if (_filter == value) return;
    _filter = value;
    _items.clear();
    _page = 1;
    _pages = 0;
    notifyListeners();
    await load();
  }

  /// Silent refresh (used by the poll timer / pull-to-refresh).
  Future<void> refresh() => guardedRefresh(() => load(showLoader: false));

  /// Reload from scratch — used when the selected child changes.
  Future<void> reload() async {
    _items.clear();
    _page = 1;
    _pages = 0;
    _childId = '';
    await load();
  }
}

final galleryViewModelProvider = ChangeNotifierProvider<GalleryViewModel>((
  ref,
) {
  return GalleryViewModel(ref.read(galleryRepositoryProvider));
});
