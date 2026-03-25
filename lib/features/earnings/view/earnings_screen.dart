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
import '../viewmodel/bank_tab_viewmodel.dart';
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

  Future<void> _pickCustomRange(BankTabViewModel vm) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange:
          vm.customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      vm.setFilter('Custom', customRange: picked);
    }
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
    final summary = vm.summary;
    final currFmt = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);
    final wallet = summary?.wallet;

    // Use computed totals from /vendors/earnings/ (real-time from DB)
    final totalEarnings = vm.vendorTotalEarnings;
    final totalOrders = vm.vendorTotalOrders;
    final avgOrderValue = vm.vendorAvgOrderValue;

    // Period-filtered stats from server
    final periodStats = vm.filteredPeriodStats;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: vm.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero: Total Earnings ──────────────────────────────
            _HeroCard(
              totalEarnings: currFmt.format(totalEarnings),
              subtitle:
                  'Avg. order value: ${currFmt.format(avgOrderValue)} \u2022 $totalOrders orders',
              availableBalance: currFmt.format(wallet?.availableBalance ?? 0),
            ),
            const SizedBox(height: 14),

            // ── 2. Withdraw Button ───────────────────────────────────
            _WithdrawButton(
              canWithdraw: vm.canRequestPayout,
              onPressed: () => _showWithdrawSheet(context, vm),
            ),
            const SizedBox(height: 18),

            // ── 3. Time Filters ──────────────────────────────────────
            _TimeFilterRow(
              selectedFilter: vm.selectedFilter,
              customDateRange: vm.customDateRange,
              onFilterChanged: (f) => vm.setFilter(f),
              onCustomTapped: () => _pickCustomRange(vm),
            ),
            const SizedBox(height: 14),

            // ── 4. Stat Cards (2×2 Grid) ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCardColored(
                    label: 'TOTAL EARNINGS',
                    value: currFmt.format(periodStats.total),
                    icon: Icons.currency_rupee_rounded,
                    accentColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCardColored(
                    label: 'TOTAL ORDERS',
                    value: '${periodStats.count}',
                    icon: Icons.shopping_bag_rounded,
                    accentColor: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCardColored(
                    label:
                        'PLATFORM FEE (${summary?.commission.rateDisplay ?? '10%'})',
                    value: currFmt.format(
                      periodStats.total *
                          (summary?.commission.rate ?? 10) /
                          100,
                    ),
                    icon: Icons.percent_rounded,
                    accentColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCardColored(
                    label: 'NET EARNINGS',
                    value: currFmt.format(
                      periodStats.total -
                          (periodStats.total *
                              (summary?.commission.rate ?? 10) /
                              100),
                    ),
                    icon: Icons.file_download_outlined,
                    accentColor: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── 5. Earnings Trend Chart ──────────────────────────────
            _EarningsTrendChart(
              chartData: vm.chartDayData,
              recentTransactions: vm.vendorRecentTransactions,
            ),
            const SizedBox(height: 18),

            // ── 6. Recent Transactions ───────────────────────────────
            _RecentTransactions(
              transactions: vm.vendorRecentTransactions,
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

            // ── 7. Bank Status Card ──────────────────────────────────
            _BankStatusCard(bankData: vm.bankData, bankLoading: vm.bankLoading),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext ctx, BankTabViewModel vm) {
    final wallet = vm.summary?.wallet;
    if (wallet == null) return;
    final currFmt = NumberFormat.currency(symbol: '\u20B9', decimalDigits: 0);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Withdraw Funds',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available: ${currFmt.format(wallet.availableBalance)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: wallet.availableBalance > 0
                    ? () {
                        Navigator.pop(ctx);
                        vm.requestPayout(wallet.availableBalance);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Withdraw ${currFmt.format(wallet.availableBalance)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
//  1. Hero Card — Total Earnings
// ─────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalEarnings,
    required this.subtitle,
    required this.availableBalance,
  });

  final String totalEarnings;
  final String subtitle;
  final String availableBalance;

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
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Total Earnings',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            totalEarnings,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Available: $availableBalance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
//  2. Withdraw Button
// ─────────────────────────────────────────────────────────────────────
class _WithdrawButton extends StatelessWidget {
  const _WithdrawButton({required this.canWithdraw, required this.onPressed});

  final bool canWithdraw;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: canWithdraw ? onPressed : null,
        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Withdraw Funds',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 18, color: Colors.white.withAlpha(60)),
            const SizedBox(width: 10),
            const Icon(Icons.history_rounded, size: 16),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textHint,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  3. Time Filter Row
// ─────────────────────────────────────────────────────────────────────
class _TimeFilterRow extends StatelessWidget {
  const _TimeFilterRow({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onCustomTapped,
    this.customDateRange,
  });

  final String selectedFilter;
  final DateTimeRange? customDateRange;
  final void Function(String) onFilterChanged;
  final VoidCallback onCustomTapped;

  static const _presets = ['Today', 'This Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    // Build the Custom button label
    String customLabel = 'Custom';
    if (selectedFilter == 'Custom' && customDateRange != null) {
      final fmt = DateFormat('dd MMM');
      customLabel =
          '${fmt.format(customDateRange!.start)} – ${fmt.format(customDateRange!.end)}';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._presets.map(
              (label) => _filterChip(
                label: label,
                selected: selectedFilter == label,
                onTap: () => onFilterChanged(label),
              ),
            ),
            _filterChip(
              label: customLabel,
              selected: selectedFilter == 'Custom',
              onTap: onCustomTapped,
              icon: Icons.calendar_today_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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
//  4. Stat Card — colored top border (matches design)
// ─────────────────────────────────────────────────────────────────────
class _StatCardColored extends StatelessWidget {
  const _StatCardColored({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored top border
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withAlpha(150)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
//  5. Earnings Trend Chart (fl_chart)
// ─────────────────────────────────────────────────────────────────────
class _EarningsTrendChart extends StatelessWidget {
  const _EarningsTrendChart({
    required this.chartData,
    this.recentTransactions = const [],
  });

  final List<ChartDayData> chartData;
  final List<VendorRecentTransaction> recentTransactions;

  @override
  Widget build(BuildContext context) {
    final dayTotals = <double>[];
    final dayLabels = <String>[];

    if (chartData.isNotEmpty) {
      // Use server-provided chart data
      for (final entry in chartData) {
        dayLabels.add(entry.day);
        dayTotals.add(entry.amount);
      }
    } else {
      // Fallback: compute from recent transactions
      final now = DateTime.now();
      final dayFmt = DateFormat('E');
      for (int d = 6; d >= 0; d--) {
        final day = DateTime(now.year, now.month, now.day - d);
        dayLabels.add(dayFmt.format(day));
        double total = 0;
        for (final t in recentTransactions) {
          try {
            final dt = DateTime.parse(t.date).toLocal();
            if (dt.year == day.year &&
                dt.month == day.month &&
                dt.day == day.day) {
              total += t.amount;
            }
          } catch (_) {}
        }
        dayTotals.add(total);
      }
    }

    final maxY = dayTotals.fold(0.0, (a, b) => a > b ? a : b);
    final ceiling = maxY > 0 ? (maxY * 1.3) : 500.0;

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
            'Earnings Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last 7 days performance',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: ceiling,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ceiling / 4,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.borderLight, strokeWidth: 1),
                ),
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
                        if (i < 0 || i >= dayLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayLabels[i],
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      dayTotals.length,
                      (i) => FlSpot(i.toDouble(), dayTotals[i]),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3.5,
                            color: AppColors.surface,
                            strokeWidth: 2,
                            strokeColor: AppColors.primary,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withAlpha(50),
                          AppColors.primary.withAlpha(5),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '\u20B9${s.y.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
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
//  6. Recent Transactions
// ─────────────────────────────────────────────────────────────────────
class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.transactions,
    required this.currFmt,
    this.onViewAll,
  });

  final List<VendorRecentTransaction> transactions;
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
                Icons.swap_vert_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text(
                'RECENT TRANSACTIONS',
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  '${transactions.length} orders',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent transactions',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ),
            )
          else
            ...transactions
                .take(10)
                .map((t) => _TransactionTile(txn: t, currFmt: currFmt)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn, required this.currFmt});

  final VendorRecentTransaction txn;
  final NumberFormat currFmt;

  @override
  Widget build(BuildContext context) {
    String timeStr = '';
    try {
      final dt = DateTime.parse(txn.date).toLocal();
      timeStr = DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      timeStr = txn.date;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.south_west_rounded,
              color: AppColors.success,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${txn.orderId}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\u{1F464} ${txn.customer}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${currFmt.format(txn.amount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
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
  const _BankStatusCard({required this.bankData, required this.bankLoading});

  final BankAccountData? bankData;
  final bool bankLoading;

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

    final hasBank = bankData != null;
    final verified = bankData?.isVerified ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBank
              ? (verified
                    ? AppColors.success.withAlpha(60)
                    : AppColors.warning.withAlpha(60))
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasBank
                  ? (verified ? AppColors.successLight : AppColors.warningLight)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasBank
                  ? (verified ? Icons.verified_rounded : Icons.pending_rounded)
                  : Icons.account_balance_outlined,
              color: hasBank
                  ? (verified ? AppColors.success : AppColors.warning)
                  : AppColors.textHint,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasBank
                      ? (verified ? 'Bank Verified' : 'Verification Pending')
                      : 'No Bank Added',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasBank
                        ? (verified ? AppColors.success : AppColors.warning)
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasBank
                      ? '${bankData!.bankName} \u2022 ${bankData!.maskedNumber}'
                      : 'Add a bank account to receive payouts',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textHint,
            size: 22,
          ),
        ],
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
