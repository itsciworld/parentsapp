import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vigil_parents_app/features/contact/contact_repo.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';

/// Drives the contacts screen: loads all contacts for the selected child in a
/// single request (no lazy loading) plus a search filter.
class ContactsViewModel extends ChangeNotifier {
  final ContactsRepository repository;

  ContactsViewModel(this.repository);

  // Large limit so a single request returns the whole contact list.
  static const int _allLimit = 1000;

  List<ContactModel> _all = [];
  bool loading = false;
  String? error;
  int total = 0;
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
          limit: _allLimit,
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

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// Reloads from scratch — used when the selected child changes.
  Future<void> reload() async {
    _all = [];
    await loadContacts();
  }

  Future<void> refresh() => loadContacts(showLoader: false);
}

final contactsViewModelProvider = ChangeNotifierProvider((ref) {
  return ContactsViewModel(ContactsRepository());
});
