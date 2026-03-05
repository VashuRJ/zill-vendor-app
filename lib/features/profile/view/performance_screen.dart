import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/performance_viewmodel.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PerformanceViewModel>().fetchAll();
    });
  }

  // Returns background + foreground color pair for health status
  static (Color bg, Color fg) _healthColors(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return (const Color(0xFF00B894), Colors.white);
      case 'good':
        return (const Color(0xFF00CEC9), Colors.white);
      case 'average':
        return (const Color(0xFFF39C12), Colors.white);
      case 'poor':
        return (const Color(0xFFE17055), Colors.white);
      case 'critical':
        return (const Color(0xFFD63031), Colors.white);
      default:
        return (AppColors.border, AppColors.textPrimary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance & Penalties'),
        actions: [
          Consumer<PerformanceViewModel>(
            builder: (context, vm, _) => IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Refresh',
              onPressed: vm.isLoading ? null : vm.fetchAll,
            ),
          ),
        ],
      ),
      body: Consumer<PerformanceViewModel>(
        builder: (context, vm, _) {
          if (vm.status == PerformanceStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.status == PerformanceStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 56,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      vm.errorMessage ?? 'Failed to load performance data',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.md),
                    ElevatedButton.icon(
                      onPressed: vm.fetchAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (vm.status == PerformanceStatus.initial) {
            return const SizedBox.shrink();
          }

          final m = vm.metrics;
          final r = vm.ratings;
          final ps = vm.penaltySummary;
          final (healthBg, healthFg) = _healthColors(m.healthStatus);

          return RefreshIndicator(
            onRefresh: vm.fetchAll,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSizes.xl),
              children: [
                // ── Health Banner ──────────────────────────────────────────
                Container(
                  color: healthBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _healthIcon(m.healthStatus),
                        color: healthFg,
                        size: 28,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Store Health: ${m.healthStatus.toUpperCase()}',
                              style: TextStyle(
                                color: healthFg,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            if (m.isSuspended)
                              Text(
                                m.suspendedUntil != null
                                    ? 'Suspended until ${_formatDate(m.suspendedUntil!)}'
                                    : 'Account suspended',
                                style: TextStyle(
                                  color: healthFg.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _ScoreBadge(score: m.performanceScore, fg: healthFg),
                    ],
                  ),
                ),

                // ── Suspension Warning ─────────────────────────────────────
                if (m.isSuspended)
                  Container(
                    margin: const EdgeInsets.fromLTRB(
                      AppSizes.md,
                      AppSizes.md,
                      AppSizes.md,
                      0,
                    ),
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.block_outlined,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            m.suspensionReason.isNotEmpty
                                ? m.suspensionReason
                                : 'Your store is currently suspended.',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSizes.md),

                // ── Score + Rating Row ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Performance Score',
                          value: m.performanceScore.toStringAsFixed(1),
                          suffix: '/100',
                          icon: Icons.stars_rounded,
                          iconColor: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _MetricCard(
                          label: 'Avg Rating',
                          value: r.avgRestaurantRating.toStringAsFixed(1),
                          suffix: '/5',
                          icon: Icons.star_rounded,
                          iconColor: AppColors.warning,
                          sub: '${r.totalReviews} reviews',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.sm),

                // ── 30-Day Metrics ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: _SectionHeader('Last 30 Days'),
                ),
                const SizedBox(height: AppSizes.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSizes.sm,
                    mainAxisSpacing: AppSizes.sm,
                    childAspectRatio: 2.4,
                    children: [
                      _MetricCard(
                        label: 'Total Orders',
                        value: m.totalOrders30d.toString(),
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.primary,
                      ),
                      _MetricCard(
                        label: 'Completed',
                        value: m.completedOrders30d.toString(),
                        icon: Icons.check_circle_outline,
                        iconColor: AppColors.success,
                      ),
                      _MetricCard(
                        label: 'Acceptance Rate',
                        value: '${m.acceptanceRate.toStringAsFixed(1)}%',
                        icon: Icons.thumb_up_alt_outlined,
                        iconColor: AppColors.success,
                      ),
                      _MetricCard(
                        label: 'Completion Rate',
                        value: '${m.completionRate.toStringAsFixed(1)}%',
                        icon: Icons.done_all_outlined,
                        iconColor: AppColors.success,
                      ),
                      _MetricCard(
                        label: 'Cancellation',
                        value: '${m.cancellationRate.toStringAsFixed(1)}%',
                        icon: Icons.cancel_outlined,
                        iconColor: AppColors.error,
                      ),
                      _MetricCard(
                        label: 'Active Strikes',
                        value: m.activeStrikes.toString(),
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.warning,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.md),

                // ── Rating Breakdown ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: _SectionHeader('Rating Breakdown'),
                ),
                const SizedBox(height: AppSizes.xs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: _RatingBreakdownCard(r: r),
                ),

                const SizedBox(height: AppSizes.md),

                // ── Penalty Summary ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: _SectionHeader('Penalty Summary'),
                ),
                const SizedBox(height: AppSizes.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: Row(
                    children: [
                      _PenaltyChip(
                        label: 'Total',
                        count: ps.totalPenalties,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      _PenaltyChip(
                        label: 'Warnings',
                        count: ps.totalWarnings,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      _PenaltyChip(
                        label: 'Fines',
                        count: ps.totalFines,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      _PenaltyChip(
                        label: 'Suspensions',
                        count: ps.totalSuspensions,
                        color: const Color(0xFFB71C1C),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      _PenaltyChip(
                        label: 'Unresolved',
                        count: ps.unresolvedCount,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
                if (ps.totalAmountDeducted > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.md,
                      AppSizes.xs,
                      AppSizes.md,
                      0,
                    ),
                    child: Text(
                      'Total deducted: ₹${ps.totalAmountDeducted.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: AppSizes.md),

                // ── Penalty History ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: _SectionHeader(
                    'Penalty History (${vm.penalties.length})',
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                if (vm.penalties.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSizes.md),
                    child: _EmptyPenalties(),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                    itemCount: vm.penalties.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (_, i) =>
                        _PenaltyCard(penalty: vm.penalties[i]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _healthIcon(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return Icons.sentiment_very_satisfied_rounded;
      case 'good':
        return Icons.sentiment_satisfied_rounded;
      case 'average':
        return Icons.sentiment_neutral_rounded;
      case 'poor':
        return Icons.sentiment_dissatisfied_rounded;
      case 'critical':
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.info_outlined;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final double score;
  final Color fg;

  const _ScoreBadge({required this.score, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        '${score.toStringAsFixed(0)}/100',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final String? sub;
  final IconData icon;
  final Color iconColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.suffix,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: AppSizes.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (suffix != null)
                      Text(
                        suffix!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null)
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
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

class _RatingBreakdownCard extends StatelessWidget {
  final RatingBreakdown r;
  const _RatingBreakdownCard({required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RatingStat(label: 'Restaurant', value: r.avgRestaurantRating),
              _RatingStat(label: 'Food', value: r.avgFoodRating),
              _RatingStat(label: 'Delivery', value: r.avgDeliveryRating),
            ],
          ),
          const Divider(height: AppSizes.lg),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = r.distribution[star] ?? 0;
            final total = r.totalReviews;
            final frac = total > 0 ? count / total : 0.0;
            return _StarBar(star: star, frac: frac, count: count);
          }),
        ],
      ),
    );
  }
}

class _RatingStat extends StatelessWidget {
  final String label;
  final double value;
  const _RatingStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 2),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _StarBar extends StatelessWidget {
  final int star;
  final double frac;
  final int count;
  const _StarBar({required this.star, required this.frac, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: const TextStyle(fontSize: 12)),
          const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
          const SizedBox(width: AppSizes.xs),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.warning,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

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

class _PenaltyChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _PenaltyChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _PenaltyCard extends StatelessWidget {
  final PenaltyRecord penalty;
  const _PenaltyCard({required this.penalty});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _severityColors(penalty.severity);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  penalty.severityDisplay.isNotEmpty
                      ? penalty.severityDisplay
                      : penalty.severity,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              if (penalty.strikeNumber > 0)
                Text(
                  'Strike #${penalty.strikeNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              const Spacer(),
              if (penalty.isResolved)
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.success,
                ),
              if (!penalty.isResolved)
                const Icon(
                  Icons.radio_button_unchecked,
                  size: 16,
                  color: AppColors.error,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            penalty.penaltyTypeDisplay.isNotEmpty
                ? penalty.penaltyTypeDisplay
                : penalty.penaltyType,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          if (penalty.reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              penalty.reason,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              if (penalty.penaltyAmount > 0)
                _Tag(
                  Icons.currency_rupee_rounded,
                  '₹${penalty.penaltyAmount.toStringAsFixed(0)}',
                  AppColors.error,
                ),
              if (penalty.orderNumber != null) ...[
                const SizedBox(width: AppSizes.sm),
                _Tag(
                  Icons.receipt_outlined,
                  penalty.orderNumber!,
                  AppColors.primary,
                ),
              ],
              const Spacer(),
              Text(
                _formatDate(penalty.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── static helpers inside _PenaltyCard ──────────────────────────────────
  static (Color bg, Color fg) _severityColors(String severity) {
    switch (severity.toLowerCase()) {
      case 'warning':
        return (AppColors.warningLight, AppColors.warning);
      case 'fine':
        return (AppColors.errorLight, AppColors.error);
      case 'suspension':
        return (const Color(0xFFFDE8E8), const Color(0xFFB71C1C));
      case 'deactivation':
        return (const Color(0xFF2D3436), Colors.white);
      default:
        return (AppColors.borderLight, AppColors.textPrimary);
    }
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Tag(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyPenalties extends StatelessWidget {
  const _EmptyPenalties();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.shield_outlined, size: 48, color: AppColors.success),
          SizedBox(height: AppSizes.sm),
          Text(
            'No penalties on record',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Keep up the great work!',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
