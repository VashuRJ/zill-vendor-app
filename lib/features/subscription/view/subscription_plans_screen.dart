import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/app_logger.dart';
import '../models/subscription_models.dart';
import '../services/razorpay_subscription_service.dart';
import '../viewmodel/subscription_viewmodel.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final _razorpayService = RazorpaySubscriptionService();

  RazorpayOrderData? _pendingOrder;

  @override
  void initState() {
    super.initState();
    _razorpayService.initialize(
      onSuccess: _onPaymentSuccess,
      onError: _onPaymentError,
      onWallet: _onExternalWallet,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionViewModel>().fetchPlans();
    });
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  // ── Razorpay callbacks ────────────────────────────────────────────────

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    final vm = context.read<SubscriptionViewModel>();
    final order = _pendingOrder ?? _razorpayService.currentOrder;
    if (order == null ||
        response.orderId == null ||
        response.paymentId == null) {
      vm.resetStatus();
      _showSnackBar('Payment data incomplete', isError: true);
      return;
    }
    final ok = await vm.verifyPayment(
      invoiceId: order.invoiceId,
      razorpayPaymentId: response.paymentId!,
      razorpaySignature: response.signature ?? '',
    );
    if (!mounted) return;
    if (ok) {
      _showSnackBar('Subscription activated!');
      Navigator.of(context).pop(true);
    } else {
      _showSnackBar(vm.errorMessage ?? 'Verification failed', isError: true);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    AppLogger.e('Payment failed: ${response.code} - ${response.message}');
    context.read<SubscriptionViewModel>().resetStatus();
    _showSnackBar(response.message ?? 'Payment failed', isError: true);
  }

  Future<void> _retryVerification() async {
    final vm = context.read<SubscriptionViewModel>();
    final ok = await vm.retryVerification();
    if (!mounted) return;
    if (ok) {
      _showSnackBar('Subscription activated!');
      Navigator.of(context).pop(true);
    } else {
      _showSnackBar(
        vm.errorMessage ?? 'Verification failed. Try again.',
        isError: true,
      );
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnackBar('External wallet selected: ${response.walletName}');
  }

  // ── Subscribe action ──────────────────────────────────────────────────

  Future<void> _handleSubscribe(SubscriptionPlan plan) async {
    final vm = context.read<SubscriptionViewModel>();
    // Backend expects integer PK, not string plan_id
    final orderData = await vm.initiateSubscribe(plan.id);

    if (!mounted) return;

    // Trial started — no payment needed
    if (orderData == null && vm.errorMessage == null) {
      _showSnackBar('Trial started! Enjoy ${plan.name}.');
      Navigator.of(context).pop(true);
      return;
    }

    if (orderData == null) {
      if (vm.errorMessage != null) {
        _showSnackBar(vm.errorMessage!, isError: true);
      }
      return;
    }

    // Open Razorpay checkout — use key_id from backend response
    _pendingOrder = orderData;
    _razorpayService.openCheckout(
      orderData: orderData,
      vendorName: 'Vendor',
      vendorEmail: '',
      vendorPhone: '',
      razorpayKey: orderData.keyId,
      themeColor: AppColors.primary,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.plans.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (vm.status == SubscriptionStatus.error && vm.plans.isEmpty) {
            return _buildError(vm);
          }
          return _buildContent(vm);
        },
      ),
    );
  }

  Widget _buildError(SubscriptionViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: AppSizes.md),
            Text(
              vm.errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            ElevatedButton.icon(
              onPressed: vm.fetchPlans,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SubscriptionViewModel vm) {
    return Column(
      children: [
        // ── Verification recovery banner (network-drop) ─────────────
        if (vm.hasPendingVerification && vm.status == SubscriptionStatus.error)
          MaterialBanner(
            padding: const EdgeInsets.all(AppSizes.sm),
            backgroundColor: AppColors.warning.withAlpha(20),
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
            ),
            content: const Text(
              'Payment was received but verification failed. Tap to retry.',
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: vm.isVerifying ? null : _retryVerification,
                child: vm.isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text('Retry Verification'),
              ),
            ],
          ),

        // ── Billing cycle toggle ────────────────────────────────────
        _buildBillingToggle(vm),

        // ── Plans list (or empty-state if nothing came back) ────────
        // The fetch can resolve to `loaded` with an empty list — e.g.
        // a transient backend hiccup, no active plans seeded, or a
        // shape change that quietly produced zero rows. Without a
        // dedicated empty branch the screen used to render just the
        // toggle on a blank canvas, leaving the vendor with no path
        // forward (and no Retry).
        Expanded(
          child: vm.plans.isEmpty
              ? _buildEmptyPlans(vm)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.md,
                    AppSizes.sm,
                    AppSizes.md,
                    AppSizes.xxl,
                  ),
                  itemCount: vm.plans.length,
                  itemBuilder: (context, index) {
                    final plan = vm.plans[index];
                    final isCurrentPlan =
                        vm.mySubscription?.planId == plan.planId;
                    final isMostPopular = _isMostPopularPlan(plan);
                    // Only spin the tapped card; other cards stay
                    // visible but get their buttons disabled via
                    // `anyPlanSubscribing` so the user can't start a
                    // second subscribe while one is in-flight (the
                    // VM's double-tap guard would reject it anyway,
                    // but we want that visually clear).
                    return _PlanCard(
                      plan: plan,
                      isAnnual: vm.showAnnual,
                      isCurrentPlan: isCurrentPlan,
                      isMostPopular: isMostPopular,
                      isSubscribingThisPlan: vm.isSubscribingPlan(plan.id),
                      anyPlanSubscribing: vm.isSubscribing,
                      onSubscribe: () => _handleSubscribe(plan),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Empty state for `_buildContent`.
  ///
  /// Subscription is the last gate in the onboarding flow, but admin
  /// occasionally pulls plans offline (price changes, cleanup, GST
  /// re-config). Without an escape hatch the vendor is dead-stuck on
  /// this screen — KYC done, can't reach the dashboard, can't take
  /// orders. So when plans come back empty we expose:
  ///   • Primary CTA → "Continue to dashboard" (skip the gate; they
  ///     can subscribe later from Profile once admin re-enables plans)
  ///   • Secondary  → "Retry" (cheap re-fetch in case it was a hiccup)
  Widget _buildEmptyPlans(SubscriptionViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSizes.md),
            const Text(
              'No subscription plans right now',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontLg,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'You can continue to your dashboard and subscribe later '
              'from Profile when plans are available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _continueWithoutSubscription(),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continue to dashboard'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.md,
                  ),
                  textStyle: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            TextButton.icon(
              onPressed: vm.isLoading ? null : vm.fetchPlans,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(vm.isLoading ? 'Loading…' : 'Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skip the subscription gate when plans are unavailable. Routes
  /// straight to /home with `pushNamedAndRemoveUntil` so the back
  /// stack doesn't keep stale onboarding screens around — once the
  /// vendor lands on the dashboard, swipe-back should not pop them
  /// back into the empty plans page.
  void _continueWithoutSubscription() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  String? _maxSavingsBadge(SubscriptionViewModel vm) {
    final maxSavings = vm.plans
        .map((p) => p.savingsPercent ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    return maxSavings > 0 ? 'Save up to $maxSavings%' : null;
  }

  bool _isMostPopularPlan(SubscriptionPlan plan) {
    final lowerName = plan.name.toLowerCase();
    return plan.isRecommended || lowerName.contains('premium');
  }

  Widget _buildBillingToggle(SubscriptionViewModel vm) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.xs,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ToggleButton(
                label: 'Monthly',
                isSelected: !vm.showAnnual,
                onTap: () {
                  if (vm.showAnnual) vm.toggleBillingCycle();
                },
              ),
            ),
            Expanded(
              child: _ToggleButton(
                label: 'Annual',
                badge: _maxSavingsBadge(vm),
                isSelected: vm.showAnnual,
                onTap: () {
                  if (!vm.showAnnual) vm.toggleBillingCycle();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Toggle button
// ═══════════════════════════════════════════════════════════════════════════

class _ToggleButton extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 2),
              Text(
                badge!,
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.textOnPrimary.withAlpha(200)
                      : AppColors.success,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Plan card
// ═══════════════════════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isAnnual;
  final bool isCurrentPlan;
  final bool isMostPopular;
  /// True only when THIS plan is the one being subscribed to — drives
  /// the spinner. Keeping it per-card fixes the bug where all cards
  /// rendered a spinner because a single shared bool was passed in.
  final bool isSubscribingThisPlan;
  /// True while ANY plan's subscribe is in flight — disables all other
  /// plan buttons so only the tapped one is interactive.
  final bool anyPlanSubscribing;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.plan,
    required this.isAnnual,
    required this.isCurrentPlan,
    required this.isMostPopular,
    required this.isSubscribingThisPlan,
    required this.anyPlanSubscribing,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    // Pricing display follows the web vendor portal
    // (frontend_pages/vendor/subscription.html → renderPlans).
    // For monthly plans the prominent figure is the *base* price
    // (₹199, ₹499, ₹888) and the GST-inclusive total goes underneath
    // as a hint. Showing the GST-inclusive figure as the headline made
    // the plans look 18% more expensive than the marketing pages
    // ("Basic ₹234.82" instead of "Basic ₹199").
    final priceToPay = isAnnual
        ? (plan.annualTotal ?? (plan.monthlyTotal * 12))
        : plan.monthlyTotal;
    final annualMonthlyEquivalent = priceToPay / 12;
    final monthlyBase = priceToPay / 1.18;
    final monthlyGst = priceToPay - monthlyBase;
    final prominentPrice = isAnnual
        ? '₹${annualMonthlyEquivalent.toStringAsFixed(2)}'
        : '₹${monthlyBase.toStringAsFixed(2)}';
    final priceHint = isAnnual
        ? 'Billed ₹${priceToPay.toStringAsFixed(2)} annually (incl. GST)'
        : '+ 18% GST (₹${monthlyGst.toStringAsFixed(2)}) = ₹${priceToPay.toStringAsFixed(2)} total';

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.md, top: isMostPopular ? 12 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(
                color: isCurrentPlan
                    ? AppColors.success
                    : isMostPopular
                    ? AppColors.primary
                    : AppColors.border,
                width: (isCurrentPlan || isMostPopular) ? 2 : 1,
              ),
              boxShadow: [
                if (isMostPopular)
                  const BoxShadow(
                    color: Color(0x1AFF5E1E),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: Offset(0, 8),
                  )
                else
                  const BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row — plan name + (optional) "CURRENT PLAN"
                  // pill. Stacked above the price (web layout) so a
                  // wide price like ₹588.82 can't squeeze the title
                  // column to the point where "Basic" wraps one
                  // character per line.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppSizes.fontXxl,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isCurrentPlan)
                        Container(
                          margin: const EdgeInsets.only(left: AppSizes.sm),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: const Text(
                            'CURRENT PLAN',
                            style: TextStyle(
                              fontSize: AppSizes.fontXs,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (plan.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      plan.description,
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSizes.sm),
                  // Price line — base amount + period suffix.
                  // FittedBox guards against very long prices on small
                  // screens (annual totals, GST-inclusive figures).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          prominentPrice,
                          style: const TextStyle(
                            fontSize: AppSizes.fontHeading,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAnnual ? '/mo' : '/month',
                          style: const TextStyle(
                            fontSize: AppSizes.fontSm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    priceHint,
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  if (isAnnual &&
                      plan.savingsPercent != null &&
                      plan.savingsPercent! > 0) ...[
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                      ),
                      child: Text(
                        'Save ${plan.savingsPercent}%',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.md),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: AppSizes.md),

                  ...plan.featureList.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: AppSizes.fontMd,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (plan.trialDays > 0) ...[
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                      ),
                      child: Text(
                        '${plan.trialDays}-day free trial',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.lg),

                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.buttonHeight,
                    child: ElevatedButton(
                      onPressed:
                          isCurrentPlan || anyPlanSubscribing ? null : onSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrentPlan
                            ? AppColors.success
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isCurrentPlan
                            ? AppColors.success.withAlpha(180)
                            : AppColors.textHint,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonRadius,
                          ),
                        ),
                        elevation: isCurrentPlan ? 0 : 2,
                      ),
                      child: isSubscribingThisPlan
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isCurrentPlan
                                  ? 'Current Plan'
                                  : plan.trialDays > 0
                                  ? 'Start Free Trial'
                                  : 'Subscribe Now',
                              style: const TextStyle(
                                fontSize: AppSizes.fontLg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMostPopular)
            Positioned(
              top: -12,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.fontXs,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
