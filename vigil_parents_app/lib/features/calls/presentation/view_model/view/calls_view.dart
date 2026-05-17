import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/calls/presentation/view_model/calls_viewmodel.dart';

class AccessCallsScreen extends ConsumerStatefulWidget {
  const AccessCallsScreen({super.key});

  @override
  ConsumerState<AccessCallsScreen> createState() => _AccessCallsScreenState();
}

class _AccessCallsScreenState extends ConsumerState<AccessCallsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callLogViewModelProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(callLogViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // _buildAppBar(),
            AppHeader(
              actionIcon: Icons.refresh_rounded,
              onActionTap: () {
                vm.refresh();
              },
            ),

            Expanded(
              child: vm.isLoading && vm.summary == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A7F5A),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF1A7F5A),
                      onRefresh: vm.refresh,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeader(vm)),

                          SliverToBoxAdapter(child: _buildChildDateRow(vm)),

                          const SliverToBoxAdapter(child: SizedBox(height: 16)),

                          SliverToBoxAdapter(child: _buildSearchRow(vm)),

                          const SliverToBoxAdapter(child: SizedBox(height: 16)),

                          SliverToBoxAdapter(child: _buildFilterTabs(vm)),

                          const SliverToBoxAdapter(child: SizedBox(height: 12)),

                          SliverToBoxAdapter(child: _buildSummaryCard(vm)),

                          const SliverToBoxAdapter(child: SizedBox(height: 8)),

                          if (vm.isLoading)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1A7F5A),
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._buildCallLogSections(vm),

                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        ],
                      ),
                    ),
            ),

            // _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A7F5A),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'VIGIL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A7F5A),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Watch Smart. Protect Better',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          _iconButton(
            icon: Icons.refresh_rounded,
            onTap: () => ref.read(callLogViewModelProvider).refresh(),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF333333)),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(CallLogViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: Color(0xFF1A7F5A),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Access Calls',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                "View and monitor your child's call activity",
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Child + Date Row ────────────────────────────────────────────────────────

  Widget _buildChildDateRow(CallLogViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Child Selector
          Expanded(
            child: _dropdownCard(
              label: 'Child',
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1A7F5A),
                    backgroundImage: null,
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vm.selectedChild?.name ?? 'Select Child',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF888888),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Date Selector
          Expanded(
            child: _dropdownCard(
              label: 'Date',
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF1A7F5A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Today, 21 May 2025',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF888888),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownCard({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  // ─── Search + Filter ─────────────────────────────────────────────────────────

  Widget _buildSearchRow(CallLogViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFAAAAAA),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: vm.setSearchQuery,
                      decoration: const InputDecoration(
                        hintText: 'Search number or contact name...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFAAAAAA),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Container(
          //   height: 48,
          //   padding: const EdgeInsets.symmetric(horizontal: 16),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF7F7F7),
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(color: const Color(0xFFEEEEEE)),
          //   ),
          //   child: const Row(
          //     children: [
          //       Icon(
          //         Icons.filter_list_rounded,
          //         color: Color(0xFF555555),
          //         size: 20,
          //       ),
          //       SizedBox(width: 6),
          //       Text(
          //         'Filter',
          //         style: TextStyle(
          //           fontSize: 14,
          //           fontWeight: FontWeight.w600,
          //           color: Color(0xFF555555),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  // ─── Filter Tabs ─────────────────────────────────────────────────────────────

  Widget _buildFilterTabs(CallLogViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _filterTab('All Calls', FilterTab.all, vm),
          const SizedBox(width: 8),
          _filterTab('Incoming', FilterTab.incoming, vm),
          const SizedBox(width: 8),
          _filterTab('Outgoing', FilterTab.outgoing, vm),
          const SizedBox(width: 8),
          _filterTabMissed('Missed', FilterTab.missed, vm),
        ],
      ),
    );
  }

  Widget _filterTab(String label, FilterTab tab, CallLogViewModel vm) {
    final isActive = vm.activeFilter == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.setFilter(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1A3A5C) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF555555),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterTabMissed(String label, FilterTab tab, CallLogViewModel vm) {
    final isActive = vm.activeFilter == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.setFilter(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1A3A5C) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF555555),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${vm.missedCallCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Summary Card ─────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(CallLogViewModel vm) {
    final s = vm.summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _summaryItem(
              icon: Icons.phone_rounded,
              iconColor: const Color(0xFF1A7F5A),
              count: s?.totalCalls ?? 0,
              label: 'Total Calls',
            ),
            _summaryDivider(),
            _summaryItem(
              icon: Icons.call_received_rounded,
              iconColor: const Color(0xFF1565C0),
              count: s?.incomingCalls ?? 0,
              label: 'Incoming',
              iconRotation: -0.5,
            ),
            _summaryDivider(),
            _summaryItem(
              icon: Icons.call_made_rounded,
              iconColor: const Color(0xFF2E7D32),
              count: s?.outgoingCalls ?? 0,
              label: 'Outgoing',
            ),
            _summaryDivider(),
            _summaryItem(
              icon: Icons.call_missed_rounded,
              iconColor: const Color(0xFFE53935),
              count: s?.missedCalls ?? 0,
              label: 'Missed',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
    double iconRotation = 0,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: iconRotation,
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
  }

  // ─── Call Log Sections ───────────────────────────────────────────────────────

  List<Widget> _buildCallLogSections(CallLogViewModel vm) {
    final grouped = vm.groupedCallLogs;
    final sections = <Widget>[];

    grouped.forEach((dateLabel, logs) {
      sections.add(SliverToBoxAdapter(child: _buildDateLabel(dateLabel)));
      sections.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildCallLogTile(logs[index]),
            childCount: logs.length,
          ),
        ),
      );
    });

    return sections;
  }

  Widget _buildDateLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  Widget _buildCallLogTile(CallLogModel log) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(log),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.contactName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.phoneNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                  if (log.isUnknownContact) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 12,
                            color: Color(0xFFF57C00),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Unknown Contact',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFF57C00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCallTypeBadge(log.callType),
                const SizedBox(height: 4),
                Text(
                  log.formattedTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  log.formattedDuration,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(CallLogModel log) {
    if (log.isUnknownContact) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF9E9E9E),
          size: 24,
        ),
      );
    }

    final color = _parseColor(log.avatarColor) ?? const Color(0xFF1A7F5A);
    final initials =
        log.avatarInitials ??
        log.contactName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildCallTypeBadge(CallType type) {
    switch (type) {
      case CallType.incoming:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.call_received_rounded,
              color: Color(0xFF1A7F5A),
              size: 13,
            ),
            SizedBox(width: 3),
            Text(
              'Incoming',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1A7F5A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case CallType.outgoing:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_made_rounded, color: Color(0xFF2E7D32), size: 13),
            SizedBox(width: 3),
            Text(
              'Outgoing',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case CallType.missed:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_missed_rounded, color: Color(0xFFE53935), size: 13),
            SizedBox(width: 3),
            Text(
              'Missed',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }

  // ─── Bottom Nav ──────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFEEEEEE))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _navItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                isActive: false,
              ),
              _navItem(
                icon: Icons.phone_rounded,
                label: 'Calls',
                isActive: true,
              ),
              _navItem(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                isActive: false,
              ),
              _navItemWithBadge(
                icon: Icons.notifications_outlined,
                label: 'Alerts',
                badge: '3',
                isActive: false,
              ),
              _navItem(
                icon: Icons.menu_rounded,
                label: 'More',
                isActive: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF1A7F5A) : const Color(0xFFAAAAAA),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? const Color(0xFF1A7F5A)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItemWithBadge({
    required IconData icon,
    required String label,
    required String badge,
    required bool isActive,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isActive
                    ? const Color(0xFF1A7F5A)
                    : const Color(0xFFAAAAAA),
                size: 24,
              ),
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }
}
