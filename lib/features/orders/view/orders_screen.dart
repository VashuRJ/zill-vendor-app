// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/utils/app_logger.dart';
import '../viewmodel/orders_viewmodel.dart';
import '../viewmodel/tracking_viewmodel.dart';
import 'order_detail_screen.dart';
import '../../../shared/widgets/accept_order_dialog.dart';

// ────────────────────────────────────────────────────────────────────
//  Orders Screen
// ────────────────────────────────────────────────────────────────────
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late final OrdersViewModel _ordersVM;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _ordersVM = context.read<OrdersViewModel>();
    _tab.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ordersVM.fetchOrders();
      _ordersVM.startAutoRefresh();
    });
  }

  void _onTabChanged() {
    // Show search only on Completed (3) and Cancelled (4) tabs
    final shouldShow = _tab.index == 3 || _tab.index == 4;
    if (shouldShow != _showSearch) {
      setState(() => _showSearch = shouldShow);
      if (!shouldShow) {
        _searchCtrl.clear();
        _ordersVM.clearSearch();
      }
    }
  }

  @override
  void dispose() {
    _ordersVM.stopAutoRefresh();
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() => context.read<OrdersViewModel>().fetchOrders();

  Future<void> _pickDateRange(OrdersViewModel vm) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: vm.dateFilter ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) vm.setDateFilter(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: Consumer<OrdersViewModel>(
            builder: (context, vm, _) {
              return TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: [
                  _TabWithBadge(label: 'New', count: vm.newOrders.length),
                  _TabWithBadge(label: 'Preparing', count: vm.preparingOrders.length),
                  _TabWithBadge(label: 'Ready', count: vm.readyOrders.length, showRedBadge: false),
                  _TabWithBadge(label: 'Completed', count: vm.completedOrders.length, showRedBadge: false),
                  _TabWithBadge(label: 'Cancelled', count: vm.cancelledOrders.length, showRedBadge: false),
                ],
              );
            },
          ),
        ),
      ),
      body: Consumer<OrdersViewModel>(
        builder: (context, vm, _) {
          if (vm.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          vm.error!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.white,
                  behavior: SnackBarBehavior.floating,
                  elevation: 6,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.error.withAlpha(100)),
                  ),
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: AppColors.primary,
                    onPressed: _refresh,
                  ),
                ),
              );
              vm.clearError();
            });
          }

          if (vm.status == OrdersStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return Column(
            children: [
              // ── Search bar (Completed/Cancelled tabs only) ──
              if (_showSearch)
                _OrderSearchBar(
                  controller: _searchCtrl,
                  dateFilter: vm.dateFilter,
                  onChanged: (q) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      vm.setSearchQuery(q);
                    });
                  },
                  onClear: () {
                    _searchCtrl.clear();
                    vm.clearSearch();
                  },
                  onDatePick: () => _pickDateRange(vm),
                  onDateClear: () => vm.setDateFilter(null),
                ),
              // ── Content ──
              Expanded(
                child: vm.isSearchActive
                    ? _SearchResultsBody(vm: vm)
                    : TabBarView(
                        controller: _tab,
                        children: [
                          _OrderTabBody(
                            orders: vm.newOrders,
                            tabType: _TabType.newOrder,
                            onRefresh: _refresh,
                          ),
                          _OrderTabBody(
                            orders: vm.preparingOrders,
                            tabType: _TabType.preparing,
                            onRefresh: _refresh,
                          ),
                          _OrderTabBody(
                            orders: vm.readyOrders,
                            tabType: _TabType.ready,
                            onRefresh: _refresh,
                          ),
                          _OrderTabBody(
                            orders: vm.completedOrders,
                            tabType: _TabType.completed,
                            onRefresh: _refresh,
                          ),
                          _OrderTabBody(
                            orders: vm.cancelledOrders,
                            tabType: _TabType.cancelled,
                            onRefresh: _refresh,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Search Bar
// ────────────────────────────────────────────────────────────────────
class _OrderSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final DateTimeRange? dateFilter;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onDatePick;
  final VoidCallback onDateClear;

  const _OrderSearchBar({
    required this.controller,
    required this.dateFilter,
    required this.onChanged,
    required this.onClear,
    required this.onDatePick,
    required this.onDateClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Search field
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search order ID, customer...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      suffixIcon: controller.text.isNotEmpty
                          ? GestureDetector(
                              onTap: onClear,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textHint,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date filter button
              GestureDetector(
                onTap: onDatePick,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: dateFilter != null
                        ? AppColors.primary.withAlpha(15)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dateFilter != null
                          ? AppColors.primary.withAlpha(80)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.date_range_rounded,
                    size: 20,
                    color: dateFilter != null
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          // Date filter chip
          if (dateFilter != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_fmtDate(dateFilter!.start)} — ${_fmtDate(dateFilter!.end)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onDateClear,
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ────────────────────────────────────────────────────────────────────
//  Search Results Body
// ────────────────────────────────────────────────────────────────────
class _SearchResultsBody extends StatelessWidget {
  final OrdersViewModel vm;
  const _SearchResultsBody({required this.vm});

  static _TabType _tabTypeFromStatus(String status) {
    switch (status) {
      case 'pending':
      case 'confirmed':
        return _TabType.newOrder;
      case 'preparing':
        return _TabType.preparing;
      case 'ready':
      case 'picked':
      case 'on_the_way':
        return _TabType.ready;
      case 'cancelled':
        return _TabType.cancelled;
      default:
        return _TabType.completed;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (vm.searchLoading && vm.searchResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (vm.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.textHint.withAlpha(80),
            ),
            const SizedBox(height: 12),
            const Text(
              'No orders found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search or date range',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint.withAlpha(160),
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 &&
            vm.searchHasMore &&
            !vm.searchLoading) {
          vm.loadMoreSearchResults();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: vm.searchResults.length + (vm.searchHasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == vm.searchResults.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OrderCard(
              order: vm.searchResults[i],
              tabType: _SearchResultsBody._tabTypeFromStatus(vm.searchResults[i].status),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Tab with count badge
// ────────────────────────────────────────────────────────────────────
class _TabWithBadge extends StatelessWidget {
  const _TabWithBadge({
    required this.label,
    required this.count,
    this.showRedBadge = true,
  });

  final String label;
  final int count;
  final bool showRedBadge;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            if (showRedBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Text(
                '($count)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Tab content
// ────────────────────────────────────────────────────────────────────
enum _TabType { newOrder, preparing, ready, completed, cancelled }

class _OrderTabBody extends StatelessWidget {
  const _OrderTabBody({
    required this.orders,
    required this.tabType,
    required this.onRefresh,
  });

  final List<VendorOrder> orders;
  final _TabType tabType;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const Center(child: _EmptyOrdersPlaceholder()),
            ),
          ],
        ),
      );
    }

    final vm = context.watch<OrdersViewModel>();
    final totalCount = orders.length;

    // Pagination only for Completed / Cancelled tabs
    final int limit;
    final VoidCallback? onLoadMore;
    if (tabType == _TabType.completed) {
      limit = vm.completedLimit;
      onLoadMore = vm.loadMoreCompleted;
    } else if (tabType == _TabType.cancelled) {
      limit = vm.cancelledLimit;
      onLoadMore = vm.loadMoreCancelled;
    } else {
      limit = totalCount; // active tabs — show all
      onLoadMore = null;
    }

    final visibleCount = limit < totalCount ? limit : totalCount;
    final hasMore = visibleCount < totalCount;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: visibleCount + (hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          // "Load More" button at the end
          if (i == visibleCount) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    'Load More  ·  Showing $visibleCount of $totalCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withAlpha(80),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            );
          }

          try {
            return _OrderCard(order: orders[i], tabType: tabType);
          } catch (e, st) {
            AppLogger.e('_OrderCard build CRASHED for index $i '
                'status=${orders[i].status}', e, st);
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Card Render Error: ${orders[i].orderNumber}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status: ${orders[i].status}\nError: $e',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Order Card
// ────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.tabType});

  final VendorOrder order;
  final _TabType tabType;

  Color _accentColor() => switch (order.status) {
    'pending' => AppColors.orderPending,
    'confirmed' => AppColors.orderConfirmed,
    'preparing' => AppColors.orderPreparing,
    'ready' => AppColors.orderReady,
    'picked' || 'on_the_way' || 'delivered' => AppColors.orderPickedUp,
    'cancelled' || 'refunded' => AppColors.orderCancelled,
    _ => AppColors.border,
  };

  bool get _hasActions =>
      tabType == _TabType.newOrder || tabType == _TabType.preparing;

  /// Format price: ₹30 for whole numbers, ₹59.85 for decimals
  static String _fmtPrice(double amount) {
    if (amount == amount.truncateToDouble()) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {

    // Build item list for display
    final displayItems = order.items.isNotEmpty
        ? order.items
        : <OrderLineItem>[]; // real items preferred

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        // Stack replaces IntrinsicHeight+Row — avoids silent layout collapse
        child: Stack(
          children: [
            // Coloured left accent strip (stretches to full card height)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: _accentColor()),
            ),
            // Main content (offset by 4px to clear the accent strip)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // ─ Scheduled banner ──────────────────────────────────
                    if (order.isScheduled)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        color: const Color(0xFFFFF3CD),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Color(0xFF856404),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order.scheduledFor != null
                                    ? 'SCHEDULED · ${DateFormat('d MMM, hh:mm a').format(order.scheduledFor!.toLocal())}'
                                    : 'SCHEDULED ORDER',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF856404),
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ─ Tappable info area ───────────────────────────────
                    InkWell(
                      onTap: () {
                        final vm = context.read<OrdersViewModel>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(order: order, vm: vm),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Top row: ID + order number + time + status ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Short ID (prominent, like Dashboard)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _accentColor().withAlpha(18),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'ID: ${order.id}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: _accentColor(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    order.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _timeAgo(order.createdAt),
                                  style: const TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusChip(status: order.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // ── Type badge + customer + COD badge + call ──
                            Row(
                              children: [
                                _OrderTypeBadge(orderType: order.orderType),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    order.customerName,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Payment badge (next to name, like Dashboard)
                                _PaymentMethodBadge(method: order.paymentMethod),
                                // Call button
                                if (order.customerPhone.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => launchUrl(
                                      Uri.parse('tel:${order.customerPhone}'),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withAlpha(15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.call_rounded,
                                        size: 16,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // ── ITEMS SECTION (Zomato-style) ──────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: displayItems.isNotEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...displayItems
                                            .take(3)
                                            .map(
                                              (item) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 5,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    // Qty x Name
                                                    Text(
                                                      '${item.quantity} x ',
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        item.itemName,
                                                        style: const TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      _fmtPrice(
                                                        item.subtotal,
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        if (displayItems.length > 3)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              '+${displayItems.length - 3} more item${displayItems.length - 3 == 1 ? '' : 's'}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  // Fallback to summary strings
                                  : order.itemsSummary.isNotEmpty
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...order.itemsSummary
                                            .take(3)
                                            .map(
                                              (s) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        if (order.itemsSummary.length > 3)
                                          Text(
                                            '+${order.itemsSummary.length - 3} more',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    )
                                  : Text(
                                      '${order.itemsCount} item${order.itemsCount == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            // ── Bottom row: items count + total + chevron ──
                            Row(
                              children: [
                                Text(
                                  '${order.itemsCount} item${order.itemsCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Total: ${_fmtPrice(order.totalAmount)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.textHint,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ─ Action buttons (NOT inside InkWell) ────────────────
                    if (_hasActions)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: _ActionButtons(order: order, tabType: tabType),
                      ),
                    // ─ Ready tab: delivery status + Track button ──────────
                    if (tabType == _TabType.ready)
                      _ReadyCardFooter(order: order),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Ready Card Footer — delivery status + Track button
// ────────────────────────────────────────────────────────────────────
class _ReadyCardFooter extends StatelessWidget {
  const _ReadyCardFooter({required this.order});

  final VendorOrder order;

  /// Delivery status label based on order status.
  (String label, IconData icon, Color bg, Color fg) _deliveryInfo() {
    return switch (order.status) {
      'picked' => (
        'Picked Up',
        Icons.check_circle_outline,
        const Color(0xFFD4EDDA),
        const Color(0xFF155724),
      ),
      'on_the_way' => (
        'Out for Delivery',
        Icons.delivery_dining,
        const Color(0xFFCFE2FF),
        const Color(0xFF0A58CA),
      ),
      _ => (
        'Waiting for Pickup',
        Icons.schedule,
        const Color(0xFFFFF3CD),
        const Color(0xFF856404),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = _deliveryInfo();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          // ── Delivery status badge ──
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Track button ──
          ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _TrackingSheet(orderId: order.id),
              );
            },
            icon: const Icon(Icons.location_on, size: 15),
            label: const Text(
              'Track',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Order Detail Bottom Sheet
// ────────────────────────────────────────────────────────────────────
// ignore: unused_element
void _showOrderDetailSheet(BuildContext context, VendorOrder order) {
  final vm = context.read<OrdersViewModel>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderDetailSheet(order: order, vm: vm),
  );
}

class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.order, required this.vm});

  final VendorOrder order;
  final OrdersViewModel vm;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  VendorOrderDetail? _detail;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final d = await widget.vm.fetchOrderDetail(widget.order.id);
    if (mounted) {
      setState(() {
        _detail = d;
        _loadingDetail = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _detail?.order ?? widget.order;
    final currFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.96,
      minChildSize: 0.4,
      snap: true,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                _OrderTypeBadge(orderType: order.orderType),
                                if (order.isScheduled) ...[
                                  const SizedBox(width: 8),
                                  _ScheduledChip(
                                    scheduledFor: order.scheduledFor,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _timeAgo(order.createdAt),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: order.status),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                // Scrollable content
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                    children: [
                      // ─ Customer ──────────────────────────────────────
                      _SheetSection(
                        icon: Icons.person_outline,
                        title: 'CUSTOMER',
                        child: _CustomerRow(order: order),
                      ),
                      const SizedBox(height: 18),
                      // ─ Delivery Address ───────────────────────────────
                      _SheetSection(
                        icon: Icons.location_on_outlined,
                        title:
                            order.orderType == 'takeaway' ||
                                order.orderType == 'take_away'
                            ? 'PICKUP POINT'
                            : order.orderType == 'dine_in' ||
                                  order.orderType == 'dine-in'
                            ? 'DINE IN'
                            : 'DELIVERY ADDRESS',
                        child: Text(
                          order.deliveryAddress.isNotEmpty
                              ? order.deliveryAddress
                              : 'No address provided',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Delivery instructions (from detail endpoint)
                      if (_detail != null &&
                          _detail!.deliveryInstructions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _detail!.deliveryInstructions,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      // ─ Payment ───────────────────────────────────────
                      _SheetSection(
                        icon: Icons.payment_outlined,
                        title: 'PAYMENT',
                        child: _PaymentBadge(
                          method: order.paymentMethod,
                          status: order.paymentStatus,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ─ Order Items ───────────────────────────────────
                      _SheetSection(
                        icon: Icons.receipt_long_outlined,
                        title: 'ORDER ITEMS',
                        child: order.items.isEmpty
                            ? const Text(
                                'Item details loading…',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...order.items.map(
                                    (item) => _ItemRow(item: item),
                                  ),
                                  const Divider(
                                    height: 20,
                                    color: AppColors.borderLight,
                                  ),
                                  // Price breakdown (from detail endpoint)
                                  if (_detail != null) ...[
                                    _PriceRow(
                                      label: 'Subtotal',
                                      value: _detail!.subtotal,
                                      currFmt: currFmt,
                                    ),
                                    if (_detail!.deliveryCharge > 0)
                                      _PriceRow(
                                        label: 'Delivery Fee',
                                        value: _detail!.deliveryCharge,
                                        currFmt: currFmt,
                                      ),
                                    if (_detail!.taxAmount > 0)
                                      _PriceRow(
                                        label: 'Tax',
                                        value: _detail!.taxAmount,
                                        currFmt: currFmt,
                                      ),
                                    if (_detail!.discountAmount > 0)
                                      _PriceRow(
                                        label: 'Discount',
                                        value: _detail!.discountAmount,
                                        currFmt: currFmt,
                                        isDiscount: true,
                                      ),
                                    if (_detail!.couponDiscount > 0)
                                      _PriceRow(
                                        label: _detail!.couponCode.isNotEmpty
                                            ? 'Coupon (${_detail!.couponCode})'
                                            : 'Coupon Discount',
                                        value: _detail!.couponDiscount,
                                        currFmt: currFmt,
                                        isDiscount: true,
                                      ),
                                    const Divider(
                                      height: 12,
                                      color: AppColors.borderLight,
                                    ),
                                  ] else if (_loadingDetail)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: LinearProgressIndicator(
                                        minHeight: 2,
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.borderLight,
                                      ),
                                    ),
                                  // Grand total row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Grand Total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        currFmt.format(order.totalAmount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      // ─ Special Instructions ──────────────────────────
                      if (order.instructions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _SheetSection(
                          icon: Icons.notes_outlined,
                          title: 'NOTES FROM CUSTOMER',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFE082),
                              ),
                            ),
                            child: Text(
                              order.instructions,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                      // ─ Scheduled For ─────────────────────────────────
                      if (order.isScheduled && order.scheduledFor != null) ...[
                        const SizedBox(height: 18),
                        _SheetSection(
                          icon: Icons.calendar_today_outlined,
                          title: 'SCHEDULED FOR',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFCA2C),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 15,
                                  color: Color(0xFF856404),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat(
                                    'EEE, d MMM y · hh:mm a',
                                  ).format(order.scheduledFor!.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      // ─ ETA / Prep Time ───────────────────────────────
                      if (order.estimatedPrepTime != null ||
                          order.estimatedDeliveryTime != null) ...[
                        const SizedBox(height: 18),
                        _SheetSection(
                          icon: Icons.schedule_outlined,
                          title: 'ESTIMATED TIMES',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (order.estimatedPrepTime != null)
                                _EtaBadge(
                                  icon: Icons.restaurant_outlined,
                                  label: 'Prep Time',
                                  value: '${order.estimatedPrepTime} min',
                                  color: const Color(0xFF6F42C1),
                                ),
                              if (order.estimatedDeliveryTime != null)
                                _EtaBadge(
                                  icon: Icons.delivery_dining_outlined,
                                  label: 'ETA',
                                  value: DateFormat('hh:mm a').format(
                                    order.estimatedDeliveryTime!.toLocal(),
                                  ),
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      ],
                      // ─ Cancellation Info ──────────────────────────────
                      if (_detail != null &&
                          (order.status == 'cancelled' ||
                              order.status == 'refunded') &&
                          (_detail!.cancellationReason.isNotEmpty ||
                              _detail!.cancellationNote.isNotEmpty)) ...[
                        const SizedBox(height: 18),
                        _SheetSection(
                          icon: Icons.cancel_outlined,
                          title: 'CANCELLATION REASON',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_detail!.cancellationReason.isNotEmpty)
                                  Text(
                                    _detail!.cancellationReason
                                        .replaceAll('_', ' ')
                                        .toLowerCase()
                                        .split(' ')
                                        .map(
                                          (w) => w.isEmpty
                                              ? w
                                              : w[0].toUpperCase() +
                                                    w.substring(1),
                                        )
                                        .join(' '),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                if (_detail!.cancellationNote.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _detail!.cancellationNote,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.error,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Sheet reusable section header
// ────────────────────────────────────────────────────────────────────
class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(left: 21), child: child),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Item row in detail sheet
// ────────────────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderLineItem item;

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '×${item.quantity}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.variantName != null && item.variantName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.variantName!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                // Individual addons listed
                if (item.selectedAddons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: item.selectedAddons
                          .map(
                            (a) => Text(
                              '+ ${a.addonName}  ${currFmt.format(a.addonPrice)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                else if (item.addonsPrice > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Addons: +${currFmt.format(item.addonsPrice)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                // Per-item customer note
                if (item.specialInstructions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notes,
                          size: 11,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.specialInstructions,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            currFmt.format(item.subtotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Payment badge
// ────────────────────────────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.method, required this.status});

  final String method;
  final String status;

  String get _methodLabel => switch (method.toLowerCase()) {
    'cod' => 'Cash on Delivery',
    'upi' => 'UPI',
    'card' => 'Card',
    'wallet' => 'Wallet',
    'online' || 'razorpay' => 'Online Payment',
    _ => method.toUpperCase(),
  };

  bool get _isPaid =>
      status.toLowerCase() == 'paid' || status.toLowerCase() == 'completed';
  bool get _isCod => method.toLowerCase() == 'cod';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            _methodLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (_isPaid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Paid',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          )
        else if (_isCod)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Pay on Delivery',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF856404),
              ),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Action Buttons  (StatefulWidget — tracks which button is loading)
// ────────────────────────────────────────────────────────────────────
class _ActionButtons extends StatefulWidget {
  const _ActionButtons({required this.order, required this.tabType});

  final VendorOrder order;
  final _TabType tabType;

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  // Tracks which button the user last tapped ('accept'|'reject'|'ready')
  String? _activeAction;

  Future<void> _doAndTrack(
    String action,
    Future<bool> Function() vmCall,
  ) async {
    if (!mounted) return;
    setState(() => _activeAction = action);
    final success = await vmCall();
    if (!mounted) return;
    setState(() => _activeAction = null);
    final msg = switch (action) {
      'accept' => 'Order accepted!',
      'reject' => 'Order rejected.',
      'preparing' => 'Started preparing!',
      'ready' => 'Order marked as Ready!',
      _ => success ? 'Done!' : 'Action failed.',
    };
    _showPremiumToast(msg, success: success);
  }

  void _showPremiumToast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? AppColors.success : AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: success
                ? AppColors.success.withAlpha(100)
                : AppColors.error.withAlpha(100),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _btnSpinner({Color color = Colors.white}) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
  );

  void _showRejectDialog() {
    // Local state inside dialog
    String cancellationReason = 'restaurant_busy';
    final ctrl = TextEditingController(text: 'Restaurant is busy');
    final vm = context.read<OrdersViewModel>();

    const reasons = [
      ('restaurant_busy', 'Restaurant Busy'),
      ('item_unavailable', 'Item Unavailable'),
      ('restaurant_closed', 'Restaurant Closed'),
      ('other', 'Other'),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text(
            'Reject Order',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠️ Penalty warning banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCA2C)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF856404),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Warning: Cancelling orders incurs penalties '
                          '(1st: Warning, 2nd: ₹50, 3rd: ₹100, '
                          '4th: ₹150 + Deactivation)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF856404),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Cancellation reason dropdown
                const Text(
                  'Cancellation Reason',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: cancellationReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  items: reasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.$1,
                          child: Text(
                            r.$2,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => cancellationReason = v);
                  },
                ),
                const SizedBox(height: 14),
                // Detailed explanation
                const Text(
                  'Additional Details (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: 'Enter additional details…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _doAndTrack(
                  'reject',
                  () => vm.rejectOrder(
                    widget.order.id,
                    reason: ctrl.text.trim().isEmpty
                        ? reasons
                              .firstWhere((r) => r.$1 == cancellationReason)
                              .$2
                        : ctrl.text.trim(),
                    cancellationReason: cancellationReason,
                  ),
                );
              },
              child: const Text('Reject Order'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcceptDialog() {
    final vm = context.read<OrdersViewModel>();
    showAcceptOrderDialog(
      context: context,
      order: widget.order,
      onAccept: (prepTime) => _doAndTrack(
        'accept',
        () => vm.acceptOrder(widget.order.id, estimatedPrepTime: prepTime),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<OrdersViewModel>();
    final actioning = context.select<OrdersViewModel, bool>(
      (v) => v.isActionLoading(widget.order.id),
    );

    final btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
    );
    const btnPad = EdgeInsets.symmetric(vertical: 8, horizontal: 8);

    final status = widget.order.status.toLowerCase();

    if (status == 'pending') {
      return Row(
        children: [
          // Reject — smaller (flex 1), red outlined
          Expanded(
            flex: 1,
            child: ElevatedButton(
              onPressed: actioning ? null : _showRejectDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEBEE),
                foregroundColor: const Color(0xFFB71C1C),
                elevation: 0,
                shape: btnShape,
                padding: btnPad,
                side: const BorderSide(color: Color(0xFFEF9A9A)),
              ),
              child: _activeAction == 'reject' && actioning
                  ? _btnSpinner(color: const Color(0xFFB71C1C))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Reject',
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Accept Order — larger (flex 2), green filled
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: actioning ? null : _showAcceptDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: btnShape,
                padding: btnPad,
              ),
              child: _activeAction == 'accept' && actioning
                  ? _btnSpinner()
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Accept Order',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    // confirmed → Start Preparing (purple)
    if (status == 'confirmed') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: actioning
              ? null
              : () => _doAndTrack(
                  'preparing',
                  () => vm.startPreparing(widget.order.id),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8E24AA),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: btnShape,
            padding: btnPad,
          ),
          child: _activeAction == 'preparing' && actioning
              ? _btnSpinner()
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Start Preparing',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      );
    }

    // preparing → Mark as Ready (green)
    if (status == 'preparing') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: actioning
              ? null
              : () => _doAndTrack('ready', () => vm.markReady(widget.order.id)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: btnShape,
            padding: btnPad,
          ),
          child: _activeAction == 'ready' && actioning
              ? _btnSpinner()
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Mark as Ready',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      );
    }

    // ready / picked / on_the_way → status badge + Track button
    if (status == 'ready' || status == 'picked' || status == 'on_the_way') {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              height: AppSizes.buttonHeight,
              decoration: BoxDecoration(
                color: switch (status) {
                  'picked' => const Color(0xFFD4EDDA),
                  'on_the_way' => const Color(0xFFCFE2FF),
                  _ => Colors.grey.shade100,
                },
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                border: Border.all(
                  color: switch (status) {
                    'picked' => const Color(0xFF155724).withAlpha(60),
                    'on_the_way' => const Color(0xFF0A58CA).withAlpha(60),
                    _ => Colors.grey.shade300,
                  },
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    switch (status) {
                      'picked' => Icons.check_circle_outline,
                      'on_the_way' => Icons.delivery_dining,
                      _ => Icons.hourglass_top_rounded,
                    },
                    size: 15,
                    color: switch (status) {
                      'picked' => const Color(0xFF155724),
                      'on_the_way' => const Color(0xFF0A58CA),
                      _ => Colors.grey.shade500,
                    },
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      switch (status) {
                        'picked' => 'Picked Up',
                        'on_the_way' => 'Out for Delivery',
                        _ => 'Waiting for Pickup',
                      },
                      style: TextStyle(
                        color: switch (status) {
                          'picked' => const Color(0xFF155724),
                          'on_the_way' => const Color(0xFF0A58CA),
                          _ => Colors.grey.shade600,
                        },
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _showTrackingSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: Size(double.infinity, AppSizes.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Track', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _showTrackingSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrackingSheet(orderId: widget.order.id),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Status Chip
// ────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'pending' => (
        const Color(0xFFFFF3CD),
        const Color(0xFF856404),
        'Pending',
      ),
      'confirmed' => (
        const Color(0xFFCFE2FF),
        const Color(0xFF0A58CA),
        'Confirmed',
      ),
      'preparing' => (
        const Color(0xFFE2D9F3),
        const Color(0xFF6F42C1),
        'Preparing',
      ),
      'ready' => (const Color(0xFFD1ECF1), const Color(0xFF0C5460), 'Ready'),
      'picked' => (const Color(0xFFD4EDDA), const Color(0xFF155724), 'Picked'),
      'on_the_way' => (
        const Color(0xFFD4EDDA),
        const Color(0xFF155724),
        'On the Way',
      ),
      'delivered' => (
        const Color(0xFFD4EDDA),
        const Color(0xFF155724),
        'Delivered',
      ),
      'cancelled' => (
        const Color(0xFFF8D7DA),
        const Color(0xFF721C24),
        'Cancelled',
      ),
      'refunded' => (
        const Color(0xFFE9ECEF),
        const Color(0xFF495057),
        'Refunded',
      ),
      _ => (const Color(0xFFE9ECEF), const Color(0xFF495057), status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Empty Placeholder
// ────────────────────────────────────────────────────────────────────
class _EmptyOrdersPlaceholder extends StatelessWidget {
  const _EmptyOrdersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 72,
          color: AppColors.textSecondary.withAlpha(102),
        ),
        const SizedBox(height: 16),
        const Text(
          'No orders here',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pull down to refresh',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  ETA Badge (used in Order Detail Sheet)
// ────────────────────────────────────────────────────────────────────
class _EtaBadge extends StatelessWidget {
  const _EtaBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Order Type Badge
// ────────────────────────────────────────────────────────────────────
class _OrderTypeBadge extends StatelessWidget {
  const _OrderTypeBadge({required this.orderType});

  final String orderType;

  @override
  Widget build(BuildContext context) {
    final type = orderType.toLowerCase();
    final (IconData icon, String label, Color bg, Color fg) = switch (type) {
      'takeaway' || 'take_away' => (
        Icons.directions_walk,
        'Takeaway',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      'dine_in' || 'dine-in' => (
        Icons.restaurant,
        'Dine In',
        const Color(0xFFEDE7F6),
        const Color(0xFF512DA8),
      ),
      _ => (
        Icons.delivery_dining,
        'Delivery',
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Scheduled Chip
// ────────────────────────────────────────────────────────────────────
class _ScheduledChip extends StatelessWidget {
  const _ScheduledChip({this.scheduledFor});

  final DateTime? scheduledFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCA2C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 11, color: Color(0xFF856404)),
          const SizedBox(width: 4),
          Text(
            scheduledFor != null
                ? 'Scheduled · ${DateFormat('hh:mm a').format(scheduledFor!.toLocal())}'
                : 'Scheduled',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF856404),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Customer row with call + copy actions
// ────────────────────────────────────────────────────────────────────
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.order});

  final VendorOrder order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              if (order.customerPhone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    order.customerPhone,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (order.customerPhone.isNotEmpty) ...[
          // Call button
          Container(
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.phone, color: AppColors.success, size: 20),
              tooltip: 'Call customer',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final uri = Uri.parse('tel:${order.customerPhone}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  Clipboard.setData(ClipboardData(text: order.customerPhone));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Phone copied (dial not supported)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.white,
                        behavior: SnackBarBehavior.floating,
                        elevation: 4,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Copy button
          Container(
            decoration: BoxDecoration(
              color: AppColors.border.withAlpha(120),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.copy,
                color: AppColors.textSecondary,
                size: 18,
              ),
              tooltip: 'Copy number',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: order.customerPhone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Phone number copied',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.white,
                    behavior: SnackBarBehavior.floating,
                    elevation: 4,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Price row (for order breakdown)
// ────────────────────────────────────────────────────────────────────
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    required this.currFmt,
    this.isDiscount = false,
  });

  final String label;
  final double value;
  final NumberFormat currFmt;
  final bool isDiscount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            isDiscount
                ? '−${currFmt.format(value.abs())}'
                : currFmt.format(value),
            style: TextStyle(
              fontSize: 12,
              color: isDiscount ? AppColors.success : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Payment method mini badge (for order card)
// ────────────────────────────────────────────────────────────────────
class _PaymentMethodBadge extends StatelessWidget {
  const _PaymentMethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (method
        .toLowerCase()) {
      'cod' => (Icons.money, 'Cash', const Color(0xFF2E7D32)),
      'upi' => (Icons.phone_android, 'UPI', const Color(0xFF6A1B9A)),
      'card' => (Icons.credit_card, 'Card', const Color(0xFF1565C0)),
      'online' ||
      'razorpay' => (Icons.payment, 'Online', const Color(0xFF283593)),
      _ => (Icons.payment, method, AppColors.textSecondary),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//  Time ago helper
// ────────────────────────────────────────────────────────────────────
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return DateFormat('d MMM, hh:mm a').format(dt.toLocal());
}

// ────────────────────────────────────────────────────────────────────
//  Live Tracking Bottom Sheet  (animated, real API — TrackingViewModel)
// ────────────────────────────────────────────────────────────────────
class _TrackingSheet extends StatefulWidget {
  const _TrackingSheet({required this.orderId});

  final int orderId;

  @override
  State<_TrackingSheet> createState() => _TrackingSheetState();
}

class _TrackingSheetState extends State<_TrackingSheet>
    with SingleTickerProviderStateMixin {
  late final TrackingViewModel _vm;
  late final WebSocketService _wsService;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _wsService = context.read<WebSocketService>();
    _vm = TrackingViewModel(apiService: context.read<ApiService>());
    _vm.startTracking(widget.orderId);
    // Wire WebSocket for real-time tracking updates
    _wsService.connectOrderTracking(widget.orderId);
    _vm.listenToWebSocket(_wsService.onOrderTracking);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _vm.stopTracking();
    _vm.dispose();
    _wsService.disconnectOrderTracking(widget.orderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrackingViewModel>.value(
      value: _vm,
      child: Consumer<TrackingViewModel>(
        builder: (_, vm, _) => _buildSheet(vm),
      ),
    );
  }

  // ── Sheet scaffold ────────────────────────────────────────────────────
  Widget _buildSheet(TrackingViewModel vm) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (vm.isLoading)
            _buildLoader()
          else if (vm.status == TrackingViewStatus.error && !vm.hasData)
            _buildError(vm)
          else if (vm.hasData)
            Flexible(child: _buildLoaded(vm)),
        ],
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.info,
              backgroundColor: AppColors.info.withAlpha(30),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Fetching rider info…',
            style: TextStyle(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────
  Widget _buildError(TrackingViewModel vm) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 44, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            vm.errorMessage ?? 'Failed to load tracking info.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: vm.refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.info,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loaded ───────────────────────────────────────────────────────────
  Widget _buildLoaded(TrackingViewModel vm) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBanner(vm),
          const SizedBox(height: 14),
          _buildETADashboard(vm),
          const SizedBox(height: 14),
          vm.partner != null
              ? _buildPartnerCard(vm.partner!)
              : _buildNoPartner(),
          const SizedBox(height: 14),
          _buildDeliveryInfo(vm),
          const SizedBox(height: 14),
          _buildLiveTimeline(vm),
          const SizedBox(height: 10),
          _buildLiveFooter(vm),
        ],
      ),
    );
  }

  // ── Animated Status Banner ──────────────────────────────────────────
  Widget _buildStatusBanner(TrackingViewModel vm) {
    final ts = vm.trackingStatus;
    final statusText = ts?.statusDisplay ?? 'Tracking…';
    final rawEta = vm.eta?.pickupDisplay ?? 'Calculating…';
    // Only prepend "Arriving in" when ETA contains an actual time value (digit)
    // and the order is not already out for delivery / delivered.
    final bool showArrivingPrefix = !(ts?.isOutForDelivery ?? false) &&
        !(ts?.isNearCustomer ?? false) &&
        !(ts?.isDelivered ?? false) &&
        RegExp(r'\d').hasMatch(rawEta);
    final etaText = showArrivingPrefix ? 'Arriving in $rawEta' : rawEta;

    // Color based on current tracking status
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;

    if (ts == null || ts.isAwaitingAssignment) {
      bgColor = AppColors.warningLight;
      borderColor = AppColors.warning.withAlpha(80);
      textColor = const Color(0xFFE65100);
      icon = Icons.search_rounded;
    } else if (ts.isAtRestaurant) {
      bgColor = AppColors.successLight;
      borderColor = AppColors.success.withAlpha(80);
      textColor = const Color(0xFF1B5E20);
      icon = Icons.storefront_rounded;
    } else if (ts.isOutForDelivery || ts.isNearCustomer) {
      bgColor = AppColors.successLight;
      borderColor = AppColors.success.withAlpha(80);
      textColor = const Color(0xFF1B5E20);
      icon = Icons.delivery_dining_rounded;
    } else {
      bgColor = AppColors.infoLight;
      borderColor = AppColors.info.withAlpha(80);
      textColor = const Color(0xFF0D47A1);
      icon = Icons.moped_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                // Pulsing ETA text
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Text(
                    etaText,
                    style: TextStyle(
                      color: textColor.withAlpha(200),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Live dot indicator
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, _) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor.withAlpha((_pulseAnim.value * 255).toInt()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rider Card (Zomato-style) ───────────────────────────────────────
  Widget _buildPartnerCard(TrackingPartner partner) {
    final initial =
        partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
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
          // Profile photo / avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.info.withAlpha(24),
              border: Border.all(color: AppColors.info.withAlpha(60), width: 2),
            ),
            child: ClipOval(
              child: (partner.profilePhoto != null &&
                      partner.profilePhoto!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: partner.profilePhoto!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + vehicle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.two_wheeler_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        partner.vehicleDisplay.isNotEmpty
                            ? '${partner.vehicleDisplay} · ${partner.vehicleNumber}'
                            : partner.vehicleNumber,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (partner.rating > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.ratingStar),
                      const SizedBox(width: 2),
                      Text(
                        '${partner.rating.toStringAsFixed(1)} · ${partner.totalDeliveries} deliveries',
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Call button
          Container(
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withAlpha(60)),
            ),
            child: IconButton(
              icon: const Icon(Icons.phone_rounded, color: AppColors.success),
              onPressed: partner.phone.isNotEmpty
                  ? () async {
                      final uri = Uri.parse('tel:${partner.phone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    }
                  : null,
              tooltip: 'Call rider',
            ),
          ),
        ],
      ),
    );
  }

  // ── No Partner Placeholder ──────────────────────────────────────────
  Widget _buildNoPartner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: _pulseAnim,
            child: const Icon(Icons.person_search_rounded,
                size: 20, color: AppColors.warning),
          ),
          const SizedBox(width: 10),
          const Text(
            'Finding a delivery partner nearby…',
            style: TextStyle(
              color: Color(0xFFE65100),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── ETA Dashboard (two-column: Pickup + Delivery) ──────────────────
  Widget _buildETADashboard(TrackingViewModel vm) {
    final eta = vm.eta;
    final ts = vm.trackingStatus;

    // Determine which phase we're in for contextual labels
    final bool pickupDone =
        ts?.isOutForDelivery == true ||
        ts?.isNearCustomer == true ||
        ts?.isDelivered == true;

    return Row(
      children: [
        // ── Pickup ETA ──
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pickupDone ? AppColors.successLight : AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: pickupDone
                    ? AppColors.success.withAlpha(60)
                    : AppColors.info.withAlpha(60),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  pickupDone
                      ? Icons.check_circle_rounded
                      : Icons.storefront_rounded,
                  size: 20,
                  color: pickupDone
                      ? AppColors.success
                      : AppColors.info,
                ),
                const SizedBox(height: 6),
                Text(
                  pickupDone ? 'Picked Up' : 'Pickup ETA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: pickupDone
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF0D47A1),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (!pickupDone && eta != null && eta.pickupMinutes != null)
                  Text(
                    '${eta.pickupMinutes} min',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  )
                else
                  Text(
                    pickupDone
                        ? 'Done'
                        : eta?.pickupDisplay ?? '—',
                    style: TextStyle(
                      fontSize: pickupDone ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: pickupDone
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  pickupDone
                      ? 'Order with rider'
                      : 'Rider → Restaurant',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // ── Delivery ETA ──
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ts?.isDelivered == true
                  ? AppColors.successLight
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: ts?.isDelivered == true
                    ? AppColors.success.withAlpha(60)
                    : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  ts?.isDelivered == true
                      ? Icons.check_circle_rounded
                      : Icons.location_on_rounded,
                  size: 20,
                  color: ts?.isDelivered == true
                      ? AppColors.success
                      : (pickupDone ? AppColors.primary : AppColors.textHint),
                ),
                const SizedBox(height: 6),
                Text(
                  ts?.isDelivered == true ? 'Delivered' : 'Delivery ETA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ts?.isDelivered == true
                        ? const Color(0xFF1B5E20)
                        : (pickupDone
                            ? AppColors.textPrimary
                            : AppColors.textHint),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (ts?.isDelivered == true)
                  const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  )
                else if (eta != null && eta.deliveryMinutes != null)
                  Text(
                    '${eta.deliveryMinutes} min',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: pickupDone
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      height: 1.1,
                    ),
                  )
                else
                  Text(
                    eta?.deliveryDisplay ?? '—',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  ts?.isDelivered == true
                      ? 'Completed'
                      : 'Rider → Customer',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Delivery Info Card (customer + address) ───────────────────────
  Widget _buildDeliveryInfo(TrackingViewModel vm) {
    final info = vm.orderInfo;
    if (info == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DELIVERING TO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          // Customer name
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Address
          if (info.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.location_on_outlined,
                      size: 15, color: AppColors.textHint),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    info.deliveryAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // Payment + Order number
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: info.paymentMethod.toLowerCase().contains('cod') ||
                          info.paymentMethod.toLowerCase().contains('cash')
                      ? AppColors.warningLight
                      : AppColors.successLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  info.paymentMethod.isNotEmpty
                      ? info.paymentMethod.toUpperCase()
                      : 'PREPAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        info.paymentMethod.toLowerCase().contains('cod') ||
                                info.paymentMethod
                                    .toLowerCase()
                                    .contains('cash')
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1B5E20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                info.orderNumber,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '₹${info.grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Live Update Footer ────────────────────────────────────────────
  Widget _buildLiveFooter(TrackingViewModel vm) {
    final isLive = vm.trackingStatus?.isLiveTracking ?? false;
    final lastUpdated = vm.data?.lastUpdated;
    String agoText = '';
    if (lastUpdated != null) {
      final diff = DateTime.now().difference(lastUpdated).inSeconds;
      if (diff < 5) {
        agoText = 'Just now';
      } else if (diff < 60) {
        agoText = '${diff}s ago';
      } else {
        agoText = '${(diff ~/ 60)}m ago';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing live dot
          if (isLive || vm.isTracking)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, _) => Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success
                      .withAlpha((_pulseAnim.value * 255).toInt()),
                ),
              ),
            ),
          if (isLive || vm.isTracking) const SizedBox(width: 5),
          Text(
            isLive ? 'LIVE' : 'AUTO-REFRESH',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isLive ? AppColors.success : AppColors.info,
              letterSpacing: 1,
            ),
          ),
          if (agoText.isNotEmpty) ...[
            const Text(
              '  ·  ',
              style: TextStyle(fontSize: 9, color: AppColors.textHint),
            ),
            Text(
              'Updated $agoText',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
          const Text(
            '  ·  ',
            style: TextStyle(fontSize: 9, color: AppColors.textHint),
          ),
          const Text(
            '10s polling',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: extract timestamp from backend timeline events ──────────
  String? _timeFromEvent(List<TrackingTimelineEvent> events, String key) {
    for (final e in events) {
      if (e.event == key && e.timestamp != null) {
        final t = e.timestamp!.toLocal();
        final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
        final m = t.minute.toString().padLeft(2, '0');
        final ampm = t.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $ampm';
      }
    }
    return null;
  }

  // ── Live 5-Step Timeline ────────────────────────────────────────────
  Widget _buildLiveTimeline(TrackingViewModel vm) {
    final orderStatus = vm.orderInfo?.status ?? 'pending';
    final events = vm.timeline;

    // 7-step order lifecycle matching the Web App
    const statusOrder = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'picked',
      'on_the_way',
      'delivered',
    ];

    final rawIndex = statusOrder.indexOf(orderStatus);
    final activeIndex = rawIndex >= 0 ? rawIndex : 0;
    final isDelivered = orderStatus == 'delivered';

    // 0=pending, 1=active (pulsing), 2=completed (green check)
    int stepState(int i) {
      if (isDelivered) return 2; // terminal — all steps completed
      if (i < activeIndex) return 2;
      if (i == activeIndex) return 1;
      return 0;
    }

    // Format a DateTime as "h:mm AM/PM"
    String fmtTime(DateTime dt) {
      final t = dt.toLocal();
      final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
      final m = t.minute.toString().padLeft(2, '0');
      final ampm = t.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    }

    // Extract timestamps from backend timeline events where available
    final pickedTime = _timeFromEvent(events, 'order_picked');
    final deliveredTime = _timeFromEvent(events, 'order_delivered');
    final placedTime = vm.orderInfo?.createdAt != null
        ? fmtTime(vm.orderInfo!.createdAt!)
        : null;

    // Step definitions: label, icon, subtitle
    final steps = <(String, IconData, String?)>[
      ('Order Placed', Icons.receipt_long_rounded, placedTime),
      ('Confirmed', Icons.thumb_up_alt_rounded, null),
      ('Preparing', Icons.restaurant_rounded, null),
      ('Ready', Icons.check_box_rounded, null),
      ('Picked Up', Icons.inventory_2_rounded, pickedTime),
      ('On the Way', Icons.delivery_dining_rounded, null),
      ('Delivered', Icons.check_circle_rounded, deliveredTime),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER TIMELINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++)
            _TimelineStep(
              state: stepState(i),
              label: steps[i].$1,
              subtitle: stepState(i) != 0 ? steps[i].$3 : null,
              icon: steps[i].$2,
              isLast: i == steps.length - 1,
              pulseAnimation: stepState(i) == 1 ? _pulseAnim : null,
            ),
        ],
      ),
    );
  }
}

// ── Single Timeline Step Widget ──────────────────────────────────────
class _TimelineStep extends StatelessWidget {
  final int state; // 0=inactive, 1=active, 2=completed
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool isLast;
  final Animation<double>? pulseAnimation;

  const _TimelineStep({
    required this.state,
    required this.label,
    required this.icon,
    required this.isLast,
    this.subtitle,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state == 1;
    final isCompleted = state == 2;

    final Color lineColor =
        isCompleted ? AppColors.success : AppColors.borderLight;

    final Color textColor = isCompleted || isActive
        ? AppColors.textPrimary
        : AppColors.textHint;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + connector line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                isActive && pulseAnimation != null
                    ? AnimatedBuilder(
                        animation: pulseAnimation!,
                        builder: (_, _) => Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary
                                .withAlpha((pulseAnimation!.value * 40).toInt()),
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                              child: Icon(icon, size: 11, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.borderLight,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_rounded : icon,
                          size: 14,
                          color: isCompleted
                              ? Colors.white
                              : AppColors.textHint,
                        ),
                      ),
                // Connector line
                if (!isLast)
                  Container(
                    width: 2,
                    height: 24,
                    color: lineColor,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Label + subtitle
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w600,
                      fontSize: isActive ? 14 : 13,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textHint,
                        fontWeight:
                            isActive ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
