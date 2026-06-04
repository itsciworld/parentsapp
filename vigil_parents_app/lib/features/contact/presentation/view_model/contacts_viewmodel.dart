import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';

/// Drives the contacts screen: paginated load for the selected child plus a
/// search filter. Uses page=1 with a growing limit so the list stays stable
/// across the 5s foreground refresh while still supporting "load more".
class ContactsViewModel extends ChangeNotifier {
  final ContactsRepository repository;

  ContactsViewModel(this.repository);

  static const int pageSize = 20;

  List<ContactModel> _all = [];
  bool loading = false;
  bool loadingMore = false;
  String? error;
  int total = 0;
  int _limit = pageSize;
  String _query = '';

  String get query => _query;

  /// Contacts after applying the current search query (name or any number).
  List<ContactModel> get contacts {
    if (_query.trim().isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where(
          (c) =>
              c.displayName.toLowerCase().contains(q) ||
              c.phones.any((p) => p.toLowerCase().contains(q)),
        )
        .toList();
  }

  /// More contacts exist on the server than we've loaded.
  bool get hasMore => _query.trim().isEmpty && _all.length < total;

  Future<void> loadContacts({bool showLoader = true}) async {
    if (showLoader) {
      loading = true;
      error = null;
      notifyListeners();
    }

    try {
      final ctx = await repository.resolveContext();
      if (!ctx.isValid) {
        _all = [];
        total = 0;
        error = ctx.childId.isEmpty
            ? 'No child linked to this account yet'
            : 'Missing account information';
      } else {
        final res = await repository.getContacts(
          childId: ctx.childId,
          parentId: ctx.parentId,
          page: 1,
          limit: _limit,
        );
        _all = res.contacts;
        total = res.total;
        error = null;
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Loads the next page window.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();

    _limit += pageSize;
    await loadContacts(showLoader: false);

    loadingMore = false;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Reloads from scratch — used when the selected child changes.
  Future<void> reload() async {
    _limit = pageSize;
    _all = [];
    await loadContacts();
  }

  Future<void> refresh() => loadContacts(showLoader: false);
}

final contactsViewModelProvider = ChangeNotifierProvider((ref) {
  return ContactsViewModel(ContactsRepository());
});
