// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/verification_status.dart';
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
  /// `restaurant.is_active` — false if admin has disabled the restaurant.
  final bool isActive;
  // 3-state status: 'online', 'busy', 'offline'
  final String storeStatus;
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
    this.isActive = true,
    this.storeStatus = 'offline',
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

    // Parse 3-state status — fallback to the vendor's explicit toggle
    // choice (`is_temporarily_closed`) rather than the computed
    // `is_open_now` (which factors in operating hours and returns
    // false when no hours are set — making the toggle snap back to
    // offline even after the vendor turned it on).
    final rawStatus = restaurant['store_status'] as String?;
    final isTempClosed =
        restaurant['is_temporarily_closed'] as bool? ?? false;
    final storeStatus = rawStatus ??
        (isTempClosed ? 'offline' : 'online');

    return DashboardData(
      todayOrders: (json['today_orders'] as num?)?.toInt() ?? 0,
      todayRevenue: (json['today_revenue'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      menuCount: (json['menu_count'] as num?)?.toInt() ?? 0,
      isStoreOpen: storeStatus == 'online',
      storeName: restaurant['name'] as String? ?? '',
      isVerified: restaurant['is_verified'] as bool? ?? false,
      isActive: restaurant['is_active'] as bool? ?? true,
      storeStatus: storeStatus,
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

  /// Verification state machine — sourced from /vendors/profile/
  /// (`verification_status` top-level field, computed in
  /// food-delivery-api/vendors/views.py:563).
  /// Defaults to `pending` until first fetch resolves.
  VerificationStatus _verificationStatus = VerificationStatus.pending;
  VerificationStatus get verificationStatus => _verificationStatus;

  /// True once the vendor has filled in the bare minimum of their
  /// restaurant profile. Surfaced for the "Complete your setup"
  /// banner / progress card — NOT used to block the Accepting
  /// Orders toggle. The web dashboard
  /// (frontend_pages/vendor/dashboard.html → updateOnlineStatus)
  /// enables the toggle as soon as the restaurant row exists,
  /// even at 83% completion with delivery zones missing. The app
  /// must mirror that — over-gating the toggle blocked vendors
  /// who couldn't add delivery zones (e.g. when zone creation
  /// itself was failing) from ever going live.
  bool get isProfileComplete => _data.profileCompletion >= 100;

  /// True when:
  ///   1. KYC is approved by admin, AND
  ///   2. The restaurant row is `is_active=true`.
  /// Profile completion is intentionally NOT a hard gate here —
  /// the web vendor portal lets vendors flip "Accepting Orders"
  /// at any completion %. The Complete-your-Setup banner already
  /// nudges them to finish missing sections without locking the
  /// toggle.
  bool get canAcceptOrders =>
      _verificationStatus.isApproved && _data.isActive;

  // Recent orders, pending count & unread notifications
  List<RecentOrder> _recentOrders = [];
  int _pendingCount = 0;
  int _unreadNotifications = 0;

  StreamSubscription<void>? _sessionClearedSub;

  DashboardViewModel({required ApiService apiService})
      : _apiService = apiService {
    // Flush state when the user logs out (explicit or 401) so the
    // next vendor to sign in doesn't see the previous one's
    // restaurant name, recent orders, or notification count.
    _sessionClearedSub =
        ApiService.onSessionExpired.listen((_) => clearSession());
  }

  @override
  void dispose() {
    _sessionClearedSub?.cancel();
    super.dispose();
  }

  /// Reset every field that is tied to the logged-in vendor. Called
  /// automatically on session clear; safe to call directly as well.
  void clearSession() {
    _status = DashboardStatus.initial;
    _data = const DashboardData();
    _errorMessage = null;
    _isToggling = false;
    _verificationStatus = VerificationStatus.pending;
    _recentOrders = [];
    _pendingCount = 0;
    _unreadNotifications = 0;
    notifyListeners();
  }

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

  // ── Fetch dashboard + pending + recent + notifications + verification ──
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
      // /vendors/profile/ exposes the computed `verification_status` and
      // `is_verified` flags that gate the "Accepting Orders" toggle
      // and feed the verification banner. The dashboard endpoint itself
      // does NOT include the verification_status string.
      _apiService.get(ApiEndpoints.profile)
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
      // Hard failure on the primary dashboard call — most commonly a
      // 404 "Restaurant not found" when admin deletes the vendor's
      // restaurant mid-session. Wipe the cached fields so the UI
      // can't render the deleted restaurant's name/revenue/orders
      // alongside the retry banner (the visual glitch reported on
      // 2026-04-21).
      _data = const DashboardData();
      _recentOrders = [];
      _pendingCount = 0;
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
          // Backend returns {"stats": {"unread_count": N}}
          final stats = body['stats'] as Map<String, dynamic>?;
          _unreadNotifications =
              (stats?['unread_count'] as num?)?.toInt() ??
              (body['unread_count'] as num?)?.toInt() ??
              (body['unread'] as num?)?.toInt() ??
              0;
        }
      } catch (e) {
        debugPrint('[Dashboard] notifications stats parse: $e');
      }
    }

    // ── Parse verification_status from /vendors/profile/ ────────────
    if (results[4] is Response) {
      try {
        final body = (results[4] as Response).data;
        if (body is Map<String, dynamic>) {
          _verificationStatus = VerificationStatus.fromApi(
            body['verification_status'] as String?,
          );
        }
      } catch (e) {
        debugPrint('[Dashboard] verification_status parse: $e');
      }
    }

    _status = dashboardOk ? DashboardStatus.loaded : DashboardStatus.error;
    _errorMessage ??= dashboardOk ? null : 'Failed to load dashboard data.';
    notifyListeners();
  }

  // ── Lightweight unread-count refresh ───────────────────────────
  /// Hits only `/notifications/stats/` (not the full 5-endpoint
  /// dashboard load) so the bell-icon badge can live-update whenever
  /// a push / websocket event tells us new activity happened. Safe to
  /// call frequently; errors are swallowed silently.
  Future<void> refreshNotificationCount() async {
    try {
      final res = await _apiService.get(ApiEndpoints.notificationsStats);
      final body = res.data;
      if (body is! Map<String, dynamic>) return;
      final stats = body['stats'] as Map<String, dynamic>?;
      final count = (stats?['unread_count'] as num?)?.toInt() ??
          (body['unread_count'] as num?)?.toInt() ??
          (body['unread'] as num?)?.toInt();
      if (count != null && count != _unreadNotifications) {
        _unreadNotifications = count;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort — next fetchDashboard() will correct any drift.
    }
  }

  // ── Toggle store open/closed  POST /api/vendors/toggle-availability/ ───
  /// Legacy 2-state toggle (online ↔ offline). Kept for backward compat.
  Future<void> toggleStore() async {
    final newStatus = _data.storeStatus == 'online' ? 'offline' : 'online';
    await setStoreStatus(newStatus);
  }

  /// Set store to a specific 3-state status: 'online', 'busy', or 'offline'.
  Future<void> setStoreStatus(String status) async {
    if (_isToggling) return; // prevent double-tap
    final goingOnline = status == 'online';
    // Client-side mirror of the backend KYC gate at
    // vendors/views.py ToggleRestaurantAvailabilityView.post().
    // Only block going online — the vendor must always be able to go
    // offline, otherwise a freshly-rejected-docs scenario could trap
    // them accepting orders. The UI already hides the switch when
    // locked; this is defense-in-depth for programmatic callers.
    if (goingOnline && !canAcceptOrders) {
      _errorMessage = _data.isActive
          ? 'Verification required. Complete KYC to go online.'
          : 'Your restaurant is disabled by admin. Contact support.';
      notifyListeners();
      return;
    }
    _isToggling = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        ApiEndpoints.restaurantToggle,
        data: {
          'store_status': status,
          // Backward compat: backend may still read this field
          'is_temporarily_closed': !goingOnline,
        },
      );
      // Re-fetch to get the server-confirmed state
      await fetchDashboard();
    } on DioException catch (e) {
      // Backend rejects go-online attempts while KYC is unapproved
      // with a 403 whose body is
      // `{code: 'verification_required', detail: ..., error: <human>}`.
      // We check `code` (programmatic identifier) rather than `error`
      // because `error` now carries the human-readable message so web
      // callers can display it directly.
      final body = e.response?.data;
      if (e.response?.statusCode == 403 &&
          body is Map &&
          body['code'] == 'verification_required') {
        _errorMessage = (body['detail'] as String?) ??
            (body['error'] as String?) ??
            'Verification required. Complete KYC to go online.';
        // Re-fetch so the UI re-renders the locked card based on the
        // now-authoritative verification_status from /vendors/profile/.
        await fetchDashboard();
      } else {
        _errorMessage = 'Failed to update store status. Please try again.';
      }
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
    // 401 leaks through here when the auth interceptor decides not to
    // retry (e.g. refresh-token rejection). Show a clear, actionable
    // message instead of the generic "Cannot reach server" text —
    // vendors were getting stuck on the dashboard banner thinking the
    // network was down, when really their session had expired.
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
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
