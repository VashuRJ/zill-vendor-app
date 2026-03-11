import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/app_logger.dart';
import '../models/subscription_models.dart';
import '../services/razorpay_subscription_service.dart';
import '../viewmodel/subscription_viewmodel.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );
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
      final vm = context.read<SubscriptionViewModel>();
      if (vm.invoices.isEmpty) {
        vm.fetchMySubscription();
      }
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
    if (order == null || response.orderId == null || response.paymentId == null) {
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
      _showSnackBar('Payment verified!');
      vm.fetchMySubscription();
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
      _showSnackBar('Payment verified!');
      vm.fetchMySubscription();
    } else {
      _showSnackBar(vm.errorMessage ?? 'Verification failed. Try again.', isError: true);
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnackBar('External wallet: ${response.walletName}');
  }

  Future<void> _handleRetry() async {
    final vm = context.read<SubscriptionViewModel>();
    // Backend finds pending invoice from auth context — empty POST
    final orderData = await vm.retryPayment();
    if (!mounted) return;
    if (orderData == null) {
      if (vm.errorMessage != null) {
        _showSnackBar(vm.errorMessage!, isError: true);
      }
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice History'),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.invoices.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (vm.invoices.isEmpty) {
            return _buildEmpty();
          }
          return Column(
            children: [
              // ── Verification recovery banner (network-drop) ───────
              if (vm.hasPendingVerification && vm.status == SubscriptionStatus.error)
                MaterialBanner(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  backgroundColor: AppColors.warning.withAlpha(20),
                  leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  content: const Text(
                    'Payment was received but verification failed. Tap to retry.',
                    style: TextStyle(fontSize: AppSizes.fontSm, color: AppColors.textPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: vm.isVerifying ? null : _retryVerification,
                      child: vm.isVerifying
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Text('Retry Verification'),
                    ),
                  ],
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: vm.fetchMySubscription,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: vm.invoices.length,
                    itemBuilder: (context, index) {
                      return _InvoiceCard(
                        invoice: vm.invoices[index],
                        dateFormat: _dateFormat,
                        currencyFormat: _currencyFormat,
                        onRetry: vm.isSubscribing ? null : _handleRetry,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            SizedBox(height: AppSizes.md),
            Text(
              'No invoices yet',
              style: TextStyle(
                fontSize: AppSizes.fontLg,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSizes.xs),
            Text(
              'Your invoice history will appear here once you make a payment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Invoice card
// ═══════════════════════════════════════════════════════════════════════════

class _InvoiceCard extends StatelessWidget {
  final SubscriptionInvoice invoice;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final VoidCallback? onRetry;

  const _InvoiceCard({
    required this.invoice,
    required this.dateFormat,
    required this.currencyFormat,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusBgColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Icon(
                    _statusIcon,
                    color: _statusBgColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber.isNotEmpty
                            ? invoice.invoiceNumber
                            : invoice.invoiceId,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        invoice.planName,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: invoice.statusLabel,
                  color: _statusBgColor,
                ),
              ],
            ),

            const SizedBox(height: AppSizes.md),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: AppSizes.md),

            // ── Details ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(invoice.totalAmount),
                      style: const TextStyle(
                        fontSize: AppSizes.fontXl,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Period',
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _periodText,
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Breakdown ───────────────────────────────────────
            if (invoice.discountAmount > 0 || invoice.lateFee > 0) ...[
              const SizedBox(height: AppSizes.sm),
              if (invoice.discountAmount > 0)
                _miniRow('Discount', '-${currencyFormat.format(invoice.discountAmount)}',
                    color: AppColors.success),
              if (invoice.lateFee > 0)
                _miniRow('Late Fee', '+${currencyFormat.format(invoice.lateFee)}',
                    color: AppColors.error),
              _miniRow('GST', currencyFormat.format(invoice.gstAmount)),
            ],

            // ── Due date / paid date ────────────────────────────
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Icon(
                  invoice.isPaid ? Icons.check_circle : Icons.schedule,
                  size: 14,
                  color: invoice.isPaid ? AppColors.success : AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  invoice.isPaid && invoice.paidAt != null
                      ? 'Paid on ${dateFormat.format(invoice.paidAt!)}'
                      : invoice.dueDate != null
                          ? 'Due ${dateFormat.format(invoice.dueDate!)}'
                          : '',
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            // ── Failure reason ──────────────────────────────────
            if (invoice.isFailed && invoice.failureReason.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Text(
                  invoice.failureReason,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],

            // ── Retry button ────────────────────────────────────
            if (invoice.canRetry) ...[
              const SizedBox(height: AppSizes.md),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    invoice.isFailed ? 'Retry Payment' : 'Pay Now',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        invoice.isFailed ? AppColors.error : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w500,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String get _periodText {
    final start = invoice.periodStart != null
        ? dateFormat.format(invoice.periodStart!)
        : '—';
    final end = invoice.periodEnd != null
        ? dateFormat.format(invoice.periodEnd!)
        : '—';
    return '$start – $end';
  }

  Color get _statusBgColor {
    switch (invoice.status) {
      case 'paid':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'pending':
        return AppColors.warning;
      case 'refunded':
        return AppColors.info;
      case 'waived':
        return AppColors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (invoice.status) {
      case 'paid':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      case 'pending':
        return Icons.schedule;
      case 'refunded':
        return Icons.replay;
      case 'waived':
        return Icons.card_giftcard;
      default:
        return Icons.receipt;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Status badge
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppSizes.fontXs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
