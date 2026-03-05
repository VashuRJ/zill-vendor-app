import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../shared/widgets/shimmer_widgets.dart';
import '../viewmodel/notifications_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsViewModel _vm;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = NotificationsViewModel(
      apiService: context.read<ApiService>(),
    );
    _vm.fetchNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _vm.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            Consumer<NotificationsViewModel>(
              builder: (_, vm, _) {
                if (vm.unreadCount == 0) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  tooltip: 'Mark all as read',
                  onPressed: vm.markAllAsRead,
                );
              },
            ),
          ],
        ),
        body: Consumer<NotificationsViewModel>(
          builder: (context, vm, _) {
            // ── Loading ──────────────────────────────────────
            if (vm.isLoading) {
              return const ShimmerList(itemCount: 8, itemHeight: 76);
            }

            // ── Error ────────────────────────────────────────
            if (vm.status == NotificationsStatus.error &&
                !vm.hasNotifications) {
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
                        vm.error ?? 'Something went wrong',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      ElevatedButton.icon(
                        onPressed: vm.fetchNotifications,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ── Empty ────────────────────────────────────────
            if (!vm.hasNotifications) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 64,
                        color: AppColors.textHint.withValues(alpha: 0.5)),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      'No notifications yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      "You'll see order updates, reviews,\nand alerts here",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }

            // ── Notification List ────────────────────────────
            final items = vm.notifications;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: vm.refresh,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length + (vm.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // ── Load-more indicator ─────────────────────
                  if (index == items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSizes.lg),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final n = items[index];

                  // ── Date header ─────────────────────────────
                  Widget? header;
                  if (index == 0 ||
                      !_isSameDay(
                          items[index - 1].createdAt, n.createdAt)) {
                    header = Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.xs),
                      child: Text(
                        _dateLabel(n.createdAt),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ?header,
                      Dismissible(
                        key: ValueKey(n.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.only(right: AppSizes.lg),
                          color: AppColors.error,
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => vm.deleteNotification(n.id),
                        child: _NotificationTile(
                          notification: n,
                          onTap: () {
                            // Delete notification (read = done, no need to keep)
                            vm.deleteNotification(n.id);
                            // Navigate to the linked order if available
                            if (n.orderId != null) {
                              final pushService =
                                  context.read<PushNotificationService>();
                              Navigator.of(context).pop();
                              pushService.onNavigateToOrder?.call(n.orderId!);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Today';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Notification Tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final iconData = _iconFor(n.type);
    final iconColor = _colorFor(n.type);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: n.isRead ? null : AppColors.infoLight.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: AppSizes.sm + 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Unread dot ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: n.isRead ? Colors.transparent : AppColors.primary,
                ),
              ),
            ),

            // ── Type icon ─────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSizes.sm + 4),

            // ── Content ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    n.isRead ? FontWeight.w500 : FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        n.timeAgo.isNotEmpty ? n.timeAgo : _timeAgo(n.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textHint,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.message,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
    if (diff.inDays == 1) return '1d ago';
    return '${diff.inDays}d ago';
  }

  static IconData _iconFor(String type) {
    if (type.contains('new_order') || type == 'order_placed') {
      return Icons.shopping_bag_rounded;
    }
    if (type == 'order_confirmed' ||
        type == 'order_preparing' ||
        type == 'order_ready') {
      return Icons.restaurant_rounded;
    }
    if (type == 'order_cancelled') return Icons.cancel_outlined;
    if (type == 'order_delivered') return Icons.done_all_rounded;
    if (type.contains('payment') || type.contains('refund')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (type == 'review_received') return Icons.star_rounded;
    if (type.contains('scheduled')) return Icons.event_rounded;
    if (type.contains('kyc') || type.contains('account')) {
      return Icons.verified_user_outlined;
    }
    if (type == 'system' || type == 'promotion') {
      return Icons.campaign_rounded;
    }
    return Icons.notifications_rounded;
  }

  static Color _colorFor(String type) {
    if (type.contains('new_order') || type == 'order_placed') {
      return AppColors.info;
    }
    if (type == 'order_confirmed' ||
        type == 'order_preparing' ||
        type == 'order_ready' ||
        type == 'order_delivered') {
      return AppColors.success;
    }
    if (type == 'order_cancelled') return AppColors.error;
    if (type.contains('payment') || type.contains('refund')) {
      return AppColors.warning;
    }
    if (type == 'review_received') return AppColors.ratingStar;
    if (type.contains('scheduled')) return AppColors.info;
    if (type.contains('kyc') || type.contains('account')) {
      return AppColors.textSecondary;
    }
    if (type == 'system' || type == 'promotion') return AppColors.primary;
    return AppColors.textSecondary;
  }
}
