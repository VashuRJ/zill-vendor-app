import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../viewmodel/dashboard_viewmodel.dart';
import '../../home/view/app_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboard),
        actions: [
          Consumer<DashboardViewModel>(
            builder: (_, vm, _) {
              final count = vm.unreadNotifications;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRouter.notifications);
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, vm, _) {
          // ── Full-screen error (only when no data at all) ──────────
          if (vm.status == DashboardStatus.error && !vm.hasData) {
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
                      vm.errorMessage ?? 'Something went wrong',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    ElevatedButton.icon(
                      onPressed: vm.fetchDashboard,
                      icon: const Icon(Icons.refresh),
                      label: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: vm.fetchDashboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 0. Greeting header ───────────────────────────────
                  _GreetingHeader(storeName: vm.data.storeName),
                  const SizedBox(height: AppSizes.md),

                  // ── 1. Premium Online/Offline Toggle ────────────────
                  vm.isLoading
                      ? const ShimmerCard(height: 110)
                      : _StoreToggleCard(vm: vm),

                  const SizedBox(height: AppSizes.md),

                  // ── Error snackbar-style inline message ─────────────
                  if (vm.errorMessage != null && vm.hasData)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: _InlineError(
                        message: vm.errorMessage!,
                        onDismiss: vm.clearError,
                      ),
                    ),

                  // ── Pending orders alert ─────────────────────────────
                  if (!vm.isLoading && vm.pendingCount > 0)
                    _PendingOrdersAlert(
                      count: vm.pendingCount,
                      onTap: () => AppShell.switchTab(context, 1),
                    ),

                  if (!vm.isLoading && vm.pendingCount > 0)
                    const SizedBox(height: AppSizes.md),

                  // ── 2. Quick Stats ──────────────────────────────────
                  Text(
                    "Today's Overview",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSizes.md),

                  vm.isLoading
                      ? const ShimmerGrid(itemCount: 4, itemHeight: 110)
                      : _QuickStatsGrid(
                          data: vm.data, pendingCount: vm.pendingCount),

                  const SizedBox(height: AppSizes.lg),

                  // ── 3. Recent Activity ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (vm.recentOrders.isNotEmpty)
                        TextButton(
                          onPressed: () => AppShell.switchTab(context, 1),
                          child: const Text(AppStrings.viewAll),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),

                  vm.isLoading
                      ? const ShimmerList(itemCount: 3, itemHeight: 72)
                      : vm.recentOrders.isEmpty
                          ? const _EmptyActivity()
                          : _RecentActivityList(orders: vm.recentOrders),

                  // Bottom safe-area padding
                  const SizedBox(height: AppSizes.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pending Orders Alert Banner
// ─────────────────────────────────────────────────────────────────────────────

class _PendingOrdersAlert extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingOrdersAlert({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: const Color(0xFFFFCA28)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count new order${count == 1 ? '' : 's'} waiting!',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const Text(
                    'Tap to review and accept',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  0. Greeting Header
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String storeName;
  const _GreetingHeader({required this.storeName});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (storeName.isNotEmpty)
                Text(
                  storeName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            DateFormat('EEE, d MMM').format(DateTime.now()),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  1. Premium Online/Offline Toggle Card
// ─────────────────────────────────────────────────────────────────────────────

class _StoreToggleCard extends StatefulWidget {
  final DashboardViewModel vm;
  const _StoreToggleCard({required this.vm});

  @override
  State<_StoreToggleCard> createState() => _StoreToggleCardState();
}

class _StoreToggleCardState extends State<_StoreToggleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final isOpen = vm.data.isStoreOpen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOpen
              ? [const Color(0xFF00B894), const Color(0xFF00A381)]
              : [const Color(0xFF636E72), const Color(0xFF2D3436)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? AppColors.success : AppColors.textSecondary)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          children: [
            // ── Pulsing status dot ────────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, _) => Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: isOpen ? _pulseAnimation.value : 0.5,
                  ),
                  boxShadow: isOpen
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: _pulseAnimation.value * 0.5,
                            ),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.md),

            // ── Text content ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'Accepting Orders' : 'Currently Offline',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (vm.data.storeName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      vm.data.storeName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                  if (vm.data.todayOpenTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${vm.data.todayOpenTime} – ${vm.data.todayCloseTime}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Toggle switch ─────────────────────────────────────
            vm.isToggling
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: isOpen,
                      onChanged:
                          vm.isLoading ? null : (_) => vm.toggleStore(),
                      activeThumbColor: Colors.white,
                      activeTrackColor:
                          Colors.white.withValues(alpha: 0.35),
                      inactiveThumbColor:
                          Colors.white.withValues(alpha: 0.9),
                      inactiveTrackColor:
                          Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  2. Quick Stats 2x2 Grid
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatsGrid extends StatelessWidget {
  final DashboardData data;
  final int pendingCount;
  const _QuickStatsGrid({required this.data, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSizes.md,
      crossAxisSpacing: AppSizes.md,
      childAspectRatio: 1.25,
      children: [
        StatCard(
          title: AppStrings.todayOrders,
          value: data.todayOrders.toString(),
          icon: Icons.shopping_bag_rounded,
          gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        StatCard(
          title: AppStrings.todayRevenue,
          value: '\u20B9${data.todayRevenue.toStringAsFixed(0)}',
          icon: Icons.currency_rupee_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
        ),
        StatCard(
          title: 'Pending',
          value: pendingCount.toString(),
          icon: Icons.pending_actions_rounded,
          gradient: pendingCount > 0
              ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
              : const [Color(0xFF94A3B8), Color(0xFF64748B)],
        ),
        StatCard(
          title: AppStrings.rating,
          value: data.rating > 0 ? data.rating.toStringAsFixed(1) : '—',
          icon: Icons.star_rounded,
          gradient: const [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  3. Recent Activity List
// ─────────────────────────────────────────────────────────────────────────────

class _RecentActivityList extends StatelessWidget {
  final List<RecentOrder> orders;
  const _RecentActivityList({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => _RecentOrderTile(order: orders[i]),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final RecentOrder order;
  const _RecentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm + 4),
      child: Row(
        children: [
          // ── Status icon ──────────────────────────────────
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor(order.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(
              _statusIcon(order.status),
              color: _statusColor(order.status),
              size: 22,
            ),
          ),
          const SizedBox(width: AppSizes.md),

          // ── Order info ───────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    const Spacer(),
                    Text(
                      '\u20B9${order.totalAmount.toStringAsFixed(0)}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order.customerName}  \u2022  '
                        '${order.itemsCount} item${order.itemsCount == 1 ? '' : 's'}  \u2022  '
                        '${_timeAgo(order.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    _StatusBadge(
                        status: order.status, label: order.statusDisplay),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  const _StatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state when no recent orders
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            AppStrings.noOrdersYet,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Inline error banner (when data exists but refresh failed)
// ─────────────────────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _InlineError({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child:
                const Icon(Icons.close, size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared status helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status) {
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
    case 'delivered':
      return AppColors.orderDelivered;
    case 'cancelled':
    case 'refunded':
      return AppColors.orderCancelled;
    default:
      return AppColors.textSecondary;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'pending':
      return Icons.schedule_rounded;
    case 'confirmed':
      return Icons.check_circle_outline;
    case 'preparing':
      return Icons.restaurant_rounded;
    case 'ready':
      return Icons.check_circle_rounded;
    case 'picked':
    case 'on_the_way':
      return Icons.delivery_dining_rounded;
    case 'delivered':
      return Icons.done_all_rounded;
    case 'cancelled':
    case 'refunded':
      return Icons.cancel_outlined;
    default:
      return Icons.receipt_long_rounded;
  }
}
