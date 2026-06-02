import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/features/sms/view_model/sms_viewmodel.dart';
import 'package:vigil_parents_app/features/sms/widgets/message_card.dart';

import 'package:vigil_parents_app/features/sms/widgets/sms_state_card.dart';

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

    Future.microtask(() {
      ref.read(smsViewModelProvider).loadMessages();
    });

    // While the screen is open, refresh from the API every 5 seconds.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(smsViewModelProvider).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildList(SmsViewModel vm, Size size) {
    if (vm.loading && vm.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error != null && vm.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.18),
          const Icon(Icons.cloud_off_rounded, size: 52, color: Colors.redAccent),
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

    if (vm.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.18),
          const Icon(Icons.sms_outlined, size: 52, color: Colors.black26),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No messages yet',
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
      // One extra row for the "load more" footer when applicable.
      itemCount: vm.messages.length + (vm.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, index) {
        if (index >= vm.messages.length) {
          return _loadMoreFooter(vm);
        }
        return MessageCard(model: vm.messages[index], width: size.width);
      },
    );
  }

  Widget _loadMoreFooter(SmsViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: vm.loadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton.icon(
                onPressed: () => ref.read(smsViewModelProvider).loadMore(),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text('Show more (${vm.total - vm.messages.length} left)'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(smsViewModelProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // bottomNavigationBar: const BottomNavbar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              AppHeader(onActionTap: () {}),

              const SizedBox(height: 20),

              /// SEARCH
              TextField(
                controller: _searchController,
                onChanged: (value) =>
                    ref.read(smsViewModelProvider).setQuery(value),
                decoration: InputDecoration(
                  hintText: "Search messages or contacts...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: vm.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(smsViewModelProvider).setQuery('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(width: .5, color: Colors.black),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              SmsStateCard(total: vm.total, unknown: vm.unknownCount),

              const SizedBox(height: 18),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: vm.refresh,
                  child: _buildList(vm, size),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
