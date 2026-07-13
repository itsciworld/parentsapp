import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// A look-back time window, selectable from a row of chips. Used to filter
/// time-stamped lists (Calls, SMS) to a recent range. Mirrors the "Last 3h /
/// 6h …" chips on the Location History screen, but measured in days.
enum DayWindow {
  twoDays(2, 'Last 2 days'),
  threeDays(3, 'Last 3 days'),
  fiveDays(5, 'Last 5 days'),
  all(null, 'All');

  const DayWindow(this.days, this.label);

  /// Number of days the window spans, or `null` for "no limit" (All).
  final int? days;

  /// The chip label.
  final String label;

  /// Whether [date] falls inside this window. "All" always includes; any other
  /// window excludes entries with no date (they can't be placed in time).
  bool includes(DateTime? date) {
    if (days == null) return true;
    if (date == null) return false;
    final cutoff = DateTime.now().subtract(Duration(days: days!));
    return date.isAfter(cutoff);
  }
}

/// A compact pill dropdown for picking a [DayWindow]. A space-saving
/// alternative to [DayWindowSelector] when a full chip row doesn't fit.
class DayWindowDropdown extends StatelessWidget {
  final DayWindow selected;
  final bool enabled;
  final ValueChanged<DayWindow> onSelected;

  const DayWindowDropdown({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: PopupMenuButton<DayWindow>(
        enabled: enabled,
        initialValue: selected,
        tooltip: 'History window',
        position: PopupMenuPosition.under,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final w in DayWindow.values)
            PopupMenuItem<DayWindow>(
              value: w,
              child: Row(
                children: [
                  Icon(
                    w == selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: w == selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    w.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: w == selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                selected.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of [DayWindow] chips. Pass the active window and a callback;
/// the active chip is filled in the brand color, the rest outlined.
class DayWindowSelector extends StatelessWidget {
  final DayWindow selected;
  final bool enabled;
  final ValueChanged<DayWindow> onSelected;

  const DayWindowSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: DayWindow.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final w = DayWindow.values[i];
          final active = w == selected;
          return GestureDetector(
            onTap: enabled && !active ? () => onSelected(w) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              // Same padding/border width in both states so the chip never
              // changes size when selected — only its colors animate.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.headerBottom : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.headerBottom : AppColors.cardBorder,
                ),
              ),
              child: Text(
                w.label,
                style: TextStyle(
                  fontSize: 12.5,
                  // Keep weight identical across states so the text width — and
                  // thus the chip width — stays constant.
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
