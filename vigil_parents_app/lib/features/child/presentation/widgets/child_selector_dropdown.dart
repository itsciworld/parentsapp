import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/child/presentation/view_model/selected_child_viewmodel.dart';

/// A "select a child" picker reused on the Home and SMS screens.
///
/// It reads the shared [selectedChildProvider], and on every tap re-fetches
/// the children list from the API before opening the menu — so additions or
/// deletions made elsewhere (e.g. the Children screen) are always reflected.
///
/// Pass [dark] = true on the dark gradient header, and [showLabel] = false to
/// render only a dropdown arrow (the menu still lists the child names).
class ChildSelectorDropdown extends ConsumerWidget {
  final ValueChanged<String> onChanged;
  final bool dark;
  final bool showLabel;

  const ChildSelectorDropdown({
    super.key,
    required this.onChanged,
    this.dark = false,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(selectedChildProvider);
    if (vm.children.isEmpty) {
      // Until the first /api/children call completes, show a shimmer in place
      // of the dropdown instead of letting it pop in abruptly.
      if (!vm.initialized) return _buildShimmer();
      return const SizedBox.shrink();
    }

    final Color fg = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final Color bg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.surface;
    final Color border = dark
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.cardBorder;

    final selectedName = vm.selected?.name.trim();
    final label = (selectedName == null || selectedName.isEmpty)
        ? 'Select child'
        : selectedName;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _open(context, ref),
        child: Container(
          padding: showLabel
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: showLabel
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_circle_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Child',
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.55),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ],
                )
              : Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: fg),
        ),
      ),
    );
  }

  /// Loading placeholder shown until the children list is first fetched.
  Widget _buildShimmer() {
    final base = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.grey.shade300;
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: showLabel ? double.infinity : 40,
        height: showLabel ? 46 : 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Opens the menu *immediately* with the current list, then kicks off a
  /// background refresh. The menu itself ([_ChildMenuOverlay]) watches the
  /// provider, so it shows a loading bar while fetching and updates live when
  /// the new data arrives — without delaying the open.
  void _open(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedChildProvider);

    final box = context.findRenderObject() as RenderBox?;
    final overlayState = Overlay.of(context);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);

    late final OverlayEntry entry;
    void close() => entry.remove();

    entry = OverlayEntry(
      builder: (_) => _ChildMenuOverlay(
        anchorTopLeft: anchorTopLeft,
        anchorSize: box.size,
        overlaySize: overlayBox.size,
        dark: dark,
        onClose: close,
        onPick: (id) async {
          close();
          final changed = await notifier.select(id);
          if (changed) onChanged(id);
        },
      ),
    );

    overlayState.insert(entry);

    // Refresh in the background. The overlay updates live as the list changes;
    // if the selected child was deleted, [load] reselects a valid one and we
    // notify the caller so its dependent data refreshes.
    final prevId = notifier.selectedId;
    notifier.load(force: true).then((_) {
      if (notifier.selectedId != null && notifier.selectedId != prevId) {
        onChanged(notifier.selectedId!);
      }
    });
  }
}

/// The live dropdown menu rendered in the [Overlay]. It watches
/// [selectedChildProvider] so it reflects loading state and list changes
/// while open.
class _ChildMenuOverlay extends ConsumerWidget {
  final Offset anchorTopLeft;
  final Size anchorSize;
  final Size overlaySize;
  final bool dark;
  final VoidCallback onClose;
  final ValueChanged<String> onPick;

  const _ChildMenuOverlay({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.overlaySize,
    required this.dark,
    required this.onClose,
    required this.onPick,
  });

  static const double _menuWidth = 220;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(selectedChildProvider);

    // Anchor the menu under the trigger, aligned to its right edge, clamped
    // to stay on screen.
    double left = anchorTopLeft.dx + anchorSize.width - _menuWidth;
    left = left.clamp(8.0, (overlaySize.width - _menuWidth - 8).clamp(8.0, double.infinity));
    final double top = anchorTopLeft.dy + anchorSize.height + 6;

    final Color fg = dark ? AppColors.textOnDark : AppColors.textPrimary;

    return Stack(
      children: [
        // Tap-outside barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: Material(
            color: dark ? AppColors.headerBottom : AppColors.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thin loading bar while the background refresh is in flight.
                if (vm.loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: Colors.transparent,
                  ),
                Flexible(
                  child: vm.children.isEmpty
                      ? _emptyRow(vm.loading, fg)
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          children: [
                            for (final c in vm.children)
                              _ChildRow(
                                name: c.name.isEmpty ? 'Unnamed child' : c.name,
                                selected: c.id == vm.selectedId,
                                fg: fg,
                                onTap: () => onPick(c.id),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyRow(bool loading, Color fg) {
    // While the first fetch is in flight, show shimmer placeholder rows so the
    // menu feels alive the instant it opens.
    if (loading) {
      final base = dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.grey.shade300;
      final highlight = dark
          ? Colors.white.withValues(alpha: 0.28)
          : Colors.grey.shade100;

      return Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Text(
        'No children found',
        style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 14),
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  final String name;
  final bool selected;
  final Color fg;
  final VoidCallback onTap;

  const _ChildRow({
    required this.name,
    required this.selected,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
