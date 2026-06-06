import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_search_field.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';
import 'package:vigil_parents_app/features/sms/view/conversation_view.dart';
import 'package:vigil_parents_app/features/sms/view_model/sms_viewmodel.dart';
import 'package:vigil_parents_app/features/sms/widgets/sms_state_card.dart';
import 'package:vigil_parents_app/features/sms/widgets/thread_card.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});

  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen> {
  Timer? _pollTimer;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      // Load the children list for the picker, then the threads for the
      // currently selected child.
      await ref.read(selectedChildProvider).load();
      ref.read(smsViewModelProvider).loadThreads();
    });

    // While the screen is open, refresh from the API every 5 seconds.
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(smsViewModelProvider).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openThread(int index) {
    final vm = ref.read(smsViewModelProvider);
    final thread = vm.threads[index];
    // Mark read so the unread badge clears once the conversation is opened.
    vm.markThreadSeen(thread);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConversationScreen(thread: thread)),
    );
  }

  Widget _buildList(SmsViewModel vm, Size size) {
    if (vm.loading && vm.threads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null && vm.threads.isEmpty) {
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.18),
          const Icon(Icons.sms_outlined, size: 52, color: Colors.black26),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No conversations yet',
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
      itemCount: vm.threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => ThreadCard(
        thread: vm.threads[index],
        unread: vm.unreadFor(vm.threads[index]),
        onTap: () => _openThread(index),
      ),
    );
  }

  /// Reloads threads for the newly-selected child. The dropdown itself
  /// persists the selection.
  void _onChildSelected(String childId) {
    ref.read(smsViewModelProvider).reload();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(smsViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    // No child registered/linked to this account yet (only after the first
    // fetch completes, so we don't flash this state before loading).
    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

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

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: vm.refresh,
                    child: _buildList(vm, size),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
