import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_bottom_nav.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_search_field.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/components/day_window_selector.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/calls/models/calls_model.dart';
import 'package:vigil_parents_app/features/calls/presentation/view_model/calls_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/no_child_linked_view.dart';

// Call-type colors.
const _incomingColor = Color(0xFF2E7D32);
const _outgoingColor = Color(0xFF1565C0);
const _missedColor = AppColors.alert;

Color _typeColor(CallType t) => switch (t) {
  CallType.incoming => _incomingColor,
  CallType.outgoing => _outgoingColor,
  CallType.missed => _missedColor,
};

IconData _typeIcon(CallType t) => switch (t) {
  CallType.incoming => Icons.call_received_rounded,
  CallType.outgoing => Icons.call_made_rounded,
  CallType.missed => Icons.call_missed_rounded,
};

String _typeLabel(CallType t) => switch (t) {
  CallType.incoming => 'Incoming',
  CallType.outgoing => 'Outgoing',
  CallType.missed => 'Missed',
};

class AccessCallsScreen extends ConsumerStatefulWidget {
  const AccessCallsScreen({super.key});

  @override
  ConsumerState<AccessCallsScreen> createState() => _AccessCallsScreenState();
}

class _AccessCallsScreenState extends ConsumerState<AccessCallsScreen> {
  Timer? _pollTimer;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(selectedChildProvider).load();
      ref.read(callLogViewModelProvider).loadCallLogs();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(callLogViewModelProvider).refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChildSelected(String childId) {
    ref.read(callLogViewModelProvider).reload();
  }

  void _openDetail(CallLogModel log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallDetailSheet(log: log),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(callLogViewModelProvider);
    final selectedChild = ref.watch(selectedChildProvider);
    final size = MediaQuery.of(context).size;

    final noChild = selectedChild.initialized && selectedChild.children.isEmpty;

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
                        'Call Logs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: ChildSelectorDropdown(onChanged: _onChildSelected),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppSearchField(
                  controller: _searchController,
                  hint: 'Search number or contact name...',
                  value: vm.query,
                  onChanged: (v) =>
                      ref.read(callLogViewModelProvider).setQuery(v),
                  onClear: () {
                    _searchController.clear();
                    ref.read(callLogViewModelProvider).setQuery('');
                  },
                ),
                const SizedBox(height: 12),
                _FilterTabs(
                  active: vm.activeFilter,
                  summary: vm.windowedSummary,
                  onSelect: (f) =>
                      ref.read(callLogViewModelProvider).setFilter(f),
                ),
                const SizedBox(height: 10),
                DayWindowSelector(
                  selected: vm.activeWindow,
                  enabled: !vm.loading,
                  onSelected: (w) =>
                      ref.read(callLogViewModelProvider).setWindow(w),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
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

  Widget _buildList(CallLogViewModel vm, Size size) {
    if (vm.loading && vm.logs.isEmpty) {
      return const ListShimmer();
    }

    if (vm.error != null && vm.logs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.14),
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

    if (vm.logs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: size.height * 0.14),
          Icon(
            Icons.phone_disabled_rounded,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No calls found',
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

    // Flatten the grouped map into header + tile rows.
    final items = <_Row>[];
    vm.groupedLogs.forEach((label, logs) {
      items.add(_Row.header(label, logs.length));
      for (final l in logs) {
        items.add(_Row.tile(l));
      }
    });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final row = items[i];
        if (row.isHeader) {
          return _DateHeader(label: row.label!, count: row.count);
        }
        return _CallTile(log: row.log!, onTap: () => _openDetail(row.log!));
      },
    );
  }
}

/// A flattened list row: either a date header or a call tile.
class _Row {
  final bool isHeader;
  final String? label;
  final int count;
  final CallLogModel? log;

  _Row.header(this.label, this.count) : isHeader = true, log = null;
  _Row.tile(this.log) : isHeader = false, label = null, count = 0;
}

// ── Filter tabs (with per-type counts) ───────────────────────────────────────
class _FilterTabs extends StatelessWidget {
  final CallFilter active;
  final CallSummaryModel summary;
  final ValueChanged<CallFilter> onSelect;

  const _FilterTabs({
    required this.active,
    required this.summary,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab('All', CallFilter.all, summary.totalCalls, AppColors.primary),
        const SizedBox(width: 8),
        _tab(
          'Incoming',
          CallFilter.incoming,
          summary.incomingCalls,
          _incomingColor,
        ),
        const SizedBox(width: 8),
        _tab(
          'Outgoing',
          CallFilter.outgoing,
          summary.outgoingCalls,
          _outgoingColor,
        ),
        const SizedBox(width: 8),
        _tab('Missed', CallFilter.missed, summary.missedCalls, _missedColor),
      ],
    );
  }

  Widget _tab(String label, CallFilter filter, int count, Color accent) {
    final isActive = active == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? accent : AppColors.scaffold,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? accent : AppColors.cardBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : accent,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date header ──────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  final int count;
  const _DateHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Call tile ────────────────────────────────────────────────────────────────
class _CallTile extends StatelessWidget {
  final CallLogModel log;
  final VoidCallback onTap;

  const _CallTile({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(log.callType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                // Avatar with call-type mini-badge.
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: log.isUnknown
                          ? AppColors.scaffold
                          : AppColors.primaryLight,
                      child: log.isUnknown
                          ? const Icon(
                              Icons.person_rounded,
                              color: AppColors.textSecondary,
                              size: 24,
                            )
                          : Text(
                              log.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(
                          _typeIcon(log.callType),
                          color: Colors.white,
                          size: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.label,
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
                          Icon(_typeIcon(log.callType), size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            _typeLabel(log.callType),
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (log.callType != CallType.missed) ...[
                            const Text(
                              '  ·  ',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            Text(
                              log.formattedDuration,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  log.formattedTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Call detail bottom sheet ─────────────────────────────────────────────────
class _CallDetailSheet extends StatelessWidget {
  final CallLogModel log;
  const _CallDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(log.callType);

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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: log.isUnknown
                      ? AppColors.scaffold
                      : AppColors.primaryLight,
                  child: log.isUnknown
                      ? const Icon(
                          Icons.person_rounded,
                          color: AppColors.textSecondary,
                          size: 30,
                        )
                      : Text(
                          log.initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.label,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _typeIcon(log.callType),
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _typeLabel(log.callType),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _detailRow(
                  Icons.phone_rounded,
                  'Number',
                  log.number.isEmpty ? 'Unknown' : log.number,
                ),
                _detailRow(
                  Icons.swap_vert_rounded,
                  'Call type',
                  _typeLabel(log.callType),
                ),
                _detailRow(
                  Icons.timer_outlined,
                  'Duration',
                  log.callType == CallType.missed
                      ? 'Not answered'
                      : (log.durationSeconds <= 0
                            ? '—'
                            : _fullDuration(log.durationSeconds)),
                ),
                _detailRow(
                  Icons.calendar_today_outlined,
                  'Date & time',
                  _fullDateTime(log.timestamp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fullDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '$m min $s sec';
    return '$s sec';
  }

  static String _fullDateTime(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month]} ${dt.year}, $hour:$minute $period';
  }
}
