import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../models/subscription_models.dart';
import '../viewmodel/subscription_viewmodel.dart';
import 'invoice_history_screen.dart';
import 'subscription_plans_screen.dart';

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionViewModel>().fetchMySubscription();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Subscription'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Invoice History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InvoiceHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.mySubscription == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (vm.mySubscription == null) {
            return _buildNoSubscription(vm);
          }
          return _buildSubscriptionDetails(vm);
        },
      ),
    );
  }

  Widget _buildNoSubscription(SubscriptionViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(
              'No Active Subscription',
              style: TextStyle(
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            const Text(
              'Subscribe to a plan to unlock premium features and grow your business.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPlansScreen(),
                    ),
                  );
                  if (result == true && mounted) {
                    context.read<SubscriptionViewModel>().fetchMySubscription();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
                child: const Text(
                  'View Plans',
                  style: TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: AppSizes.md),
              Text(
                vm.errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: AppSizes.fontSm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails(SubscriptionViewModel vm) {
    final sub = vm.mySubscription!;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.fetchMySubscription,
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          // ── Status + Days remaining card ───────────────────────
          _buildStatusCard(sub),
          const SizedBox(height: AppSizes.md),

          // ── Plan details card ─────────────────────────────────
          _buildPlanDetailsCard(sub),
          const SizedBox(height: AppSizes.md),

          // ── Auto-renew toggle ─────────────────────────────────
          _buildAutoRenewCard(sub),
          const SizedBox(height: AppSizes.md),

          // ── Quick actions ─────────────────────────────────────
          _buildActionsCard(sub, vm),
          const SizedBox(height: AppSizes.xxl),
        ],
      ),
    );
  }

  // ── Status card with circular progress ──────────────────────────────

  Widget _buildStatusCard(VendorSubscription sub) {
    final statusColor = _statusColor(sub.status);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withAlpha(15),
            statusColor.withAlpha(5),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: statusColor.withAlpha(60)),
      ),
      child: Row(
        children: [
          // Circular days-left indicator
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: sub.progressFraction,
                color: statusColor,
                backgroundColor: statusColor.withAlpha(30),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${sub.daysRemaining}',
                      style: TextStyle(
                        fontSize: AppSizes.fontHeading,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      'days left',
                      style: TextStyle(
                        fontSize: AppSizes.fontXs,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    sub.statusLabel,
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  sub.planName.isNotEmpty ? sub.planName : 'Subscription',
                  style: const TextStyle(
                    fontSize: AppSizes.fontXl,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (sub.endDate != null)
                  Text(
                    sub.cancelAtPeriodEnd
                        ? 'Cancels on ${_dateFormat.format(sub.endDate!)}'
                        : 'Renews on ${_dateFormat.format(sub.endDate!)}',
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: sub.cancelAtPeriodEnd
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan details card ─────────────────────────────────────────────────

  Widget _buildPlanDetailsCard(VendorSubscription sub) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Details',
            style: TextStyle(
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _detailRow('Billing Cycle', _billingCycleLabel(sub.billingCycle)),
          _detailRow('Price', _currencyFormat.format(sub.currentPrice)),
          _detailRow('GST', _currencyFormat.format(sub.currentGst)),
          _detailRow('Total', _currencyFormat.format(sub.currentTotal),
              bold: true),
          if (sub.startDate != null)
            _detailRow('Start Date', _dateFormat.format(sub.startDate!)),
          if (sub.trialEndDate != null && sub.isTrial)
            _detailRow('Trial Ends', _dateFormat.format(sub.trialEndDate!)),
          _detailRow('Payment Method', _paymentMethodLabel(sub.paymentMethod)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Auto-renew card ───────────────────────────────────────────────────

  Widget _buildAutoRenewCard(VendorSubscription sub) {
    final isAutoRenew = sub.autoRenew && !sub.cancelAtPeriodEnd;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.autorenew,
            color: isAutoRenew ? AppColors.success : AppColors.textHint,
            size: 22,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-Renew',
                  style: TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAutoRenew
                      ? 'Your plan will renew automatically'
                      : 'Cancelled — will not renew',
                  style: TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: isAutoRenew
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAutoRenew
                  ? AppColors.success.withAlpha(20)
                  : AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Text(
              isAutoRenew ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w700,
                color: isAutoRenew ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions card ──────────────────────────────────────────────────────

  Widget _buildActionsCard(VendorSubscription sub, SubscriptionViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.swap_horiz,
            iconColor: AppColors.info,
            title: 'Change Plan',
            subtitle: 'Upgrade or switch your subscription',
            onTap: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const SubscriptionPlansScreen(),
                ),
              );
              if (result == true && mounted) {
                vm.fetchMySubscription();
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _actionTile(
            icon: Icons.receipt_long,
            iconColor: AppColors.purple,
            title: 'Invoice History',
            subtitle: 'View past payments and invoices',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InvoiceHistoryScreen(),
              ),
            ),
          ),
          if (sub.isActiveOrTrial && !sub.cancelAtPeriodEnd) ...[
            const Divider(height: 1, indent: 56),
            _actionTile(
              icon: Icons.cancel_outlined,
              iconColor: AppColors.error,
              title: 'Cancel Subscription',
              subtitle: 'Cancel at the end of your billing period',
              onTap: () => _showCancelBottomSheet(vm),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: AppSizes.fontMd,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: AppSizes.fontSm,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs,
      ),
    );
  }

  // ── Cancel confirmation bottom sheet ──────────────────────────────────

  void _showCancelBottomSheet(SubscriptionViewModel vm) {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.lg + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSizes.md),
              const Text(
                'Cancel Subscription?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontXxl,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              const Text(
                'Your subscription will remain active until the end of your current billing period. After that, you\'ll lose access to premium features.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontMd,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Reason for cancellation (optional)',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSizes.lg),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ok = await vm.cancelSubscription(
                      reason: reasonController.text.trim(),
                      atPeriodEnd: true,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Subscription will cancel at period end'
                              : vm.errorMessage ?? 'Failed to cancel',
                        ),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'Cancel at Period End',
                    style: TextStyle(
                      fontSize: AppSizes.fontLg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              SizedBox(
                height: AppSizes.buttonHeight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                  ),
                  child: const Text(
                    'Keep Subscription',
                    style: TextStyle(
                      fontSize: AppSizes.fontLg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'trial':
        return AppColors.info;
      case 'grace_period':
      case 'past_due':
        return AppColors.warning;
      case 'suspended':
      case 'cancelled':
      case 'expired':
        return AppColors.error;
      case 'paused':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _billingCycleLabel(String cycle) {
    switch (cycle) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'half_yearly':
        return 'Half Yearly';
      case 'annual':
        return 'Annual';
      default:
        return cycle;
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'razorpay':
        return 'Razorpay';
      case 'wallet':
        return 'Vendor Wallet';
      case 'manual':
        return 'Manual / Offline';
      default:
        return method;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Circular progress painter for "Days Left"
// ═══════════════════════════════════════════════════════════════════════════

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
