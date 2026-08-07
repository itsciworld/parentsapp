import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/routing/routes.dart';
import 'package:vigil_parents_app/features/subscription/models/subscription_model.dart';
import 'package:vigil_parents_app/features/subscription/presentation/view_model/subscription_viewmodel.dart';

/// Home-screen card that replaces the old foundation footer. It shows what the
/// parent unlocks by upgrading — features they don't have yet are marked with a
/// lock — and routes to the full plans screen. Once on a paid plan it collapses
/// to a slim "all unlocked" confirmation instead of upselling.
class UpgradePlanCard extends ConsumerStatefulWidget {
  const UpgradePlanCard({super.key});

  @override
  ConsumerState<UpgradePlanCard> createState() => _UpgradePlanCardState();
}

class _UpgradePlanCardState extends ConsumerState<UpgradePlanCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final vm = ref.read(subscriptionViewModelProvider);
      // Only fetch if we don't already have data (e.g. from the plans screen).
      if (vm.plans.isEmpty && !vm.isLoading) vm.load(showLoader: false);
    });
  }

  void _openPlans() {
    Navigator.of(context).pushNamed(AppRoutesName.plansView).then((_) {
      if (mounted) ref.read(subscriptionViewModelProvider).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(subscriptionViewModelProvider);

    // Don't render an empty shell before the first load lands.
    if (vm.plans.isEmpty && vm.isLoading) {
      return const _LoadingCard();
    }
    if (vm.plans.isEmpty) return const SizedBox.shrink();

    // The "target" plan is the richest paid one — its feature set defines
    // everything that can be unlocked.
    final paidPlans = vm.plans.where((p) => !p.isFree).toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    final targetPlan = paidPlans.isNotEmpty ? paidPlans.first : null;

    // What the parent has right now: their current plan's flags, or — before
    // any subscription — the free/trial plan's flags.
    final currentFeatures =
        vm.mySubscription.currentFeatures ??
        vm.plans
            .firstWhere((p) => p.isFree, orElse: () => vm.plans.first)
            .features;

    final items = PlanFeatures.catalogue(enabledIn: currentFeatures);
    final lockedCount = items.where((i) => !i.enabled).length;

    // On the top plan there's nothing to upsell — the home screen hides this
    // whole section, but guard here too in case the card is used standalone.
    if (vm.isOnTopPlan || (vm.mySubscription.isPaid && lockedCount == 0)) {
      return const SizedBox.shrink();
    }

    return _UpsellCard(
      items: items,
      lockedCount: lockedCount,
      inTrial: vm.mySubscription.inTrial || !vm.mySubscription.hasSubscription,
      planName: vm.mySubscription.hasSubscription
          ? vm.mySubscription.planName
          : 'Free',
      priceLabel: targetPlan != null ? _priceLabel(targetPlan) : null,
      onUpgrade: _openPlans,
    );
  }

  String _priceLabel(SubscriptionPlan plan) {
    final symbol = plan.currency.toUpperCase() == 'USD' ? '\$' : '';
    final value = plan.price == plan.price.roundToDouble()
        ? plan.price.toStringAsFixed(0)
        : plan.price.toStringAsFixed(2);
    return '$symbol$value/mo';
  }
}

class _UpsellCard extends StatelessWidget {
  final List<PlanFeatureItem> items;
  final int lockedCount;
  final bool inTrial;
  final String planName;
  final String? priceLabel;
  final VoidCallback onUpgrade;

  const _UpsellCard({
    required this.items,
    required this.lockedCount,
    required this.inTrial,
    required this.planName,
    required this.priceLabel,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2240), Color(0xFF123A63)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerTop.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unlock Everything',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lockedCount > 0
                          ? "You're on $planName • $lockedCount features locked"
                          : "You're on $planName",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Feature chips ───────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in items) _FeatureChip(item: item)],
          ),
          const SizedBox(height: 18),
          // ── CTA ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    priceLabel != null
                        ? 'Upgrade Plan • $priceLabel'
                        : 'Upgrade Plan',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final PlanFeatureItem item;
  const _FeatureChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final on = item.enabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: on
            ? AppColors.primary.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: on
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.check_rounded : Icons.lock_rounded,
            size: 13,
            color: on ? AppColors.primary : AppColors.textOnDarkMuted,
          ),
          const SizedBox(width: 5),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : AppColors.textOnDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
