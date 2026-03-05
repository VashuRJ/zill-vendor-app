import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../viewmodel/analytics_viewmodel.dart';

class AnalyticsScreen extends StatefulWidget {
  final ApiService apiService;
  const AnalyticsScreen({super.key, required this.apiService});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late AnalyticsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = AnalyticsViewModel(apiService: widget.apiService);
    _vm.fetchAnalytics();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          actions: [
            Consumer<AnalyticsViewModel>(
              builder: (_, vm, _) => IconButton(
                icon: Icon(
                  vm.startDate != null
                      ? Icons.date_range_rounded
                      : Icons.calendar_today_outlined,
                  color: vm.startDate != null ? AppColors.primary : null,
                ),
                tooltip: 'Filter by date range',
                onPressed: () => _showDateRangePicker(context, vm),
              ),
            ),
          ],
        ),
        body: Consumer<AnalyticsViewModel>(
          builder: (context, vm, _) {
            // ── Loading ────────────────────────────────────────
            if (vm.isLoading) {
              return const ShimmerList(itemCount: 6, itemHeight: 100);
            }

            // ── Error ──────────────────────────────────────────
            if (vm.status == AnalyticsStatus.error && !vm.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 56, color: AppColors.textHint),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        vm.errorMessage ?? 'Something went wrong',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      ElevatedButton.icon(
                        onPressed: vm.fetchAnalytics,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ── Data ───────────────────────────────────────────
            final data = vm.data;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: vm.fetchAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date range chip
                    if (vm.startDate != null && vm.endDate != null)
                      _DateRangeChip(
                        start: vm.startDate!,
                        end: vm.endDate!,
                        onClear: vm.clearDateRange,
                      ),
                    if (vm.startDate != null)
                      const SizedBox(height: AppSizes.sm),

                    // 1. Metrics summary
                    _MetricsSummary(metrics: data.metrics),
                    const SizedBox(height: AppSizes.lg),

                    // 2. Revenue trend bar chart
                    if (data.revenueTrend.isNotEmpty) ...[
                      _SectionTitle('Revenue Trend'),
                      const SizedBox(height: AppSizes.sm),
                      _RevenueBarChart(
                        trend: data.revenueTrend,
                        maxRevenue: data.maxRevenue,
                      ),
                      const SizedBox(height: AppSizes.lg),
                    ],

                    // 3. Order status breakdown
                    if (data.orderStatus.isNotEmpty) ...[
                      _SectionTitle('Order Status'),
                      const SizedBox(height: AppSizes.sm),
                      _OrderStatusCard(
                        statuses: data.orderStatus,
                        total: data.totalStatusOrders,
                      ),
                      const SizedBox(height: AppSizes.lg),
                    ],

                    // 4. Top selling items
                    if (data.topItems.isNotEmpty) ...[
                      _SectionTitle('Top Selling Items'),
                      const SizedBox(height: AppSizes.sm),
                      _TopItemsList(items: data.topItems),
                      const SizedBox(height: AppSizes.lg),
                    ],

                    // 5. Payment methods
                    if (data.paymentMethods.isNotEmpty) ...[
                      _SectionTitle('Payment Methods'),
                      const SizedBox(height: AppSizes.sm),
                      _PaymentMethodsCard(methods: data.paymentMethods),
                      const SizedBox(height: AppSizes.lg),
                    ],

                    // Empty state if no data at all
                    if (data.revenueTrend.isEmpty &&
                        data.orderStatus.isEmpty &&
                        data.topItems.isEmpty &&
                        data.metrics.totalOrders == 0)
                      _EmptyState(),

                    const SizedBox(height: AppSizes.xl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker(
    BuildContext context,
    AnalyticsViewModel vm,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: vm.startDate != null && vm.endDate != null
          ? DateTimeRange(start: vm.startDate!, end: vm.endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      vm.setDateRange(picked.start, picked.end);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Date Range Chip
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangeChip extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final VoidCallback onClear;
  const _DateRangeChip({
    required this.start,
    required this.end,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.date_range_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '${_fmt(start)} – ${_fmt(end)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Metrics Summary (4 cards in 2x2 grid)
// ─────────────────────────────────────────────────────────────────────────────

class _MetricsSummary extends StatelessWidget {
  final AnalyticsMetrics metrics;
  const _MetricsSummary({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.currency_rupee_rounded,
                iconColor: AppColors.success,
                label: 'Total Revenue',
                value: _formatCurrency(metrics.totalRevenue),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: _MetricCard(
                icon: Icons.shopping_bag_rounded,
                iconColor: AppColors.info,
                label: 'Total Orders',
                value: metrics.totalOrders.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.people_rounded,
                iconColor: AppColors.orderPreparing,
                label: 'Customers',
                value: metrics.newCustomers.toString(),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: _MetricCard(
                icon: Icons.star_rounded,
                iconColor: AppColors.ratingStar,
                label: 'Avg Rating',
                value: metrics.avgRating > 0
                    ? metrics.avgRating.toStringAsFixed(1)
                    : '—',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\u20B9${amount.toStringAsFixed(0)}';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(24),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Revenue Bar Chart (pure Flutter — no chart package)
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final List<RevenueTrendPoint> trend;
  final double maxRevenue;
  const _RevenueBarChart({required this.trend, required this.maxRevenue});

  @override
  Widget build(BuildContext context) {
    // Show at most the last 7 days for readability
    final points = trend.length > 7 ? trend.sublist(trend.length - 7) : trend;
    final effectiveMax = maxRevenue > 0 ? maxRevenue : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chart area
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-axis labels
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _YLabel(_formatShort(effectiveMax)),
                      _YLabel(_formatShort(effectiveMax * 0.5)),
                      _YLabel('\u20B90'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bars
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barWidth = math.min(
                        (constraints.maxWidth / points.length) - 6,
                        32.0,
                      );
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: points.map((pt) {
                          final fraction = pt.total / effectiveMax;
                          final barHeight =
                              math.max(fraction * 140, 4.0);
                          return _BarColumn(
                            height: barHeight,
                            width: barWidth,
                            label: _dayLabel(pt.date),
                            amount: pt.total,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  static String _formatShort(double amount) {
    if (amount >= 100000) return '\u20B9${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '\u20B9${(amount / 1000).toStringAsFixed(1)}K';
    return '\u20B9${amount.toStringAsFixed(0)}';
  }
}

class _YLabel extends StatelessWidget {
  final String text;
  const _YLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        color: AppColors.textHint,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final double height;
  final double width;
  final String label;
  final double amount;
  const _BarColumn({
    required this.height,
    required this.width,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '\u20B9${amount.toStringAsFixed(0)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(width / 4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Order Status Card (horizontal bar breakdown)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderStatusCard extends StatelessWidget {
  final List<OrderStatusCount> statuses;
  final int total;
  const _OrderStatusCard({required this.statuses, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < statuses.length; i++) ...[
            _StatusRow(
              status: statuses[i],
              total: total,
              color: _statusColor(statuses[i].status),
            ),
            if (i < statuses.length - 1) const SizedBox(height: AppSizes.sm),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'completed':
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'pending':
        return AppColors.orderPending;
      case 'confirmed':
        return AppColors.orderConfirmed;
      case 'preparing':
        return AppColors.orderPreparing;
      case 'ready':
        return AppColors.orderReady;
      case 'picked':
      case 'on_the_way':
        return AppColors.orderPickedUp;
      case 'refunded':
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }
}

class _StatusRow extends StatelessWidget {
  final OrderStatusCount status;
  final int total;
  final Color color;
  const _StatusRow({
    required this.status,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? status.count / total : 0.0;
    final pct = (fraction * 100).toStringAsFixed(0);

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${status.count}  ($pct%)',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top Selling Items List
// ─────────────────────────────────────────────────────────────────────────────

class _TopItemsList extends StatelessWidget {
  final List<TopSellingItem> items;
  const _TopItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _TopItemTile(item: items[i], rank: i + 1),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.borderLight),
          ],
        ],
      ),
    );
  }
}

class _TopItemTile extends StatelessWidget {
  final TopSellingItem item;
  final int rank;
  const _TopItemTile({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 12,
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? _rankColor(rank).withAlpha(24)
                  : AppColors.borderLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? _rankColor(rank) : AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Item image or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: item.image != null
                ? Image.network(
                    '${ApiEndpoints.baseUrl.replaceAll('/api', '')}${item.image}',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 40,
                      height: 40,
                      color: AppColors.primary.withAlpha(14),
                      child: const Icon(Icons.fastfood_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: AppColors.primary.withAlpha(14),
                    child: const Icon(Icons.fastfood_rounded,
                        size: 20, color: AppColors.primary),
                  ),
          ),
          const SizedBox(width: 12),

          // Name + orders count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.orders} orders',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          // Revenue
          Text(
            '\u20B9${item.revenue.toStringAsFixed(0)}',
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

  static Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFE67E00); // gold
      case 2:
        return AppColors.textSecondary; // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return AppColors.textHint;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Payment Methods Card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodsCard extends StatelessWidget {
  final List<PaymentMethodCount> methods;
  const _PaymentMethodsCard({required this.methods});

  @override
  Widget build(BuildContext context) {
    final total = methods.fold<int>(0, (s, m) => s + m.count);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stacked bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (int i = 0; i < methods.length; i++)
                      Expanded(
                        flex: methods[i].count,
                        child: Container(color: _methodColor(i)),
                      ),
                  ],
                ),
              ),
            ),
          if (total > 0) const SizedBox(height: AppSizes.md),

          // Legend
          Wrap(
            spacing: AppSizes.md,
            runSpacing: AppSizes.sm,
            children: [
              for (int i = 0; i < methods.length; i++)
                _LegendItem(
                  color: _methodColor(i),
                  label: methods[i].displayName,
                  count: methods[i].count,
                  icon: _methodIcon(methods[i].method),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _methodColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.orderPreparing,
    ];
    return colors[index % colors.length];
  }

  static IconData _methodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'card':
        return Icons.credit_card_rounded;
      case 'upi':
        return Icons.phone_android_rounded;
      case 'cod':
      case 'cash':
        return Icons.money_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'net_banking':
      case 'netbanking':
        return Icons.account_balance_rounded;
      default:
        return Icons.payment_rounded;
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final IconData icon;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textHint,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: AppSizes.xl),
          Icon(Icons.analytics_outlined,
              size: 64, color: AppColors.textHint.withAlpha(128)),
          const SizedBox(height: AppSizes.md),
          Text(
            'No analytics data yet',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Analytics will appear once you\nstart receiving orders',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

