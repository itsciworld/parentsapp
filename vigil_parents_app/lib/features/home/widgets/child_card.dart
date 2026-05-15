import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/features/home/models/home_model.dart';
import 'package:vigil_parents_app/features/home/widgets/omman_widgets.dart';

/// The child header that sits on the dark gradient: avatar, name + "Online"
/// pill, device line, last-sync line, and the three status indicators.
class ChildHeaderCard extends StatelessWidget {
  final ChildProfile child;
  final List<StatusIndicator> indicators;

  const ChildHeaderCard({
    super.key,
    required this.child,
    required this.indicators,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChildAvatar(avatarUrl: child.avatarUrl, isOnline: child.isOnline),
            const SizedBox(width: 12),
            Expanded(child: _ChildInfo(child: child)),
            const SizedBox(width: 8),
            const _SecurityShield(),
          ],
        ),
        const SizedBox(height: 22),
        _StatusRow(indicators: indicators),
      ],
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  final String avatarUrl;
  final bool isOnline;

  const _ChildAvatar({required this.avatarUrl, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 70,
          height: 70,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2.5),
          ),
          child: ClipOval(
            child: Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              // Graceful fallback if the dummy network image fails to load.
              errorBuilder: (_, _, _) => Container(
                color: AppColors.primaryLight,
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.primaryLight,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.headerBottom, width: 2.5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                child.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            if (child.isOnline)
              const StatusPill(label: 'Online', color: AppColors.online),
          ],
        ),
        const SizedBox(height: 5),
        _IconLine(
          icon: Icons.smartphone_rounded,
          text: '${child.deviceModel}  •  ${child.osVersion}',
        ),
        const SizedBox(height: 4),
        _IconLine(
          icon: Icons.sync_rounded,
          text: 'Last Sync: ${child.lastSync}',
        ),
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
