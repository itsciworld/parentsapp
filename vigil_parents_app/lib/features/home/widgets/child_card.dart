import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';

/// The child header that sits on the dark gradient: avatar, name + "Online"
/// pill, device line, last-sync line, and the three status indicators.
class ChildHeaderCard extends StatelessWidget {
  final ChildProfile child;
  final List<StatusIndicator> indicators;

  /// Widget shown on the right of the header row. Defaults to the security
  /// shield; the Home screen passes the child picker dropdown here instead.
  final Widget? trailing;

  const ChildHeaderCard({
    super.key,
    required this.child,
    required this.indicators,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChildAvatar(isOnline: child.isOnline),
            const SizedBox(width: 12),
            Expanded(child: _ChildInfo(child: child)),
            const SizedBox(width: 8),
            trailing ?? const _SecurityShield(),
          ],
        ),
        const SizedBox(height: 22),
        _StatusRow(indicators: indicators),
      ],
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  final bool isOnline;

  const _ChildAvatar({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          // Static profile picture removed for now — use a simple account icon
          // sized to fill the ring.
          child: const Icon(
            Icons.account_circle,
            color: AppColors.textOnDarkMuted,
            size: 52,
          ),
        ),
        if (isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.headerBottom, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChildInfo extends StatelessWidget {
  final ChildProfile child;
  const _ChildInfo({required this.child});

  @override
  Widget build(BuildContext context) {
    // Device name + OS only — e.g. "Samsung Galaxy A52  •  Android 13".
    final deviceLine = [
      child.deviceModel,
      child.osVersion,
    ].where((s) => s.trim().isNotEmpty).join('  •  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          child.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (deviceLine.isNotEmpty) ...[
          const SizedBox(height: 5),
          _IconLine(icon: Icons.smartphone_rounded, text: deviceLine),
        ],
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textOnDarkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Decorative glowing lock shield on the right of the header.
class _SecurityShield extends StatelessWidget {
  const _SecurityShield();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B7FB0), Color(0xFF124B7A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B7FB0).withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final List<StatusIndicator> indicators;
  const _StatusRow({required this.indicators});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < indicators.length; i++) ...[
          Expanded(child: _StatusItem(indicator: indicators[i])),
          if (i != indicators.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  final StatusIndicator indicator;
  const _StatusItem({required this.indicator});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(indicator.icon, color: indicator.color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indicator.title,
                style: TextStyle(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                indicator.subtitle,
                style: TextStyle(
                  color: AppColors.textOnDarkMuted,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
