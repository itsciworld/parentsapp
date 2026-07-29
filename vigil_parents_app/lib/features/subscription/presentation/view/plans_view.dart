import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil_parents_app/components/app_header.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';
import 'package:vigil_parents_app/core/apptost/app_tost.dart';
import 'package:vigil_parents_app/features/profile/presentation/view_model/profile_viewmodel.dart';
import 'package:vigil_parents_app/features/subscription/models/subscription_model.dart';
import 'package:vigil_parents_app/features/subscription/presentation/view/checkout_webview.dart';
import 'package:vigil_parents_app/features/subscription/presentation/view_model/subscription_viewmodel.dart';

/// Full-screen plan catalogue. Lists every plan from
/// `GET /api/subscriptions/plans`, shows the parent's current status, and drives
/// the Stripe purchase for paid plans through an in-app checkout.
class PlansView extends ConsumerStatefulWidget {
  const PlansView({super.key});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(subscriptionViewModelProvider).load();
      // Ensure we have the parent's name/email for the checkout call.
      final profileVm = ref.read(profileViewModelProvider);
      if (profileVm.profile == null) profileVm.loadProfile(showLoader: false);
    });
  }

  Future<void> _onChoosePlan(SubscriptionPlan plan) async {
    final vm = ref.read(subscriptionViewModelProvider);
    if (vm.isCheckingOut) return;

    // Resolve the buyer's identity — required by /payments/initiate.
    var profile = ref.read(profileViewModelProvider).profile;
    if (profile == null) {
      await ref.read(profileViewModelProvider).loadProfile(showLoader: false);
      profile = ref.read(profileViewModelProvider).profile;
    }
    if (!mounted) return;

    if (profile == null || profile.email.trim().isEmpty) {
      showAppToast(
        context: context,
        title: 'Profile needed',
        subtitle: 'We couldn\'t read your account email. Please try again.',
        type: ToastType.error,
      );
      return;
    }

    CheckoutSession session;
    try {
      session = await vm.startCheckout(
        plan: plan,
        email: profile.email,
        name: profile.name,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Could not start checkout',
        subtitle: e.toString().replaceAll('Exception: ', ''),
        type: ToastType.error,
      );
      return;
    }

    if (!mounted) return;

    // Open Stripe Checkout inside the app. The WebView watches for the redirect
    // away from Stripe's hosted page (Stripe's success/cancel URLs point back at
    // our own return URLs) and closes itself with a result, so the parent lands
    // straight back in the app instead of being stranded on the success page in
    // an external browser. The webhook is still the real source of truth, so we
    // reconcile from /subscriptions/my whenever they return from a completed or
    // ambiguous flow. (CheckoutWebView keeps an "open in browser" escape hatch
    // for the rare device where Stripe renders blank inside a WebView.)
    debugPrint('🧾 Checkout: opening IN-APP WebView → ${session.url}');
    final result = await Navigator.of(context).push<CheckoutResult>(
      MaterialPageRoute(
        builder: (_) => CheckoutWebView(url: session.url, planName: plan.name),
      ),
    );
    debugPrint('🧾 Checkout: WebView closed with result → $result');
    if (!mounted) return;

    switch (result) {
      case CheckoutResult.success:
      case CheckoutResult.returned:
        // Paid, or left Stripe for a page we couldn't classify — either way the
        // reconcile call decides from the server whether the plan went live.
        await _reconcileAfterCheckout(plan);
      case CheckoutResult.canceled:
      case CheckoutResult.closed:
        showAppToast(
          context: context,
          title: 'Checkout canceled',
          subtitle: 'You can pick a plan whenever you\'re ready.',
          type: ToastType.info,
        );
      case null:
        // Route popped without a result (e.g. system back) — nothing to do.
        break;
    }
  }

  /// Re-reads the subscription after the parent leaves checkout and tells them
  /// whether the plan went live. The webhook is the real source of truth, so
  /// activation can lag a moment behind a completed payment.
  Future<void> _reconcileAfterCheckout(SubscriptionPlan plan) async {
    final vm = ref.read(subscriptionViewModelProvider);
    await vm.refreshMySubscription();
    if (!mounted) return;

    final nowActive = vm.mySubscription.isPaid ||
        vm.isCurrentPlan(plan) && !vm.mySubscription.inTrial;

    if (nowActive) {
      showAppToast(
        context: context,
        title: 'Payment successful',
        subtitle: '${plan.name} is now active.',
        type: ToastType.success,
      );
    } else {
      showAppToast(
        context: context,
        title: 'Finishing up',
        subtitle:
            'If you completed payment, activation can take a few seconds. '
            'Pull to refresh.',
        type: ToastType.info,
      );
    }
  }

  Future<void> _confirmCancel(SubscriptionPlan plan) async {
    final vm = ref.read(subscriptionViewModelProvider);
    if (vm.isCanceling) return;

    final inTrial = vm.mySubscription.inTrial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate plan?'),
        content: Text(
          inTrial
              ? 'This turns off auto-renew for your trial. You '
                  'keep access until the trial ends, after which it will not '
                  'convert to a paid plan.'
              : 'This turns off auto-renew for ${plan.name}. You keep access '
                  'until the end of your current billing period, after which '
                  'the plan will not renew.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await vm.cancelSubscription();
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Auto-renew turned off',
        subtitle: 'Your plan won\'t renew after the current period.',
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context: context,
        title: 'Could not deactivate',
        subtitle: e.toString().replaceAll('Exception: ', ''),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(subscriptionViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(showBack: true),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => vm.refresh(),
                child: _buildBody(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SubscriptionViewModel vm) {
    if (vm.isLoading && vm.plans.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.hasError && vm.plans.isEmpty) {
      return _ErrorState(
        message: vm.errorMessage ?? 'Something went wrong',
        onRetry: () => vm.load(),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        const _PlansIntro(),
        if (vm.mySubscription.hasSubscription) ...[
          const SizedBox(height: 14),
          _CurrentStatusBanner(sub: vm.mySubscription),
        ],
        const SizedBox(height: 18),
        for (final plan in vm.plans) ...[
          _PlanCard(
            plan: plan,
            // The trial card is purely informational — it never takes the
            // "current plan" treatment, even while the trial is the active
            // subscription. Deactivate lives on the paid (enterprise) plan.
            isCurrent: vm.isCurrentPlan(plan) && !plan.isTrial,
            // On the top plan there's nothing to buy — lock every CTA.
            onTopPlan: vm.isOnTopPlan,
            checkingOut: vm.checkoutPlanId == plan.id,
            anyCheckoutInFlight: vm.isCheckingOut,
            // Deactivate is offered on the active paid plan (enterprise) if there
            // is any active subscription (including the trial subscription).
            canCancel: !plan.isTrial &&
                vm.mySubscription.hasSubscription &&
                (vm.isCurrentPlan(plan) || vm.mySubscription.inTrial),
            canceling: vm.isCanceling,
            onChoose: () => _onChoosePlan(plan),
            onCancel: () => _confirmCancel(plan),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
        const _SecureNote(),
      ],
    );
  }
}

class _PlansIntro extends StatelessWidget {
  const _PlansIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // VIGIL brand logo
        Image.asset(
          AppImages.logo1,
          height: 64,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox(height: 8),
        ),
        const SizedBox(height: 14),
        const Text(
          'Choose your plan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unlock more monitoring and protect more children.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// A slim banner summarising the active subscription (plan + time left).
class _CurrentStatusBanner extends StatelessWidget {
  final MySubscription sub;
  const _CurrentStatusBanner({required this.sub});

  @override
  Widget build(BuildContext context) {
    final planLabel = sub.planName.isEmpty ? 'Active plan' : sub.planName;
    final days = sub.inTrial ? sub.trialDaysRemaining : sub.daysRemaining;
    final subtitle = sub.inTrial
        ? 'Trial • $days days remaining'
        : days > 0
        ? '$days days remaining'
        : 'Active';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: $planLabel',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
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

/// A single plan option with price, capacity, feature list, and CTA.
class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool onTopPlan;
  final bool checkingOut;
  final bool anyCheckoutInFlight;
  final bool canCancel;
  final bool canceling;
  final VoidCallback onChoose;
  final VoidCallback onCancel;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onTopPlan,
    required this.checkingOut,
    required this.anyCheckoutInFlight,
    required this.canCancel,
    required this.canceling,
    required this.onChoose,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = !plan.isFree; // the paid plan gets the accent treatment
    final features = plan.features.detailedItems;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.shadow,
            blurRadius: highlight ? 20 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: name + badge ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isCurrent)
                const _Tag(text: 'CURRENT', color: AppColors.primary)
              else if (highlight)
                const _Tag(text: 'BEST VALUE', color: AppColors.blueIcon),
            ],
          ),
          const SizedBox(height: 8),
          // ── Price ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.isFree ? 'Free' : _priceLabel(plan),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (!plan.isFree) ...[
                const SizedBox(width: 4),
                const Text(
                  '/month',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // ── Capacity + description ──────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.family_restroom_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                plan.maxChildren == 1
                    ? 'Up to 1 child'
                    : 'Up to ${plan.maxChildren} children',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (plan.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.description.trim(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 12),
          // ── Feature list ────────────────────────────────────────
          for (final f in features) ...[
            _FeatureRow(item: f),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          // ── CTA ─────────────────────────────────────────────────
          _buildCta(),
        ],
      ),
    );
  }

  Widget _buildCta() {
    if (isCurrent) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Your Current Plan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          // Explicit deactivate option for the active paid plan.
          if (canCancel) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canceling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.alert,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: AppColors.alert.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: canceling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.alert,
                        ),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(
                  canceling ? 'Deactivating…' : 'Deactivate ${plan.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Free/trial plans can't be bought through Stripe — present them as
    // informational rather than offering a checkout that would fail.
    if (plan.isFree) {
      return const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Included by default',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    // Already on the highest tier: nothing above this to buy, so the CTA is
    // shown disabled rather than offering an upgrade that can't happen.
    final blocked = onTopPlan;

    final ctaButton = ElevatedButton(
      // Disabled when: already on the top plan, or another card's checkout
      // is in flight.
      onPressed: (blocked || (anyCheckoutInFlight && !checkingOut))
          ? null
          : onChoose,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: blocked
            ? AppColors.cardBorder
            : AppColors.primary.withValues(alpha: 0.5),
        disabledForegroundColor: blocked ? AppColors.textSecondary : null,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: checkingOut
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              blocked ? "You're on the top plan" : 'Upgrade Now',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    if (canCancel) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ctaButton,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canceling ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.alert,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: AppColors.alert.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: canceling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.alert,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined, size: 18),
              label: Text(
                canceling ? 'Deactivating…' : 'Deactivate ${plan.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ctaButton,
    );
  }

  String _priceLabel(SubscriptionPlan plan) {
    final symbol = plan.currency.toUpperCase() == 'USD' ? '\$' : '';
    final value = plan.price == plan.price.roundToDouble()
        ? plan.price.toStringAsFixed(0)
        : plan.price.toStringAsFixed(2);
    return '$symbol$value';
  }
}

class _FeatureRow extends StatelessWidget {
  final PlanFeatureItem item;
  const _FeatureRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final on = item.enabled;
    final color = on ? AppColors.primary : AppColors.textSecondary;
    return Row(
      children: [
        Icon(
          on ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          size: 18,
          color: on ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.textPrimary : AppColors.textSecondary,
              decoration: on ? null : TextDecoration.lineThrough,
              decorationColor: AppColors.textSecondary,
            ),
          ),
        ),
        Icon(item.icon, size: 16, color: color.withValues(alpha: 0.7)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.lock_rounded, size: 13, color: AppColors.textSecondary),
        SizedBox(width: 6),
        Text(
          'Secure payment powered by Stripe',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.alert),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Unable to load plans',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ),
      ],
    );
  }
}
