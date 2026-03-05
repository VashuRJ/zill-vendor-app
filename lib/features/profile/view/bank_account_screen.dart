import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../../earnings/viewmodel/earnings_viewmodel.dart'
    show EarningsCommission, EarningsSettlement, EarningsWallet, Payout;
import '../viewmodel/bank_account_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────
//  Route entry-point — owns its own ChangeNotifier
// ─────────────────────────────────────────────────────────────────────
class BankAccountScreen extends StatelessWidget {
  const BankAccountScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BankAccountViewModel(apiService: apiService),
      child: const _BankAccountView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Main view
// ─────────────────────────────────────────────────────────────────────
class _BankAccountView extends StatefulWidget {
  const _BankAccountView();

  @override
  State<_BankAccountView> createState() => _BankAccountViewState();
}

class _BankAccountViewState extends State<_BankAccountView> {
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<BankAccountViewModel>();
      vm.addListener(_onVmChange);
      vm.fetchBankAccount();
    });
  }

  @override
  void dispose() {
    try {
      context.read<BankAccountViewModel>().removeListener(_onVmChange);
    } catch (_) {}
    super.dispose();
  }

  void _onVmChange() {
    if (!mounted) return;
    final vm = context.read<BankAccountViewModel>();

    if (vm.status == BankStatus.error && !vm.isFetchError) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vm.errorMessage ?? 'Failed to save. Please retry.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(AppSizes.md),
            duration: const Duration(seconds: 4),
          ),
        );
    }

    if (vm.status == BankStatus.idle && vm.hasBank && _isEditing) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  'Bank details saved successfully!',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(AppSizes.md),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BankAccountViewModel>();

    Widget body;
    if (vm.status == BankStatus.fetching) {
      body = const _LoadingView();
    } else if (vm.isFetchError) {
      body = _FetchErrorView(
        message: vm.errorMessage ?? 'Could not load bank details.',
        onRetry: context.read<BankAccountViewModel>().fetchBankAccount,
      );
    } else if (vm.hasBank && !_isEditing) {
      body = _DetailsView(
        data: vm.bankData!,
        wallet: vm.wallet,
        commission: vm.commission,
        settlement: vm.settlement,
        payouts: vm.payouts,
        onUpdate: () => setState(() => _isEditing = true),
      );
    } else {
      body = _FormView(
        vm: vm,
        isUpdate: vm.hasBank,
        onCancel: vm.hasBank ? () => setState(() => _isEditing = false) : null,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Bank Account',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Loading view
// ─────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank card placeholder
            Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
            ),
            const SizedBox(height: 24),
            // Balance summary placeholder
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            const SizedBox(height: 24),
            // Detail rows placeholder
            for (int i = 0; i < 5; i++) ...[
              Container(
                height: 52,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Fetch error view
// ─────────────────────────────────────────────────────────────────────
class _FetchErrorView extends StatelessWidget {
  const _FetchErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 34,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(
              'Unable to load bank details',
              style: TextStyle(
                fontSize: AppSizes.fontXl,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontMd,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Details view — shown when bank is registered
// ─────────────────────────────────────────────────────────────────────
class _DetailsView extends StatelessWidget {
  const _DetailsView({
    required this.data,
    required this.onUpdate,
    this.wallet,
    this.commission,
    this.settlement,
    this.payouts = const [],
  });

  final BankAccountData data;
  final EarningsWallet? wallet;
  final EarningsCommission? commission;
  final EarningsSettlement? settlement;
  final List<Payout> payouts;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
        AppSizes.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Premium bank card ────────────────────────────────────────
          _BankCard(data: data),

          // ── Balance summary (from earnings API) ─────────────────────
          if (wallet != null) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.success,
              iconBg: AppColors.success.withAlpha(20),
              title: 'Balance Summary',
            ),
            const SizedBox(height: 10),
            _BalanceSummaryCard(wallet: wallet!),
          ],

          // ── Commission & Settlement Details ───────────────────────────
          if (commission != null || settlement != null) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF6C5CE7),
              iconBg: const Color(0xFF6C5CE7).withAlpha(20),
              title: 'Commission & Settlement',
            ),
            const SizedBox(height: 10),
            _CommissionSettlementCard(
              commission: commission,
              settlement: settlement,
            ),
          ],

          const SizedBox(height: 24),

          // ── Account Information ──────────────────────────────────────
          _SectionHeader(
            icon: Icons.account_balance_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primary.withAlpha(20),
            title: 'Account Information',
          ),
          const SizedBox(height: 10),
          _DetailCard(
            rows: [
              _DetailRow(
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF6C5CE7),
                label: 'Account Holder',
                value: data.holderName.isNotEmpty ? data.holderName : '\u2014',
              ),
              _DetailRow(
                icon: Icons.credit_card_rounded,
                iconColor: AppColors.primary,
                label: 'Account Number',
                value: _formatMasked(data.maskedNumber),
              ),
              _DetailRow(
                icon: Icons.pin_rounded,
                iconColor: AppColors.info,
                label: 'IFSC Code',
                value: data.ifscCode.isNotEmpty ? data.ifscCode : '\u2014',
                copyable: data.ifscCode.isNotEmpty,
              ),
              _DetailRow(
                icon: Icons.domain_rounded,
                iconColor: AppColors.success,
                label: 'Bank',
                value: _bankLabel(data),
              ),
              _DetailRow(
                icon: Icons.category_rounded,
                iconColor: AppColors.warning,
                label: 'Account Type',
                value: data.accountType.isNotEmpty
                    ? _capitalize(data.accountType)
                    : '\u2014',
              ),
              if (data.upiId.isNotEmpty)
                _DetailRow(
                  icon: Icons.qr_code_2_rounded,
                  iconColor: const Color(0xFF6C5CE7),
                  label: 'UPI ID',
                  value: data.upiId,
                  copyable: true,
                  isLast: true,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Verification status ──────────────────────────────────────
          _VerificationBanner(data: data),

          const SizedBox(height: 24),

          // ── Update button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: onUpdate,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                'Update Bank Details',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSizes.buttonRadius),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSizes.md),

          // ── Security note ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: AppColors.info),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your bank details are encrypted and stored securely.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Recent Payouts ──────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionHeader(
            icon: Icons.payments_rounded,
            iconColor: AppColors.info,
            iconBg: AppColors.info.withAlpha(20),
            title: 'Recent Payouts',
          ),
          const SizedBox(height: 10),
          _RecentPayoutsCard(payouts: payouts),
        ],
      ),
    );
  }

  String _bankLabel(BankAccountData d) {
    if (d.bankName.isNotEmpty && d.branchName.isNotEmpty) {
      return '${d.bankName} \u2014 ${d.branchName}';
    }
    if (d.bankName.isNotEmpty) return d.bankName;
    return '\u2014';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─────────────────────────────────────────────────────────────────────
//  Gradient bank card
// ─────────────────────────────────────────────────────────────────────
class _BankCard extends StatelessWidget {
  const _BankCard({required this.data});
  final BankAccountData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        gradient: const LinearGradient(
          colors: [Color(0xFFE55A2B), Color(0xFFFF6B35), Color(0xFFFF8F65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(90),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: _Circle(size: 120, color: Colors.white.withAlpha(14)),
          ),
          Positioned(
            bottom: -40,
            right: 40,
            child: _Circle(size: 90, color: Colors.white.withAlpha(10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Text(
                    'Bank Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontMd,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  _CardBadge(
                    label: data.isVerified
                        ? 'Verified'
                        : _pendingLabel(data.verificationStatus),
                    icon: data.isVerified
                        ? Icons.verified_rounded
                        : Icons.schedule_rounded,
                    color: data.isVerified
                        ? Colors.white
                        : Colors.white.withAlpha(180),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _formatMasked(data.maskedNumber),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CardSubLabel(
                    heading: 'Account Holder',
                    value: data.holderName.isNotEmpty
                        ? data.holderName.toUpperCase()
                        : '\u2014',
                  ),
                  _CardSubLabel(
                    heading: 'IFSC',
                    value: data.ifscCode.isNotEmpty
                        ? data.ifscCode.toUpperCase()
                        : '\u2014',
                    align: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pendingLabel(String status) {
    switch (status.toLowerCase()) {
      case 'failed':
        return 'Failed';
      case 'verified':
        return 'Verified';
      default:
        return 'Pending';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Balance summary card
// ─────────────────────────────────────────────────────────────────────
class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.wallet});
  final EarningsWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row — Available + Pending
          Row(
            children: [
              Expanded(
                child: _BalanceTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.success,
                  label: 'Available',
                  amount: wallet.availableBalance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceTile(
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.warning,
                  label: 'Pending',
                  amount: wallet.pendingSettlement,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row — Gross + Held
          Row(
            children: [
              Expanded(
                child: _BalanceTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.info,
                  label: 'Gross Earnings',
                  amount: wallet.grossBalance,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceTile(
                  icon: Icons.lock_rounded,
                  iconColor: AppColors.error,
                  label: 'Held',
                  amount: wallet.heldBalance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\u20B9${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: iconColor == AppColors.error && amount > 0
                  ? AppColors.error
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMasked(String masked) {
  if (masked.isEmpty) return '\u2022\u2022\u2022\u2022  \u2022\u2022\u2022\u2022  \u2022\u2022\u2022\u2022';
  final display = masked.replaceAll(RegExp(r'[Xx*]'), '\u2022');
  final chunks = <String>[];
  for (var i = 0; i < display.length; i += 4) {
    final end = (i + 4).clamp(0, display.length);
    chunks.add(display.substring(i, end));
  }
  return chunks.join('  ');
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSubLabel extends StatelessWidget {
  const _CardSubLabel({
    required this.heading,
    required this.value,
    this.align = TextAlign.left,
  });
  final String heading;
  final String value;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            color: Colors.white.withAlpha(170),
            fontSize: AppSizes.fontXs,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Section header (icon pill + title)
// ─────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Verification status banner
// ─────────────────────────────────────────────────────────────────────
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.data});
  final BankAccountData data;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, headline, body) = _resolveStatus(data);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: fg.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: fg.withAlpha(200),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData, String, String) _resolveStatus(BankAccountData d) {
    if (d.isVerified) {
      return (
        AppColors.successLight,
        AppColors.success,
        Icons.verified_rounded,
        'Account Verified',
        'Your bank account is verified. Payouts will be transferred directly.',
      );
    }
    final s = d.verificationStatus.toLowerCase();
    if (s == 'failed') {
      return (
        AppColors.errorLight,
        AppColors.error,
        Icons.error_outline_rounded,
        'Verification Failed',
        'We could not verify your bank account. Please update your details.',
      );
    }
    return (
      AppColors.warningLight,
      AppColors.warning,
      Icons.schedule_rounded,
      'Verification Pending',
      'Your details are under review. Payouts will begin once verified.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Detail card (shadow card with detail rows)
// ─────────────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(
                height: 1,
                indent: 56,
                color: AppColors.borderLight,
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.primary,
    this.copyable = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool copyable;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text('$label copied'),
                        ],
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Commission & Settlement Details card
// ─────────────────────────────────────────────────────────────────────
class _CommissionSettlementCard extends StatelessWidget {
  const _CommissionSettlementCard({this.commission, this.settlement});
  final EarningsCommission? commission;
  final EarningsSettlement? settlement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CommissionTile(
                  icon: Icons.percent_rounded,
                  iconColor: const Color(0xFF6C5CE7),
                  label: 'Commission Rate',
                  value: commission?.rateDisplay.isNotEmpty == true
                      ? commission!.rateDisplay
                      : '${commission?.rate.toStringAsFixed(0) ?? '—'}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CommissionTile(
                  icon: Icons.receipt_rounded,
                  iconColor: AppColors.warning,
                  label: 'GST on Commission',
                  value: commission?.gstRate.isNotEmpty == true
                      ? '${commission!.gstRate}%'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CommissionTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppColors.info,
                  label: 'Settlement Cycle',
                  value: settlement?.cycleDisplay ?? '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CommissionTile(
                  icon: Icons.currency_rupee_rounded,
                  iconColor: AppColors.success,
                  label: 'Minimum Payout',
                  value: settlement != null
                      ? '\u20B9${settlement!.minAmount.toStringAsFixed(0)}'
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommissionTile extends StatelessWidget {
  const _CommissionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Recent Payouts card
// ─────────────────────────────────────────────────────────────────────
class _RecentPayoutsCard extends StatelessWidget {
  const _RecentPayoutsCard({required this.payouts});
  final List<Payout> payouts;

  @override
  Widget build(BuildContext context) {
    if (payouts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_rounded,
                size: 28,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No payouts yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your payout history will appear here\nonce settlements are processed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < payouts.length; i++) ...[
            _PayoutRow(payout: payouts[i]),
            if (i < payouts.length - 1)
              const Divider(
                height: 1,
                indent: 56,
                color: AppColors.borderLight,
              ),
          ],
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});
  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusLabel) = _resolveStatus();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, size: 16, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u20B9${payout.netAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(payout.initiatedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _resolveStatus() {
    if (payout.isSuccessful) {
      return (AppColors.success, Icons.check_circle_rounded, 'Processed');
    }
    if (payout.isFailed) {
      return (AppColors.error, Icons.cancel_rounded, 'Failed');
    }
    return (AppColors.warning, Icons.schedule_rounded, 'Pending');
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Registration / Edit form
// ─────────────────────────────────────────────────────────────────────
class _FormView extends StatefulWidget {
  const _FormView({required this.vm, required this.isUpdate, this.onCancel});

  final BankAccountViewModel vm;
  final bool isUpdate;
  final VoidCallback? onCancel;

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  final _formKey = GlobalKey<FormState>();

  final _holderCtrl = TextEditingController();
  final _acctCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  bool _obscureAcct = true;
  bool _obscureConfirm = true;
  String _accountType = 'current';

  final _holderFocus = FocusNode();
  final _acctFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _ifscFocus = FocusNode();
  final _upiFocus = FocusNode();

  @override
  void dispose() {
    _holderCtrl.dispose();
    _acctCtrl.dispose();
    _confirmCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _holderFocus.dispose();
    _acctFocus.dispose();
    _confirmFocus.dispose();
    _ifscFocus.dispose();
    _upiFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await widget.vm.registerBankAccount(
      holderName: _holderCtrl.text,
      accountNumber: _acctCtrl.text,
      ifscCode: _ifscCtrl.text,
      accountType: _accountType,
      upiId: _upiCtrl.text.trim().isEmpty ? null : _upiCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final isSaving = vm.status == BankStatus.saving;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
        AppSizes.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            _FormHeader(isUpdate: widget.isUpdate),
            const SizedBox(height: 24),

            // ── Account Holder Name ────────────────────────────────────
            _FieldLabel('Account Holder Name'),
            _AppTextField(
              controller: _holderCtrl,
              focusNode: _holderFocus,
              nextFocus: _acctFocus,
              hint: 'Full name as on bank records',
              prefixIcon: Icons.person_rounded,
              textCapitalization: TextCapitalization.words,
              enabled: !isSaving,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Account holder name is required';
                }
                if (v.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),

            const SizedBox(height: AppSizes.md),

            // ── Account Number ─────────────────────────────────────────
            _FieldLabel('Account Number'),
            _AppTextField(
              controller: _acctCtrl,
              focusNode: _acctFocus,
              nextFocus: _confirmFocus,
              hint: 'Enter account number',
              prefixIcon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              obscureText: _obscureAcct,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !isSaving,
              onToggleObscure: () =>
                  setState(() => _obscureAcct = !_obscureAcct),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Account number is required';
                }
                if (v.length < 9 || v.length > 18) {
                  return 'Account number must be 9\u201318 digits';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSizes.md),

            // ── Confirm Account Number ─────────────────────────────────
            _FieldLabel('Re-enter Account Number'),
            _AppTextField(
              controller: _confirmCtrl,
              focusNode: _confirmFocus,
              nextFocus: _ifscFocus,
              hint: 'Confirm account number',
              prefixIcon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              obscureText: _obscureConfirm,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !isSaving,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please confirm your account number';
                }
                if (v != _acctCtrl.text) {
                  return 'Account numbers do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSizes.md),

            // ── IFSC Code ──────────────────────────────────────────────
            _FieldLabel('IFSC Code'),
            _AppTextField(
              controller: _ifscCtrl,
              focusNode: _ifscFocus,
              nextFocus: _upiFocus,
              hint: 'e.g. HDFC0001234',
              prefixIcon: Icons.pin_rounded,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                UpperCaseTextFormatter(),
                LengthLimitingTextInputFormatter(11),
              ],
              enabled: !isSaving,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'IFSC code is required';
                }
                if (v.trim().length != 11) {
                  return 'IFSC code must be exactly 11 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSizes.lg),

            // ── Account Type ───────────────────────────────────────────
            _FieldLabel('Account Type'),
            _AccountTypeToggle(
              value: _accountType,
              enabled: !isSaving,
              onChange: (v) => setState(() => _accountType = v),
            ),

            const SizedBox(height: AppSizes.lg),

            // ── UPI ID (optional) ──────────────────────────────────────
            _FieldLabel('UPI ID  (optional)'),
            _AppTextField(
              controller: _upiCtrl,
              focusNode: _upiFocus,
              hint: 'e.g. name@upi',
              prefixIcon: Icons.qr_code_2_rounded,
              keyboardType: TextInputType.emailAddress,
              enabled: !isSaving,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.contains('@')) return 'Enter a valid UPI ID';
                return null;
              },
            ),

            const SizedBox(height: AppSizes.xl),

            // ── Save button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  elevation: 0,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.isUpdate
                                ? 'Update Bank Details'
                                : 'Save Bank Details',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Cancel (update mode) ───────────────────────────────────
            if (widget.onCancel != null) ...[
              const SizedBox(height: AppSizes.sm),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: TextButton(
                  onPressed: isSaving ? null : widget.onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppSizes.fontMd,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSizes.xl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Form header
// ─────────────────────────────────────────────────────────────────────
class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.isUpdate});
  final bool isUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpdate ? 'Update Bank Account' : 'Link Your Bank Account',
                  style: const TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your payout settlements will be transferred to this account. Details are encrypted and stored securely.',
                  style: TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                    height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────
//  Account Type toggle
// ─────────────────────────────────────────────────────────────────────
class _AccountTypeToggle extends StatelessWidget {
  const _AccountTypeToggle({
    required this.value,
    required this.onChange,
    required this.enabled,
  });

  final String value;
  final ValueChanged<String> onChange;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Current',
          icon: Icons.business_rounded,
          selected: value == 'current',
          enabled: enabled,
          onTap: () => onChange('current'),
        ),
        const SizedBox(width: AppSizes.sm),
        _TypeChip(
          label: 'Savings',
          icon: Icons.savings_rounded,
          selected: value == 'savings',
          enabled: enabled,
          onTap: () => onChange('savings'),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : AppColors.textHint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Text field
// ─────────────────────────────────────────────────────────────────────
class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.focusNode,
    this.nextFocus,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.onToggleObscure,
    this.inputFormatters,
    this.enabled = true,
    this.validator,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      textInputAction:
          nextFocus != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
      validator: validator,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppSizes.fontMd,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textHint.withAlpha(150),
          fontSize: AppSizes.fontMd,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.textHint),
        suffixIcon: onToggleObscure != null
            ? GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textHint,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
