import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/services/background/sync_signals.dart';
import 'package:vigil_parents_app/core/utils/polling_screen.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_search_field.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/components/day_window_selector.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/permission_denied_view.dart';
import 'package:vigil_parents_app/features/sms/models/sms_thread_model.dart';
import 'package:vigil_parents_app/features/sms/view/conversation_view.dart';
import 'package:vigil_parents_app/features/sms/view_model/sms_viewmodel.dart';
import 'package:vigil_parents_app/features/sms/widgets/sms_state_card.dart';
import 'package:vigil_parents_app/features/sms/widgets/thread_card.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});

  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen>
    with WidgetsBindingObserver, PollingScreen<SmsScreen> {
  final _searchController = TextEditingController();

  @override
  Duration get pollInterval => const Duration(seconds: 5);

  @override
  String? get pollFeature => SyncFeature.sms;

  @override
  void onPoll() => ref.read(smsViewModelProvider).refresh();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      // Load the children list for the picker, then the threads for the
      // currently selected child.
      await ref.read(selectedChildProvider).load();
      if (!mounted) return;
      ref.read(smsViewModelProvider).loadThreads();
      final id = ref.read(selectedChildProvider).selectedId;
      // Tells us whether the child shares messages at all — an empty list means
      // very different things with and without that permission.
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

  /// Takes the thread itself rather than its index: this screen re-polls every
  /// 5 seconds, so by the time a tap is handled the list may have been rebuilt
  /// and that index can point at a different conversation — or past the end.
  void _openThread(SmsThread thread) {
    final vm = ref.read(smsViewModelProvider);
    // Mark read so the unread badge clears once the conversation is opened.
    vm.markThreadSeen(thread);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConversationScreen(thread: thread)),
    );
  }

  Widget _buildList(SmsViewModel vm, Size size) {
    // Both of these ask "have we got anything for this child?", which is about
    // what was loaded, not what the filter currently shows — otherwise picking
    // a narrow day window put the screen back into a shimmer or an error state.
    if (vm.loading && vm.loadedThreads == 0) {
      return const ListShimmer();
    }

    if (vm.error != null && vm.loadedThreads == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.18),
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

    if (vm.threads.isEmpty) {
      // "Nothing here" and "nothing matches your filter" are very different
      // messages. Showing the first for the second is what made the day chips
      // look broken — the list emptied with no hint that a filter did it.
      final hidden = vm.loadedThreads > 0;
      final searching = vm.query.trim().isNotEmpty;

      final String title;
      final String? hint;
      if (!hidden) {
        title = 'No conversations yet';
        hint = null;
      } else if (searching) {
        title = 'No conversations match "${vm.query.trim()}"';
        hint = 'Clear the search to see all ${vm.loadedThreads} chats';
      } else {
        title = 'Nothing in the ${vm.activeWindow.label.toLowerCase()}';
        hint = 'Tap "All" to see all ${vm.loadedThreads} chats';
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.18),
          Icon(
            hidden ? Icons.filter_list_off_rounded : Icons.sms_outlined,
            size: 52,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ),
          ],
        ],
      );
    }

    // Resolve the filtered list once — the getter re-runs the window and search
    // filters on every read, and the builder would hit it twice per row.
    final threads = vm.threads;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final thread = threads[index];
        return ThreadCard(
          thread: thread,
          unread: vm.unreadFor(thread),
          onTap: () => _openThread(thread),
        );
      },
    );
  }

  /// Reloads threads for the newly-selected child. The dropdown itself
  /// persists the selection.
  void _onChildSelected(String childId) {
    ref.read(smsViewModelProvider).reload();
    ref.read(childPermissionsProvider).load(childId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(smsViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    // No child registered/linked to this account yet (only after the first
    // fetch completes, so we don't flash this state before loading).
    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

    // The child has messages sharing switched off, so there is nothing to
    // show — say so rather than rendering an empty conversation list.
    final permsVm = ref.watch(childPermissionsProvider);
    final denied = permsVm.isDenied(
      selectedChild.selectedId,
      ChildFeature.messages,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              AppHeader(onActionTap: () {}),

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
                /// CHILD PICKER — compact, right-aligned, shows selected child.
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: ChildSelectorDropdown(onChanged: _onChildSelected),
                  ),
                ),

                const SizedBox(height: 12),

                if (denied)
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref
                          .read(childPermissionsProvider)
                          .load(selectedChild.selectedId!),
                      child: PermissionDeniedBody(
                        feature: ChildFeature.messages,
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
                    hint: 'Search conversations or numbers...',
                    value: vm.query,
                    onChanged: (value) =>
                        ref.read(smsViewModelProvider).setQuery(value),
                    onClear: () {
                      _searchController.clear();
                      ref.read(smsViewModelProvider).setQuery('');
                    },
                  ),

                  const SizedBox(height: 12),

                  SmsStateCard(
                    threads: vm.totalThreads,
                    messages: vm.totalMessages,
                  ),

                  const SizedBox(height: 12),

                  DayWindowSelector(
                    selected: vm.activeWindow,
                    enabled: !vm.loading,
                    onSelected: (w) =>
                        ref.read(smsViewModelProvider).setWindow(w),
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
