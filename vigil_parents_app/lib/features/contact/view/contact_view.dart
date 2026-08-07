import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/utils/polling_screen.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_search_field.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/permission_denied_view.dart';
import 'package:vigil_parents_app/features/contact/models/contacts_model.dart';
import 'package:vigil_parents_app/features/contact/presentation/view_model/contacts_viewmodel.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage>
    with WidgetsBindingObserver, PollingScreen<ContactsPage> {
  final _searchController = TextEditingController();

  @override
  Duration get pollInterval => const Duration(minutes: 5);

  @override
  String? get pollFeature => SyncFeature.contacts;

  @override
  void onPoll() => ref.read(contactsViewModelProvider).refresh();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      if (!mounted) return;
      ref.read(contactsViewModelProvider).loadContacts();
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) ref.read(childPermissionsProvider).ensureLoadedFor(id);
    });

    startPolling();
  }

  @override
  void dispose() {
    stopPolling();
    _searchController.dispose();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    ref.read(contactsViewModelProvider).reload();
    ref.read(childPermissionsProvider).load(childId);
  }

  void _openDetail(ContactModel contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactDetailSheet(contact: contact),
    );
  }

  Widget _buildList(ContactsViewModel vm, Size size) {
    if (vm.loading && vm.contacts.isEmpty) {
      return const ListShimmer();
    }

    if (vm.error != null && vm.contacts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.16),
          const Icon(
            Icons.cloud_off_rounded,
            size: 52,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              vm.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Pull down to retry',
              style: TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ),
        ],
      );
    }

    if (vm.contacts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.16),
          Icon(Icons.contacts_outlined, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No contacts found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: vm.contacts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final c = vm.contacts[index];
        return _ContactRow(contact: c, onTap: () => _openDetail(c));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(contactsViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    // Contacts sharing is switched off on the child's device.
    final permsVm = ref.watch(childPermissionsProvider);
    final denied = permsVm.isDenied(
      selectedChild.selectedId,
      ChildFeature.contacts,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              AppHeader(showBack: true),

              const SizedBox(height: 16),

              if (noChild)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: NoChildLinkedView(
                        refreshing: selectedChild.loading,
                        onRefresh: () =>
                            ref.read(selectedChildProvider).load(force: true),
                      ),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Contacts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Child picker — compact, right-aligned, shows selected child.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: ChildSelectorDropdown(onChanged: _onChildSelected),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (denied)
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(childPermissionsProvider)
                          .load(selectedChild.selectedId!),
                      child: PermissionDeniedBody(
                        feature: ChildFeature.contacts,
                        childName: selectedChild.selected?.name,
                        refreshing: permsVm.loading,
                        onRefresh: () => ref
                            .read(childPermissionsProvider)
                            .load(selectedChild.selectedId!),
                      ),
                    ),
                  )
                else ...[
                  /// SEARCH
                  AppSearchField(
                    controller: _searchController,
                    hint: 'Search name or number...',
                    value: vm.query,
                    onChanged: (value) =>
                        ref.read(contactsViewModelProvider).setQuery(value),
                    onClear: () {
                      _searchController.clear();
                      ref.read(contactsViewModelProvider).setQuery('');
                    },
                  ),

                  const SizedBox(height: 14),

                  _ContactsSummary(
                    shown: vm.contacts.length,
                    total: vm.total,
                    filtered: vm.query.isNotEmpty,
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: vm.refresh,
                      child: _buildList(vm, size),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary strip ───────────────────────────────────────────────────────────
class _ContactsSummary extends StatelessWidget {
  final int shown;
  final int total;
  final bool filtered;

  const _ContactsSummary({
    required this.shown,
    required this.total,
    required this.filtered,
  });

  @override
  Widget build(BuildContext context) {
    final text = filtered
        ? '$shown result${shown == 1 ? '' : 's'}'
        : '$total contact${total == 1 ? '' : 's'}';
    return Row(
      children: [
        const Icon(
          Icons.people_alt_rounded,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Contact row ─────────────────────────────────────────────────────────────
class _ContactRow extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onTap;

  const _ContactRow({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final extraPhones = contact.phones.length - 1;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  contact.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.label.isEmpty ? 'Unknown' : contact.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            contact.primaryPhone.isEmpty
                                ? 'No number'
                                : contact.primaryPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (extraPhones > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+$extraPhones',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contact detail bottom sheet ──────────────────────────────────────────────
class _ContactDetailSheet extends StatelessWidget {
  final ContactModel contact;

  const _ContactDetailSheet({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECEF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    contact.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    contact.label.isEmpty ? 'Unknown' : contact.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.phones.length > 1 ? 'PHONE NUMBERS' : 'PHONE NUMBER',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                if (contact.phones.isEmpty)
                  const Text(
                    'No numbers saved',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (final phone in contact.phones)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.scaffold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
