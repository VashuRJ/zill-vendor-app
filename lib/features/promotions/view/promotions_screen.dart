import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../viewmodel/promotions_viewmodel.dart';
import 'add_promotion_sheet.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PromotionsViewModel(apiService: apiService),
      child: const _PromotionsBody(),
    );
  }
}

class _PromotionsBody extends StatefulWidget {
  const _PromotionsBody();

  @override
  State<_PromotionsBody> createState() => _PromotionsBodyState();
}

class _PromotionsBodyState extends State<_PromotionsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PromotionsViewModel>().fetchPromotions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Promotions & Offers',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
              child:
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                labelColor: AppColors.surface,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.all(3),
                tabs: [
                  Tab(
                    child: Consumer<PromotionsViewModel>(
                      builder: (_, vm, _) => Text(
                        'Active (${vm.activeCount})',
                      ),
                    ),
                  ),
                  Tab(
                    child: Consumer<PromotionsViewModel>(
                      builder: (_, vm, _) => Text(
                        'Expired (${vm.expired.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Consumer<PromotionsViewModel>(
          builder: (context, vm, _) {
            // ── Loading ─────────────────────────────────────────
            if (vm.status == PromotionsStatus.fetching && !vm.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            // ── Error ───────────────────────────────────────────
            if (vm.status == PromotionsStatus.error && !vm.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 52,
                        color: AppColors.textHint.withAlpha(100),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        vm.errorMessage ?? 'Something went wrong',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: vm.fetchPromotions,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            // ── Data ────────────────────────────────────────────
            return Column(
              children: [
                const SizedBox(height: AppSizes.md),
                // Stats Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSizes.md),
                  child: _StatsRow(
                    activeCount: vm.activeCount,
                    totalUses: vm.totalUses,
                    totalPromos: vm.active.length + vm.expired.length,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      _PromoList(type: _PromoTabType.active),
                      _PromoList(type: _PromoTabType.expired),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'New Offer',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PromotionsViewModel>(),
        child: const AddPromotionSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int activeCount;
  final int totalUses;
  final int totalPromos;

  const _StatsRow({
    required this.activeCount,
    required this.totalUses,
    required this.totalPromos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.local_offer_rounded,
          color: AppColors.success,
          label: 'Active',
          value: '$activeCount',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.people_rounded,
          color: AppColors.primary,
          label: 'Total Uses',
          value: '$totalUses',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.inventory_2_rounded,
          color: AppColors.purple,
          label: 'Total',
          value: '$totalPromos',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Promo List (Active / Expired tabs)
// ─────────────────────────────────────────────────────────────────────────────

enum _PromoTabType { active, expired }

class _PromoList extends StatelessWidget {
  final _PromoTabType type;
  const _PromoList({required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<PromotionsViewModel>(
      builder: (context, vm, _) {
        final list =
            type == _PromoTabType.active ? vm.active : vm.expired;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type == _PromoTabType.active
                      ? Icons.local_offer_outlined
                      : Icons.history_rounded,
                  size: 56,
                  color: AppColors.textHint.withAlpha(80),
                ),
                const SizedBox(height: 12),
                Text(
                  type == _PromoTabType.active
                      ? 'No active promotions'
                      : 'No expired promotions',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type == _PromoTabType.active
                      ? 'Create your first offer to attract more customers!'
                      : 'Your past promotions will appear here',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint.withAlpha(160),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: vm.fetchPromotions,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              0,
              AppSizes.md,
              100,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _CouponCard(
              promo: list[i],
              onToggle: () => vm.togglePromo(list[i].id),
              onDelete: () => _confirmDelete(context, vm, list[i]),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    PromotionsViewModel vm,
    Promotion promo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Promotion?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Are you sure you want to delete "${promo.code}"? This action cannot be undone.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.deletePromo(promo.id);
            },
            child: const Text(
              'Delete',
              style:
                  TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Coupon Card — the premium dashed-border coupon look
// ─────────────────────────────────────────────────────────────────────────────

class _CouponCard extends StatelessWidget {
  final Promotion promo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CouponCard({
    required this.promo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = promo.isActive && !promo.isExpired;
    final accent = isActive ? AppColors.primary : AppColors.textHint;

    // Display value: "50%" for percentage, "₹120" for flat
    final discountLabel = promo.discountType == 'flat'
        ? '\u20b9${promo.discountValue.toInt()}'
        : '${promo.discountValue.toInt()}%';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? AppColors.primary.withAlpha(15)
                : AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top: Discount badge + Code ──────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                // Discount circle
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.primaryDark],
                          )
                        : null,
                    color: isActive ? null : AppColors.background,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    discountLabel,
                    style: TextStyle(
                      fontSize: promo.discountType == 'flat' ? 15 : 18,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : AppColors.textHint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Code + Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dashed code badge
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: promo.code),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${promo.code} copied!',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: CustomPaint(
                          painter: _DashedBorderPainter(
                            color: accent.withAlpha(80),
                            radius: 6,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.content_copy_rounded,
                                  size: 12,
                                  color: accent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  promo.code,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        promo.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Toggle / More
                Column(
                  children: [
                    SizedBox(
                      height: 28,
                      child: Switch(
                        value: promo.isActive,
                        onChanged: (_) => onToggle(),
                        activeTrackColor: AppColors.success.withAlpha(80),
                        activeThumbColor: AppColors.success,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.textHint.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider with half-circle notches ────────────────────
          SizedBox(
            height: 20,
            child: CustomPaint(
              size: const Size(double.infinity, 20),
              painter: _NotchedDividerPainter(
                color: AppColors.borderLight,
                bgColor: AppColors.background,
              ),
            ),
          ),

          // ── Bottom: Meta info + Usage bar ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.shopping_bag_outlined,
                      label:
                          'Min \u20b9${promo.minOrderAmount.toInt()}',
                    ),
                    const SizedBox(width: 10),
                    if (promo.maxDiscount != null)
                      _MetaChip(
                        icon: Icons.savings_outlined,
                        label:
                            'Max \u20b9${promo.maxDiscount!.toInt()} off',
                      ),
                    const Spacer(),
                    _MetaChip(
                      icon: isActive
                          ? Icons.schedule_rounded
                          : Icons.event_busy_rounded,
                      label: isActive
                          ? '${promo.daysLeft}d left'
                          : 'Expired',
                      color: isActive ? AppColors.info : AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Usage bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: promo.usagePercent,
                          backgroundColor: AppColors.borderLight,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textHint,
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${promo.usageCount}/${promo.usageLimit ?? '\u221e'} used',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: c,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Dashed rectangular border around the coupon code badge.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, this.radius = 6});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}

/// Draws a dashed horizontal line with half-circle notches on left and right
/// to give the coupon a "tear-off" look.
class _NotchedDividerPainter extends CustomPainter {
  final Color color;
  final Color bgColor;

  _NotchedDividerPainter({required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const notchRadius = 10.0;

    // Left notch
    canvas.drawCircle(
      Offset(0, y),
      notchRadius,
      Paint()..color = bgColor,
    );
    // Right notch
    canvas.drawCircle(
      Offset(size.width, y),
      notchRadius,
      Paint()..color = bgColor,
    );

    // Dashed line between notches
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = notchRadius + 4;
    final endX = size.width - notchRadius - 4;
    while (x < endX) {
      final end = math.min(x + dashWidth, endX);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x = end + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _NotchedDividerPainter old) => false;
}
