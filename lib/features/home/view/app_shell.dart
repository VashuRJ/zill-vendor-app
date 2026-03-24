import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../dashboard/viewmodel/dashboard_viewmodel.dart';
import '../../dashboard/view/dashboard_screen.dart';
import '../../orders/viewmodel/orders_viewmodel.dart';
import '../../orders/view/orders_screen.dart';
import '../../orders/view/order_detail_screen.dart';
import '../../menu/view/menu_screen.dart';
import '../../earnings/view/earnings_screen.dart';
import '../../profile/view/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Call from any descendant to programmatically switch bottom-nav tab.
  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_AppShellState>()?._switchTab(index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [0];
  List<Widget>? _screens;
  bool _isExitDialogShowing = false;

  void _switchTab(int index) {
    if (index >= 0 && index < (_screens?.length ?? 5)) {
      _navigateToTab(index);
    }
  }

  void _navigateToTab(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _tabHistory.remove(index);
      _tabHistory.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    // Wire FCM push → silent refresh of Orders + Dashboard ViewModels.
    // This ensures new-order notifications trigger a live data reload
    // regardless of which tab the vendor is currently viewing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pushService = context.read<PushNotificationService>();
      final ordersVm = context.read<OrdersViewModel>();
      final dashboardVm = context.read<DashboardViewModel>();

      pushService.onRefreshOrders = () {
        ordersVm.fetchOrders();
      };

      // Connect WebSocket for real-time order updates
      final wsService = context.read<WebSocketService>();
      wsService.connectNotifications();
      ordersVm.listenToWebSocket(wsService.onNotification);

      // Deep-link: notification tap → Orders tab + order detail
      pushService.onNavigateToOrder = (orderId) {
        // Switch to Orders tab
        _navigateToTab(1);
        // Refresh and then navigate to the order detail
        ordersVm.fetchOrders().then((_) {
          if (!mounted) return;
          final order = ordersVm.findOrderById(orderId);
          if (order != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                  order: order,
                  vm: ordersVm,
                ),
              ),
            );
          }
        });
        dashboardVm.fetchDashboard();
      };
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screens ??= [
      const DashboardScreen(),
      const OrdersScreen(),
      const MenuScreen(),
      EarningsScreen(apiService: context.read<ApiService>()),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Go back through tab history
        if (_tabHistory.length > 1) {
          setState(() {
            _tabHistory.removeLast();
            _currentIndex = _tabHistory.last;
          });
          return;
        }
        // At root (Dashboard) — show exit confirmation (guard against double-tap)
        if (_isExitDialogShowing) return;
        _isExitDialogShowing = true;
        showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ).then((exit) {
          _isExitDialogShowing = false;
          if (exit == true) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens!),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: AppStrings.dashboard,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: AppStrings.orders,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: AppStrings.menu,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: AppStrings.bank,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: AppStrings.profile,
            ),
          ],
        ),
      ),
    ),
    );
  }
}
