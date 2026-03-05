import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

enum DashboardStatus { initial, loading, loaded, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Lightweight model for recent orders shown on dashboard
// ─────────────────────────────────────────────────────────────────────────────

class RecentOrder {
  final int id;
  final String orderNumber;
  final String customerName;
  final double totalAmount;
  final String status;
  final int itemsCount;
  final DateTime createdAt;

  const RecentOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.totalAmount,
    required this.status,
    required this.itemsCount,
    required this.createdAt,
  });

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'] as String? ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return RecentOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number'] as String? ?? '#${json['id']}',
      customerName: json['customer_name'] as String? ?? 'Customer',
      totalAmount: (json['grand_total'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble() ??
          0.0,
      status: (json['status'] as String? ?? 'unknown').toLowerCase().trim(),
      itemsCount: (json['item_count'] as num?)?.toInt() ??
          (json['items_count'] as num?)?.toInt() ??
          0,
      createdAt: parsedDate,
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'picked':
      case 'on_the_way':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashboard data model
// ─────────────────────────────────────────────────────────────────────────────

class DashboardData {
  final int todayOrders;
  final double todayRevenue;
  final double rating;
  final int menuCount;
  final bool isStoreOpen;
  final String storeName;
  final bool isVerified;
  // menu stats
  final int totalItems;
  final int availableItems;
  final int categories;
  // profile completion
  final int profileCompletion;
  // today hours
  final String todayOpenTime;
  final String todayCloseTime;

  const DashboardData({
    this.todayOrders = 0,
    this.todayRevenue = 0.0,
    this.rating = 0.0,
    this.menuCount = 0,
    this.isStoreOpen = false,
    this.storeName = '',
    this.isVerified = false,
    this.totalItems = 0,
    this.availableItems = 0,
    this.categories = 0,
    this.profileCompletion = 0,
    this.todayOpenTime = '',
    this.todayCloseTime = '',
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>? ?? {};
    final menuStats = json['menu_stats'] as Map<String, dynamic>? ?? {};
    final profileComp =
        json['profile_completion'] as Map<String, dynamic>? ?? {};
    final todayHours = json['today_hours'] as Map<String, dynamic>? ?? {};

    return DashboardData(
      todayOrders: (json['today_orders'] as num?)?.toInt() ?? 0,
      todayRevenue: (json['today_revenue'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      menuCount: (json['menu_count'] as num?)?.toInt() ?? 0,
      isStoreOpen: restaurant['is_open_now'] as bool? ?? false,
      storeName: restaurant['name'] as String? ?? '',
      isVerified: restaurant['is_verified'] as bool? ?? false,
      totalItems: (menuStats['total_items'] as num?)?.toInt() ?? 0,
      availableItems: (menuStats['available_items'] as num?)?.toInt() ?? 0,
      categories: (menuStats['categories'] as num?)?.toInt() ?? 0,
      profileCompletion: (profileComp['percentage'] as num?)?.toInt() ?? 0,
      todayOpenTime: todayHours['open_time'] as String? ?? '',
      todayCloseTime: todayHours['close_time'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────────────

class DashboardViewModel extends ChangeNotifier {
  final ApiService _apiService;

  DashboardStatus _status = DashboardStatus.initial;
  DashboardData _data = const DashboardData();
  String? _errorMessage;
  bool _isToggling = false;

  // Recent orders, pending count & unread notifications
  List<RecentOrder> _recentOrders = [];
  int _pendingCount = 0;
  int _unreadNotifications = 0;

  DashboardViewModel({required ApiService apiService})
      : _apiService = apiService;

  // ── Getters ──────────────────────────────────────────────────────────────
  DashboardStatus get status => _status;
  DashboardData get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DashboardStatus.loading;
  bool get hasData => _status == DashboardStatus.loaded;

  /// True only while the toggle API call is in-flight.
  bool get isToggling => _isToggling;

  List<RecentOrder> get recentOrders => List.unmodifiable(_recentOrders);
  int get pendingCount => _pendingCount;
  int get unreadNotifications => _unreadNotifications;

  // ── Fetch dashboard + pending + recent orders + unread count (4 parallel) ──
  Future<void> fetchDashboard() async {
    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // .then<dynamic> widens Future<Response> → Future<dynamic> before
    // .catchError so that returning the error object is type-safe in Dart 3.x.
    final results = await Future.wait<dynamic>([
      _apiService.get(ApiEndpoints.dashboard)
          .then<dynamic>((r) => r).catchError((Object e) => e),
      _apiService
          .get(ApiEndpoints.vendorOrders,
              queryParameters: {'status': 'pending'})
          .then<dynamic>((r) => r)
          .catchError((Object e) => e),
      _apiService.get(ApiEndpoints.vendorOrders)
          .then<dynamic>((r) => r).catchError((Object e) => e),
      _apiService.get(ApiEndpoints.notificationsStats)
          .then<dynamic>((r) => r).catchError((Object e) => e),
    ]);

    // If any request returned a 401 or cancel, the session expired and the
    // user is being navigated to login. Return silently — DO NOT set error
    // state or call notifyListeners() to avoid UI jank/flicker.
    for (final r in results) {
      if (r is DioException &&
          (r.response?.statusCode == 401 ||
              r.type == DioExceptionType.cancel)) {
        return;
      }
    }

    // ── Parse dashboard summary ──────────────────────────────────────
    bool dashboardOk = false;
    if (results[0] is Response) {
      try {
        _data = DashboardData.fromJson(
            (results[0] as Response).data as Map<String, dynamic>);
        dashboardOk = true;
      } catch (e) {
        debugPrint('[Dashboard] parse error: $e');
      }
    } else if (results[0] is DioException) {
      _errorMessage = _parseError(results[0] as DioException);
    }

    // ── Parse pending orders count ───────────────────────────────────
    if (results[1] is Response) {
      try {
        final body = (results[1] as Response).data;
        if (body is Map<String, dynamic>) {
          final orders = body['orders'] as List<dynamic>? ?? [];
          _pendingCount = orders.length;
        }
      } catch (e) {
        debugPrint('[Dashboard] pending parse: $e');
      }
    }

    // ── Parse recent orders (latest 3) ───────────────────────────────
    if (results[2] is Response) {
      try {
        final body = (results[2] as Response).data;
        if (body is Map<String, dynamic>) {
          final orders = body['orders'] as List<dynamic>? ?? [];
          _recentOrders = orders
              .take(3)
              .map((e) => RecentOrder.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[Dashboard] recent orders parse: $e');
      }
    }

    // ── Parse unread notifications count ────────────────────────────
    if (results[3] is Response) {
      try {
        final body = (results[3] as Response).data;
        if (body is Map<String, dynamic>) {
          _unreadNotifications = (body['unread'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        debugPrint('[Dashboard] notifications stats parse: $e');
      }
    }

    _status = dashboardOk ? DashboardStatus.loaded : DashboardStatus.error;
    _errorMessage ??= dashboardOk ? null : 'Failed to load dashboard data.';
    notifyListeners();
  }

  // ── Toggle store open/closed  POST /api/vendors/toggle-availability/ ───
  Future<void> toggleStore() async {
    if (_isToggling) return; // prevent double-tap
    _isToggling = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final shouldClose = _data.isStoreOpen;
      await _apiService.post(
        ApiEndpoints.restaurantToggle,
        data: {'is_temporarily_closed': shouldClose},
      );
      // Re-fetch to get the server-confirmed state
      await fetchDashboard();
    } catch (_) {
      _errorMessage = 'Failed to update store status. Please try again.';
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  String _parseError(DioException e) {
    if (e.response == null) {
      return e.type == DioExceptionType.connectionError
          ? 'Cannot reach server. Is Django running on port 8000?'
          : 'Network error. Please check your connection.';
    }
    final data = e.response!.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] != null) return data['detail'].toString();
    }
    return 'Error ${e.response!.statusCode}. Could not load dashboard.';
  }
}
