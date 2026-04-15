// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../../profile/view/bank_account_screen.dart';
import '../viewmodel/bank_tab_viewmodel.dart';
import '../viewmodel/earnings_viewmodel.dart';
import 'transactions_screen.dart';

// ─────────────────────────────────────────────────────────────────────
//  Route entry-point — signature unchanged for app_shell.dart
// ─────────────────────────────────────────────────────────────────────
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BankTabViewModel(apiService: apiService),
      child: const _EarningsDashboard(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Main scaffold
// ─────────────────────────────────────────────────────────────────────
class _EarningsDashboard extends StatefulWidget {
  const _EarningsDashboard();

  @override
  State<_EarningsDashboard> createState() => _EarningsDashboardState();
}

class _EarningsDashboardState extends State<_EarningsDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BankTabViewModel>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BankTabViewModel>();

    Widget body;
    if (vm.isInitialLoading) {
      body = const _LoadingView();
    } else if (vm.status == BankTabStatus.error && !vm.hasSummary) {
      body = _ErrorView(
        message: vm.earningsError ?? 'Could not load data.',
        onRetry: context.read<BankTabViewModel>().loadAll,
      );
    } else {
      body = _buildContent(vm);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Earnings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
        actions: [
          if (!vm.isInitialLoading)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Refresh',
              onPressed: context.read<BankTabViewModel>().refresh,
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildContent(BankTabViewModel vm) {
    final currFmt = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
    final thisWeek = vm.thisWeek ?? const ThisWeekEarnings();
    final payoutInfo = vm.payoutInfo ?? const PayoutInfo();
    final lifetime = vm.lifetime ?? const LifetimeEarnings();
    final history = vm.payoutHistory;
    final awaiting = vm.summary?.firstAwaitingBank;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Red banner: bank not verified / awaiting bank info ──
            if (!payoutInfo.bankReady) ...[
              _BankWarningBanner(
                bankStatus: payoutInfo.bankStatus,
                onTap: () => _openBankScreen(),
              ),
              const SizedBox(height: 14),
            ] else if (awaiting != null) ...[
              _AwaitingBankBanner(
                entry: awaiting,
                currFmt: currFmt,
                onTap: () => _openBankScreen(),
              ),
              const SizedBox(height: 14),
            ],

            // ── 1. This Week hero ───────────────────────────────────
            _ThisWeekHero(thisWeek: thisWeek, currFmt: currFmt),
            const SizedBox(height: 14),

            // ── 2. Next Payout card ─────────────────────────────────
            _NextPayoutCard(payoutInfo: payoutInfo, currFmt: currFmt),
            const SizedBox(height: 18),

            // ── 3. Daily breakdown bar chart ────────────────────────
            _DailyBreakdownChart(thisWeek: thisWeek, currFmt: currFmt),
            const SizedBox(height: 18),

            // ── 4. Earnings breakdown (Gross → Net) ─────────────────
            _BreakdownCard(thisWeek: thisWeek, currFmt: currFmt),
            const SizedBox(height: 18),

            // ── 5. Carry-forward strip (only if active) ─────────────
            if (payoutInfo.hasCarryForward) ...[
              _CarryForwardStrip(payoutInfo: payoutInfo, currFmt: currFmt),
              const SizedBox(height: 18),
            ],

            // ── 6. Recent payouts (settlement history) ──────────────
            _PayoutHistoryList(
              history: history,
              currFmt: currFmt,
              onViewAll: () {
                final api = context.read<BankTabViewModel>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionsScreen(apiService: api.apiService),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // ── 7. Lifetime stats ───────────────────────────────────
            _LifetimeCard(lifetime: lifetime, currFmt: currFmt),
            const SizedBox(height: 18),

            // ── 8. Bank Status Card ─────────────────────────────────
            _BankStatusCard(
              bankData: vm.bankData,
              bankLoading: vm.bankLoading,
              payoutInfo: payoutInfo,
              onTap: _openBankScreen,
            ),
          ],
        ),
      ),
    );
  }

  void _openBankScreen() {
    final api = context.read<BankTabViewModel>().apiService;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountScreen(apiService: api),
      ),
    ).then((_) {
      if (mounted) context.read<BankTabViewModel>().refresh();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Bank-not-verified red banner (auto-payout flow blocker).
// ─────────────────────────────────────────────────────────────────────
class _BankWarningBanner extends StatelessWidget {
  const _BankWarningBanner({required this.bankStatus, required this.onTap});

  final BankStatus bankStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMissing = bankStatus == BankStatus.notAdded ||
        bankStatus == BankStatus.unknown;
    final title = isMissing
        ? 'Bank account not added'
        : 'Bank verification pending';
    final subtitle = isMissing
        ? 'Add your bank account so Monday\u2019s payout can settle.'
        : 'Verification in progress \u2014 you can edit details if needed.';

    return Material(
      color: AppColors.error,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Awaiting-bank-info amber banner — settlement created but blocked
//  because the vendor never added/verified a bank account.
// ─────────────────────────────────────────────────────────────────────
class _AwaitingBankBanner extends StatelessWidget {
  const _AwaitingBankBanner({
    required this.entry,
    required this.currFmt,
    required this.onTap,
  });

  final PayoutHistoryEntry entry;
  final NumberFormat currFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currFmt.format(entry.amount)} stuck \u2014 add bank to release',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Settlement ${entry.settlementId} \u2022 ${entry.periodLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  This Week hero card
// ─────────────────────────────────────────────────────────────────────
class _ThisWeekHero extends StatelessWidget {
  const _ThisWeekHero({required this.thisWeek, required this.currFmt});

  final ThisWeekEarnings thisWeek;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3436), Color(0xFF636E72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3436).withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_view_week_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'This Week',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (thisWeek.periodLabel.isNotEmpty)
                Text(
                  thisWeek.periodLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currFmt.format(thisWeek.netEarnings),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Net earnings \u2022 ${thisWeek.totalOrders} orders',
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroChip(
                icon: Icons.payments_rounded,
                label: 'Gross ${currFmt.format(thisWeek.grossEarnings)}',
              ),
              const SizedBox(width: 8),
              _heroChip(
                icon: Icons.receipt_long_rounded,
                label:
                    'Fees ${currFmt.format(thisWeek.commissionDeducted + thisWeek.gstDeducted)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Next Payout card
// ─────────────────────────────────────────────────────────────────────
class _NextPayoutCard extends StatelessWidget {
  const _NextPayoutCard({required this.payoutInfo, required this.currFmt});

  final PayoutInfo payoutInfo;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, dd MMM');
    final ready = payoutInfo.bankReady;
    final accent = ready ? AppColors.success : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'NEXT PAYOUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currFmt.format(payoutInfo.estimatedAmount),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  payoutInfo.nextPayoutDate != null
                      ? 'on ${dateFmt.format(payoutInfo.nextPayoutDate!)}'
                      : payoutInfo.payoutSchedule,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.account_balance_rounded,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  payoutInfo.bankAccount,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (payoutInfo.belowMinPayout) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Below minimum (${currFmt.format(payoutInfo.minimumPayout)}) \u2014 will roll into next week.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (payoutInfo.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              payoutInfo.message,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Daily breakdown bar chart (this_week.daily_breakdown)
// ─────────────────────────────────────────────────────────────────────
class _DailyBreakdownChart extends StatelessWidget {
  const _DailyBreakdownChart({required this.thisWeek, required this.currFmt});

  final ThisWeekEarnings thisWeek;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    final days = thisWeek.dailyBreakdown;
    final maxY = thisWeek.peakDailyEarning;
    final ceiling = maxY > 0 ? maxY * 1.25 : 500.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            thisWeek.periodLabel.isNotEmpty
                ? thisWeek.periodLabel
                : 'Net earnings per day',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (!thisWeek.hasAnyActivity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No orders yet this week',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: ceiling,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ceiling / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.borderLight, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: ceiling / 4,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            '\u20B9${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textHint,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days[i].shortDay,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(days.length, (i) {
                    final d = days[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: d.earnings,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.primary.withAlpha(180),
                              AppColors.primary,
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) {
                        final d = days[group.x];
                        return BarTooltipItem(
                          '${currFmt.format(rod.toY)}\n${d.orders} orders',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
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
//  Earnings breakdown card — Gross → Commission → GST → Penalties → Net
// ─────────────────────────────────────────────────────────────────────
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.thisWeek, required this.currFmt});

  final ThisWeekEarnings thisWeek;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week\u2019s Math',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _row('Gross earnings', thisWeek.grossEarnings, isPositive: true),
          _row('Platform commission', -thisWeek.commissionDeducted),
          _row('GST', -thisWeek.gstDeducted),
          if (thisWeek.penalties > 0)
            _row('Penalties', -thisWeek.penalties, isPenalty: true),
          const Divider(height: 20, color: AppColors.borderLight),
          _row('Net payout', thisWeek.netEarnings, isBold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double value,
      {bool isBold = false, bool isPositive = false, bool isPenalty = false}) {
    final color = isPenalty
        ? AppColors.error
        : (value < 0
            ? AppColors.textSecondary
            : (isBold || isPositive
                ? AppColors.textPrimary
                : AppColors.textPrimary));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                color: AppColors.textSecondary,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${value < 0 ? '-' : ''}${NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0).format(value.abs())}',
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Carry-forward strip (only when amount > 0)
// ─────────────────────────────────────────────────────────────────────
class _CarryForwardStrip extends StatelessWidget {
  const _CarryForwardStrip({required this.payoutInfo, required this.currFmt});

  final PayoutInfo payoutInfo;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carry-forward: ${currFmt.format(payoutInfo.carryForwardAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Below minimum payout \u2014 added to next week\u2019s settlement.',
                  style: const TextStyle(
                    fontSize: 11,
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

// ─────────────────────────────────────────────────────────────────────
//  Payout history list
// ─────────────────────────────────────────────────────────────────────
class _PayoutHistoryList extends StatelessWidget {
  const _PayoutHistoryList({
    required this.history,
    required this.currFmt,
    this.onViewAll,
  });

  final List<PayoutHistoryEntry> history;
  final NumberFormat currFmt;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text(
                'RECENT PAYOUTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No payouts yet',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            )
          else
            ...history.take(5).map((p) => _PayoutTile(entry: p, currFmt: currFmt)),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.entry, required this.currFmt});

  final PayoutHistoryEntry entry;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    Color statusBg;
    Color statusFg;
    IconData icon;
    if (entry.isPaid) {
      statusBg = AppColors.successLight;
      statusFg = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (entry.isAwaitingBank) {
      statusBg = AppColors.warningLight;
      statusFg = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
    } else if (entry.isFailed) {
      statusBg = AppColors.errorLight;
      statusFg = AppColors.error;
      icon = Icons.error_rounded;
    } else {
      statusBg = AppColors.background;
      statusFg = AppColors.textSecondary;
      icon = Icons.schedule_rounded;
    }

    final paidStr = entry.paidOn != null
        ? DateFormat('dd MMM yyyy').format(entry.paidOn!)
        : entry.periodLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusFg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.periodLabel.isEmpty
                      ? entry.settlementId
                      : entry.periodLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.utr.isNotEmpty ? 'UTR: ${entry.utr}' : paidStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currFmt.format(entry.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.statusDisplay,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Lifetime stats card
// ─────────────────────────────────────────────────────────────────────
class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.lifetime, required this.currFmt});

  final LifetimeEarnings lifetime;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lifetime',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Earned',
                  currFmt.format(lifetime.totalEarned),
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stat(
                  'Paid out',
                  currFmt.format(lifetime.totalPaidOut),
                  AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Commission',
                  currFmt.format(lifetime.totalCommission),
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stat(
                  'GST',
                  currFmt.format(lifetime.totalGst),
                  AppColors.secondary,
                ),
              ),
            ],
          ),
          if (lifetime.totalPenalties > 0) ...[
            const SizedBox(height: 10),
            _stat(
              'Penalties',
              currFmt.format(lifetime.totalPenalties),
              AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  7. Bank Status Card
// ─────────────────────────────────────────────────────────────────────
class _BankStatusCard extends StatelessWidget {
  const _BankStatusCard({
    required this.bankData,
    required this.bankLoading,
    required this.payoutInfo,
    required this.onTap,
  });

  final BankAccountData? bankData;
  final bool bankLoading;
  final PayoutInfo payoutInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (bankLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
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
    }

    // Authoritative status from payout_info; fall back to local bank data.
    final verified = payoutInfo.bankReady ||
        (bankData?.isVerified ?? false);
    final hasBank = bankData != null ||
        payoutInfo.bankStatus != BankStatus.notAdded &&
            payoutInfo.bankStatus != BankStatus.unknown;
    final accent = verified
        ? AppColors.success
        : (hasBank ? AppColors.warning : AppColors.error);
    final title = verified
        ? 'Bank Verified'
        : (hasBank ? 'Verification Pending' : 'No Bank Added');
    final subtitle = verified
        ? payoutInfo.bankAccount
        : (hasBank
            ? 'We\u2019ll let you know once verification completes.'
            : 'Add a bank account to receive weekly payouts.');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  verified
                      ? Icons.verified_rounded
                      : (hasBank
                          ? Icons.pending_rounded
                          : Icons.account_balance_outlined),
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Loading
// ─────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
          SizedBox(height: AppSizes.md),
          Text(
            'Loading your earnings\u2026',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontMd,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Full-screen error
// ─────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 34,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            const Text(
              'Unable to load earnings',
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
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
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
