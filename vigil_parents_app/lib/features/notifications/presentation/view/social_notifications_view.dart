import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/components/day_window_selector.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/widgets/app_icon_avatar.dart';
import 'package:vigil_parents_app/features/child/models/child_permissions_model.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/child_permissions_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/permission_denied_view.dart';
import 'package:vigil_parents_app/features/notifications/models/social_notification_model.dart';
import 'package:vigil_parents_app/features/notifications/presentation/view_model/social_notification_viewmodel.dart';

/// Social-app notifications for the selected child, grouped SMS-style into
/// conversation threads. App filter chips (All / WhatsApp / …) sit above the
/// inbox; tapping a thread opens its chat view.
class SocialNotificationsScreen extends ConsumerStatefulWidget {
  const SocialNotificationsScreen({super.key});

  @override
  ConsumerState<SocialNotificationsScreen> createState() =>
      _SocialNotificationsScreenState();
}

class _SocialNotificationsScreenState
    extends ConsumerState<SocialNotificationsScreen> {
  DayWindow _window = DayWindow.twoDays;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(selectedChildProvider).load();
      if (!mounted) return;
      final id = ref.read(selectedChildProvider).selectedId;
      if (id != null) {
        ref.read(childPermissionsProvider).ensureLoadedFor(id);
        await ref.read(socialNotificationViewModelProvider).load(id);
      }
    });
  }

  void _onChildSelected(String childId) {
    ref.read(socialNotificationViewModelProvider).load(childId);
    ref.read(childPermissionsProvider).load(childId);
  }

  void _onWindowChanged(DayWindow w) {
    setState(() => _window = w);
    // "All" has no day cap — send a wide window so the server returns everything.
    ref.read(socialNotificationViewModelProvider).setDays(w.days ?? 3650);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(socialNotificationViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            _TitleBar(
              total: vm.totalMessages,
              onChildSelected: _onChildSelected,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  DayWindowDropdown(
                    selected: _window,
                    enabled: !vm.loading,
                    onSelected: _onWindowChanged,
                  ),
                ],
              ),
            ),
            if (vm.apps.isNotEmpty)
              _AppFilterBar(
                apps: vm.apps,
                selected: vm.filterPackage,
                onSelected: (pkg) => ref
                    .read(socialNotificationViewModelProvider)
                    .setFilter(pkg),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    ref.read(socialNotificationViewModelProvider).refresh(),
                child: _buildContent(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SocialNotificationViewModel vm) {
    // Notification access is off on the child's device, so nothing is captured.
    final selectedChild = ref.watch(selectedChildProvider);
    final permsVm = ref.watch(childPermissionsProvider);
    if (permsVm.isDenied(
      selectedChild.selectedId,
      ChildFeature.notifications,
    )) {
      return PermissionDeniedBody(
        feature: ChildFeature.notifications,
        childName: selectedChild.selected?.name,
        refreshing: permsVm.loading,
        onRefresh: () =>
            ref.read(childPermissionsProvider).load(selectedChild.selectedId!),
      );
    }

    // Show the skeleton while (re)loading — first load or a day-window switch —
    // so the screen never looks frozen.
    if (vm.loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 32),
        child: ListShimmer(),
      );
    }

    final threads = vm.threadItems;
    if (threads.isEmpty) {
      return _EmptyView(error: vm.error);
    }

    return ListView.separated(
      // A key tied to the filter resets scroll position on switch.
      key: ValueKey(vm.filterPackage ?? '__all__'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      itemCount: threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ThreadRow(
        item: threads[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _ThreadChatView(item: threads[i])),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Title + shared child dropdown.
/// ----------------------------------------------------------------------------
class _TitleBar extends StatelessWidget {
  final int total;
  final ValueChanged<String> onChildSelected;

  const _TitleBar({required this.total, required this.onChildSelected});

  @override
  Widget build(BuildContext context) {
    final subtitle = total > 0
        ? '$total notification${total == 1 ? '' : 's'}'
        : 'Social app alerts';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChildSelectorDropdown(onChanged: onChildSelected),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Horizontal app filter chips: "All" + one per app (with its avatar + count).
/// ----------------------------------------------------------------------------
class _AppFilterBar extends StatelessWidget {
  final List<AppNotifications> apps;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _AppFilterBar({
    required this.apps,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final total = apps.fold<int>(0, (sum, a) => sum + a.count);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: apps.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterChip(
              label: 'All',
              count: total,
              active: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final app = apps[i - 1];
          return _FilterChip(
            label: app.app,
            count: app.count,
            active: selected == app.package,
            leading: AppIconAvatar(
              appName: app.app,
              packageName: app.package,
              size: 22,
            ),
            onTap: () => onSelected(app.package),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Widget? leading;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(left: leading != null ? 6 : 14, right: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 7)],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.scaffold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// A conversation row in the SMS-style inbox. Shows the app logo (so the mixed
/// "All" feed stays legible), the conversation name, last preview, and count.
/// ----------------------------------------------------------------------------
class _ThreadRow extends StatelessWidget {
  final NotificationThreadItem item;
  final VoidCallback onTap;

  const _ThreadRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final thread = item.thread;
    final color = AppIconAvatar.colorFor(item.app, item.package);
    final who = thread.conversation.isNotEmpty
        ? thread.conversation
        : 'Unknown';
    final preview = thread.lastPreview.isNotEmpty ? thread.lastPreview : '—';
    final isGroup = thread.messages.any((m) => m.isGroup);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              AppIconAvatar(
                appName: item.app,
                packageName: item.package,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isGroup) ...[
                          const Icon(
                            Icons.group_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            who,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(thread.lastTime),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CountBadge(count: thread.count, accent: color),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color accent;
  const _CountBadge({required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Chat view for a single notification thread.
/// ----------------------------------------------------------------------------
class _ThreadChatView extends StatelessWidget {
  final NotificationThreadItem item;

  const _ThreadChatView({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = AppIconAvatar.colorFor(item.app, item.package);
    final thread = item.thread;
    final who = thread.conversation.isNotEmpty
        ? thread.conversation
        : 'Unknown';

    final messages = [...thread.messages]
      ..sort((a, b) {
        final at = a.timestamp;
        final bt = b.timestamp;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            _ChatTitleBar(name: who, item: item, accent: color),
            Expanded(
              child: messages.isEmpty
                  ? const _EmptyView()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _MessageBubble(message: messages[i], accent: color),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTitleBar extends StatelessWidget {
  final String name;
  final NotificationThreadItem item;
  final Color accent;

  const _ChatTitleBar({
    required this.name,
    required this.item,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppIconAvatar(appName: item.app, packageName: item.package, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item.app,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// A single notification, rendered as an incoming bubble.
/// ----------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  final SocialMessage message;
  final Color accent;

  const _MessageBubble({required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
    // In group chats, name the actual sender above the body.
    final showSender = message.isGroup && message.sender.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.sender,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                Text(
                  message.body.isNotEmpty ? message.body : '—',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.32,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _relativeTime(message.timestamp),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

/// "now" / "5m" / "3h" / "Jun 30" — a compact relative timestamp.
String _relativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  const months = [
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
  return '${months[time.month - 1]} ${time.day}';
}

class _EmptyView extends StatelessWidget {
  final String? error;
  const _EmptyView({this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          error != null
              ? Icons.cloud_off_rounded
              : Icons.notifications_off_outlined,
          size: 52,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            error ?? 'No notifications captured yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
