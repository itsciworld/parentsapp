import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/components/app_shimmer.dart';
import 'package:vigil_parents_app/components/day_window_selector.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/app_usage/presentation/widgets/app_icon_avatar.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';
import 'package:vigil_parents_app/features/child/presentation/widgets/child_selector_dropdown.dart';
import 'package:vigil_parents_app/features/social_apps/models/social_screen_model.dart';
import 'package:vigil_parents_app/features/social_apps/presentation/view_model/social_screen_viewmodel.dart';

/// Captured chat messages from the child's social apps. An app selector
/// (WhatsApp / Instagram / …) sits above an SMS-style inbox of conversation
/// threads; tapping a thread opens its chat view.
class SocialScreenView extends ConsumerStatefulWidget {
  const SocialScreenView({super.key});

  @override
  ConsumerState<SocialScreenView> createState() => _SocialScreenViewState();
}

class _SocialScreenViewState extends ConsumerState<SocialScreenView> {
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
        await ref.read(socialScreenViewModelProvider).load(id);
      }
    });
  }

  void _onChildSelected(String childId) {
    ref.read(socialScreenViewModelProvider).load(childId);
  }

  void _onWindowChanged(DayWindow w) {
    setState(() => _window = w);
    // "All" has no day cap — send a wide window so the server returns everything.
    ref.read(socialScreenViewModelProvider).setDays(w.days ?? 3650);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(socialScreenViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(),
            _TitleBar(total: vm.totalMessages, onChildSelected: _onChildSelected),
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
              _AppSelector(
                apps: vm.apps,
                selected: vm.selectedPackage,
                onSelected: (pkg) =>
                    ref.read(socialScreenViewModelProvider).select(pkg),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    ref.read(socialScreenViewModelProvider).refresh(),
                child: _buildContent(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SocialScreenViewModel vm) {
    // Show the skeleton while (re)loading — first load or a day-window switch —
    // so the screen never looks frozen.
    if (vm.loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: ListShimmer(),
      );
    }

    final app = vm.selectedApp;
    if (app == null) {
      return _EmptyView(error: vm.error);
    }

    final threads = vm.threads;
    if (threads.isEmpty) {
      return _EmptyView(error: vm.error, appName: app.app);
    }

    final color = AppIconAvatar.colorFor(app.app, app.package);

    return ListView.separated(
      // Reset scroll position whenever the selected app changes.
      key: ValueKey(app.package),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ThreadRow(
        thread: threads[i],
        accent: color,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ThreadChatView(
              appName: app.app,
              package: app.package,
              thread: threads[i],
            ),
          ),
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
        ? '$total message${total == 1 ? '' : 's'} captured'
        : 'Captured chat messages';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Social Apps',
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
/// Horizontal app selector: one chip per app (avatar + name + count).
/// ----------------------------------------------------------------------------
class _AppSelector extends StatelessWidget {
  final List<SocialAppMessages> apps;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _AppSelector({
    required this.apps,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: apps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final app = apps[i];
          final active = app.package == selected;
          final color = AppIconAvatar.colorFor(app.app, app.package);
          return GestureDetector(
            onTap: () => onSelected(app.package),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.only(left: 6, right: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.12) : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: active ? color : AppColors.cardBorder,
                  width: active ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconAvatar(
                    appName: app.app,
                    packageName: app.package,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    app.app,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? color : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? color.withValues(alpha: 0.18)
                          : AppColors.scaffold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${app.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active ? color : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// A conversation row in the SMS-style inbox.
/// ----------------------------------------------------------------------------
class _ThreadRow extends StatelessWidget {
  final ScreenThread thread;
  final Color accent;
  final VoidCallback onTap;

  const _ThreadRow({
    required this.thread,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final who = thread.conversation.isNotEmpty ? thread.conversation : 'Unknown';
    final preview = thread.lastPreview.isNotEmpty ? thread.lastPreview : '—';

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
              _ConversationAvatar(name: who, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                        _CountBadge(count: thread.count, accent: accent),
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

class _ConversationAvatar extends StatelessWidget {
  final String name;
  final Color accent;
  final double size;
  const _ConversationAvatar({
    required this.name,
    required this.accent,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
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
/// Chat view for a single conversation thread.
/// ----------------------------------------------------------------------------
class _ThreadChatView extends StatelessWidget {
  final String appName;
  final String package;
  final ScreenThread thread;

  const _ThreadChatView({
    required this.appName,
    required this.package,
    required this.thread,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppIconAvatar.colorFor(appName, package);
    final who = thread.conversation.isNotEmpty ? thread.conversation : 'Unknown';

    final messages = [...thread.messages]..sort((a, b) {
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
            _ChatTitleBar(name: who, appName: appName, accent: color),
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
  final String appName;
  final Color accent;

  const _ChatTitleBar({
    required this.name,
    required this.appName,
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
          _ConversationAvatar(name: name, accent: accent, size: 38),
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
                  appName,
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
/// A single chat message, rendered as an incoming bubble.
/// ----------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  final ScreenMessage message;
  final Color accent;

  const _MessageBubble({required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  message.text.isNotEmpty ? message.text : '—',
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[time.month - 1]} ${time.day}';
}

class _EmptyView extends StatelessWidget {
  final String? error;
  final String? appName;
  const _EmptyView({this.error, this.appName});

  @override
  Widget build(BuildContext context) {
    final label = error ??
        (appName != null
            ? 'No messages captured from $appName yet'
            : 'No social messages captured yet');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          error != null ? Icons.cloud_off_rounded : Icons.forum_outlined,
          size: 52,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            label,
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
