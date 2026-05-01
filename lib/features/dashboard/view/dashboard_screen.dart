// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/verification_status.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../../profile/viewmodel/profile_viewmodel.dart';
import '../../profile/widgets/complete_profile_sheet.dart';
import '../../profile/widgets/kyc_warning_banner.dart';
import '../viewmodel/dashboard_viewmodel.dart';
import '../widgets/notification_permission_banner.dart';
import '../../home/view/app_shell.dart';
import '../../orders/view/order_detail_screen.dart';
import '../../orders/viewmodel/orders_viewmodel.dart';
import '../../orders/widgets/prep_countdown_chip.dart';
import '../../../shared/widgets/accept_order_dialog.dart';

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

                  // ── 0-pre. Notification permission (Android 13+) ────
                  // Surfaces when the vendor has denied/revoked
                  // POST_NOTIFICATIONS so they know WHY order alerts
                  // aren't coming through. Tap → request / open settings.
                  const NotificationPermissionBanner(),

                  // ── 0a. Verification banner (hidden when approved) ───
                  // Mirrors web dashboard.html updateVerificationBanner()
                  // — 4 states: Documents Required / Verification In
                  // Progress / Under Review / Verification Failed.
                  if (!vm.isLoading && !vm.verificationStatus.hideBanner)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: KycWarningBanner(
                        status: vm.verificationStatus,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRouter.kycDocuments,
                        ),
                      ),
                    ),

                  // ── 0b. Profile completion banner ──────────────────
                  // Hidden once the backend reports 100%. Tap → opens
                  // the shared "Complete your profile" bottom sheet
                  // with a list of every missing setup task.
                  if (!vm.isLoading && vm.data.profileCompletion < 100)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.md),
                      child: _DashboardProfileCompletionCard(
                        percentage: vm.data.profileCompletion,
                      ),
                    ),

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

                  // ── 1b. Live Orders (quick actions) ────────────────
                  if (!vm.isLoading)
                    Consumer<OrdersViewModel>(
                      builder: (context, ordersVm, _) {
                        final pending = ordersVm.newOrders
                            .where((o) => o.status == 'pending')
                            .toList();
                        final inProgress = [
                          ...ordersVm.newOrders
                              .where((o) => o.status == 'confirmed'),
                          ...ordersVm.preparingOrders,
                        ];
                        if (pending.isEmpty && inProgress.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── New Orders (pending) ──
                            if (pending.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.notifications_active_rounded,
                                iconColor: AppColors.error,
                                title: 'New Orders',
                                count: pending.length,
                                badgeColor: AppColors.error,
                              ),
                              const SizedBox(height: AppSizes.sm),
                              ...pending.map(
                                (order) => _LiveOrderCard(
                                  order: order,
                                  ordersVm: ordersVm,
                                ),
                              ),
                              const SizedBox(height: AppSizes.md),
                            ],
                            // ── In Progress (confirmed + preparing) ──
                            if (inProgress.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.restaurant_rounded,
                                iconColor: AppColors.orderPreparing,
                                title: 'In Progress',
                                count: inProgress.length,
                                badgeColor: AppColors.orderPreparing,
                              ),
                              const SizedBox(height: AppSizes.sm),
                              ...inProgress.map(
                                (order) => _LiveOrderCard(
                                  order: order,
                                  ordersVm: ordersVm,
                                ),
                              ),
                              const SizedBox(height: AppSizes.md),
                            ],
                          ],
                        );
                      },
                    ),

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
    // Toggle is gated on KYC approval (+ admin-controlled is_active).
    // When locked we force-render the offline/grey treatment regardless
    // of the persisted `store_status`, so the UI never implies the
    // store is accepting orders while the backend will reject attempts.
    final isLocked = !vm.canAcceptOrders;
    final isOnline = !isLocked && vm.data.isStoreOpen;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOnline
              ? const [Color(0xFF00B894), Color(0xFF00A381)]
              : const [Color(0xFF636E72), Color(0xFF2D3436)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppColors.success : AppColors.textSecondary)
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
            // ── Pulsing status dot / lock badge ─────────────
            if (isLocked)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              )
            else
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, _) => Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: isOnline ? _pulseAnimation.value : 0.5,
                    ),
                    boxShadow: isOnline
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

            // ── Text content ───────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLocked
                        ? 'Verification Required'
                        : (isOnline
                            ? 'Accepting Orders'
                            : 'Currently Offline'),
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(height: 2),
                    Text(
                      _lockedSubtitle(vm.verificationStatus, vm.data.isActive),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ] else if (vm.data.storeName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      vm.data.storeName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                  if (!isLocked && vm.data.todayOpenTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${vm.data.todayOpenTime} – ${vm.data.todayCloseTime}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Toggle switch / lock indicator / spinner ──
            if (vm.isToggling)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            else if (isLocked)
              // Chevron hints the whole card is tappable and leads
              // somewhere (KYC screen) rather than flipping state.
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 28,
              )
            else
              Switch(
                value: isOnline,
                onChanged: vm.isLoading || vm.isToggling
                    ? null
                    : (_) => vm.toggleStore(),
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.4),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              ),
          ],
        ),
      ),
    );

    if (!isLocked) return card;

    // Locked: the whole card becomes a tap target that routes to the
    // KYC Documents screen so the vendor can resolve verification.
    // admin-disabled (is_active=false) is a separate, rarer case where
    // uploading docs won't help — we route there anyway because it's
    // still the most actionable screen from the dashboard.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        onTap: () => _onLockedTap(context, vm),
        child: card,
      ),
    );
  }

  void _onLockedTap(BuildContext context, DashboardViewModel vm) {
    final status = vm.verificationStatus;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    // Admin-disabled: nothing the vendor can do, just inform.
    if (!vm.data.isActive) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your restaurant has been disabled by admin. Contact support.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // KYC-related lock — route to docs.
    messenger.showSnackBar(
      SnackBar(
        content: Text(status.bannerMessage),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pushNamed(context, AppRouter.kycDocuments);
  }

  String _lockedSubtitle(VerificationStatus status, bool isActive) {
    if (!isActive) {
      return 'Your restaurant is disabled. Contact support.';
    }
    switch (status) {
      case VerificationStatus.pending:
        return 'Upload documents to unlock';
      case VerificationStatus.submitted:
      case VerificationStatus.underReview:
        return 'Documents under review (24-48 hrs)';
      case VerificationStatus.rejected:
        return 'Documents rejected — tap to re-upload';
      case VerificationStatus.approved:
        return 'Awaiting activation';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashboard Profile Completion Card
//
//  Tappable banner that opens the shared "Complete your profile" bottom
//  sheet (lib/features/profile/widgets/complete_profile_sheet.dart).
//  Shown only while the backend reports profile_completion < 100.
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardProfileCompletionCard extends StatelessWidget {
  final int percentage;
  const _DashboardProfileCompletionCard({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final pct = (percentage / 100).clamp(0.0, 1.0);
    final barColor = pct < 0.5
        ? AppColors.warning
        : pct < 0.8
            ? AppColors.primary
            : AppColors.success;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () {
          // Kick the profile fetch in case the user landed on the
          // dashboard before the profile screen ever loaded — sheet
          // uses Consumer so it'll auto-update when fresh data arrives.
          context.read<ProfileViewModel>().fetchProfile();
          showCompleteProfileSheet(context);
        },
        child: Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Complete your Setup',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: barColor.withAlpha(28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: barColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap to see what\'s left and finish your setup.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
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
          // GMV, not payout — warn vendors before they count this as
          // take-home money. Phrasing mirrors the web dashboard note.
          infoMessage: 'Subtotal of paid orders. Commission + GST are '
              'deducted in your weekly settlement.',
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

// ─────────────────────────────────────────────────────────────────────────────
//  Live Order Card with Quick Actions
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final Color badgeColor;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveOrderCard extends StatelessWidget {
  final VendorOrder order;
  final OrdersViewModel ordersVm;
  const _LiveOrderCard({required this.order, required this.ordersVm});

  @override
  Widget build(BuildContext context) {
    final isLoading = ordersVm.isActionLoading(order.id);
    final statusColor = _statusColor(order.status);
    final timeStr = DateFormat('h:mm a').format(order.createdAt.toLocal());

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order, vm: ordersVm),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: ID + Time ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusMd),
                  topRight: Radius.circular(AppSizes.radiusMd),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_statusIcon(order.status),
                          size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'ID: ${order.id}  ${order.orderNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Countdown on its own line — prevents "Overdue +MM:SS"
                  // from squeezing the order number out of the header.
                  if (order.status == 'confirmed' ||
                      order.status == 'preparing') ...[
                    const SizedBox(height: 6),
                    PrepCountdownChip(orderId: order.id),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Customer name ──
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: order.paymentStatus == 'paid'
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.paymentStatus == 'paid' ? 'PAID' : 'COD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: order.paymentStatus == 'paid'
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Items list ──
                  ...order.items.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6,
                                color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.quantity} x ${item.itemName}',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '\u20B9${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (order.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+${order.items.length - 3} more item${order.items.length - 3 == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  // ── Special instructions ──
                  if (order.instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.instructions,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ── Total + Items count ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${order.itemsCount} item${order.itemsCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Total: \u20B9${order.totalAmount.toStringAsFixed(order.totalAmount == order.totalAmount.roundToDouble() ? 0 : 2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Quick action button ──
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: _buildActionButton(context, isLoading),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcceptDialog(BuildContext context) {
    showAcceptOrderDialog(
      context: context,
      order: order,
      onAccept: (prepTime) async {
        await ordersVm.acceptOrder(order.id, estimatedPrepTime: prepTime);
        if (context.mounted) {
          context.read<DashboardViewModel>().fetchDashboard();
        }
      },
    );
  }

  Widget _buildActionButton(BuildContext context, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    switch (order.status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              flex: 1,
              child: _ActionBtn(
                label: 'Reject',
                icon: Icons.close_rounded,
                color: AppColors.error,
                outlined: true,
                onTap: () => ordersVm.rejectOrder(order.id,
                    reason: 'Rejected from dashboard'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _ActionBtn(
                label: 'Accept Order',
                icon: Icons.check_rounded,
                color: AppColors.success,
                onTap: () => _showAcceptDialog(context),
              ),
            ),
          ],
        );
      case 'confirmed':
        return _ActionBtn(
          label: 'Start Preparing',
          icon: Icons.restaurant_rounded,
          color: AppColors.orderPreparing,
          onTap: () => ordersVm.startPreparing(order.id),
        );
      case 'preparing':
        return _ActionBtn(
          label: 'Mark Food Ready',
          icon: Icons.check_circle_rounded,
          color: AppColors.orderReady,
          onTap: () => ordersVm.markReady(order.id),
        );
      default:
        return _StatusBadge(status: order.status, label: order.status);
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final RecentOrder order;
  const _RecentOrderTile({required this.order});

  void _openOrderDetail(BuildContext context) {
    final ordersVm = context.read<OrdersViewModel>();
    final fullOrder = ordersVm.findOrderById(order.id);
    if (fullOrder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: fullOrder, vm: ordersVm),
        ),
      );
    } else {
      // Order not in memory — switch to Orders tab
      AppShell.switchTab(context, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openOrderDetail(context),
      child: Padding(
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

class _InlineError extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _InlineError({required this.message, required this.onDismiss});

  @override
  State<_InlineError> createState() => _InlineErrorState();
}

class _InlineErrorState extends State<_InlineError> {
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(const Duration(seconds: 4), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

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
              widget.message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
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
