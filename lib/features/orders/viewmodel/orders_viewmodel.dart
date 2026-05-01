// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_logger.dart';
import '../services/order_timer_store.dart';

// ── Addon Item ────────────────────────────────────────────────────────
class OrderAddonItem {
  final int id;
  final String addonName;
  final double addonPrice;

  const OrderAddonItem({
    required this.id,
    required this.addonName,
    required this.addonPrice,
  });

  factory OrderAddonItem.fromJson(Map<String, dynamic> json) {
    return OrderAddonItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      addonName: json['addon_name'] as String? ?? '',
      addonPrice:
          double.tryParse((json['addon_price'] ?? '0').toString()) ?? 0.0,
    );
  }
}

// ── Order Line Item ───────────────────────────────────────────────────
class OrderLineItem {
  final int id;
  final String itemName;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double addonsPrice;
  final double subtotal;
  final int preparationTime; // minutes
  final String specialInstructions;
  final String? menuItemImage;
  final List<OrderAddonItem> selectedAddons;

  const OrderLineItem({
    required this.id,
    required this.itemName,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.addonsPrice,
    required this.subtotal,
    this.preparationTime = 0,
    this.specialInstructions = '',
    this.menuItemImage,
    this.selectedAddons = const [],
  });

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    final rawAddons = json['selected_addons'] as List<dynamic>? ?? [];
    return OrderLineItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      itemName: json['item_name'] as String? ?? 'Item',
      variantName: json['variant_name'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: double.tryParse((json['unit_price'] ?? '0').toString()) ?? 0.0,
      addonsPrice:
          double.tryParse((json['addons_price'] ?? '0').toString()) ?? 0.0,
      subtotal: double.tryParse((json['subtotal'] ?? '0').toString()) ?? 0.0,
      preparationTime: (json['preparation_time'] as num?)?.toInt() ?? 0,
      specialInstructions: json['special_instructions'] as String? ?? '',
      menuItemImage: json['menu_item_image'] as String?,
      selectedAddons: rawAddons
          .whereType<Map<String, dynamic>>()
          .map(OrderAddonItem.fromJson)
          .toList(),
    );
  }
}

// ── Order (from list / detail endpoint) ──────────────────────────────
class VendorOrder {
  final int id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final String status;
  final double totalAmount;
  final int itemsCount;
  final DateTime createdAt;
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryAddress;
  final String instructions;
  final List<OrderLineItem> items;
  final List<String> itemsSummary;
  // Order type classification
  final String orderType; // 'delivery' | 'takeaway' | 'dine_in'
  final bool isScheduled;
  final DateTime? scheduledFor;
  final bool acceptedByRestaurant;
  // Real-time ETA fields (may be null until order is accepted)
  final DateTime? estimatedDeliveryTime;
  final int? estimatedPrepTime; // minutes
  // Recipient info (may differ from customer for gift/proxy orders)
  final String? recipientName;
  final String? recipientPhone;
  // Payment verification
  final bool isPaymentVerified;

  VendorOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.totalAmount,
    required this.itemsCount,
    required this.createdAt,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryAddress,
    required this.instructions,
    required this.items,
    this.itemsSummary = const [],
    this.orderType = 'delivery',
    this.isScheduled = false,
    this.scheduledFor,
    this.acceptedByRestaurant = false,
    this.estimatedDeliveryTime,
    this.estimatedPrepTime,
    this.recipientName,
    this.recipientPhone,
    this.isPaymentVerified = false,
  });

  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    // Parse safely — never crash on unexpected / missing fields
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'] as String? ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime? parsedEta;
    try {
      final raw = json['estimated_delivery_time'] as String?;
      if (raw != null && raw.isNotEmpty) parsedEta = DateTime.parse(raw);
    } catch (_) {}

    DateTime? parsedScheduledFor;
    try {
      final raw = json['scheduled_for'] as String?;
      if (raw != null && raw.isNotEmpty) {
        parsedScheduledFor = DateTime.parse(raw);
      }
    } catch (_) {}

    // Parse items list — returned by RestaurantOrderListSerializer
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .whereType<Map<String, dynamic>>()
        .map(OrderLineItem.fromJson)
        .toList();

    // items_summary: backend-computed short strings e.g. "1x French Fries"
    final rawSummary = json['items_summary'] as List<dynamic>? ?? [];
    final parsedSummary = rawSummary.whereType<String>().toList();

    return VendorOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number'] as String? ?? '#${json['id']}',
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String? ?? '',
      status: (json['status'] as String? ?? 'unknown').toLowerCase().trim(),
      totalAmount:
          (json['grand_total'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble() ??
          0.0,
      itemsCount:
          (json['item_count'] as num?)?.toInt() ??
          (json['items_count'] as num?)?.toInt() ??
          parsedItems.length,
      createdAt: parsedDate,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      items: parsedItems,
      itemsSummary: parsedSummary,
      orderType: json['order_type'] as String? ?? 'delivery',
      isScheduled: json['is_scheduled'] as bool? ?? false,
      scheduledFor: parsedScheduledFor,
      acceptedByRestaurant: json['accepted_by_restaurant'] as bool? ?? false,
      estimatedDeliveryTime: parsedEta,
      estimatedPrepTime: (json['estimated_prep_time'] as num?)?.toInt(),
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      isPaymentVerified: json['is_payment_verified'] as bool? ?? false,
    );
  }
}

// ── Extended detail (populated from /orders/{id}/) ────────────────────
class VendorOrderDetail {
  final VendorOrder order;
  final double deliveryCharge;
  final double taxAmount;
  final double discountAmount;
  final double subtotal; // = total_amount (before delivery/tax)
  final String deliveryInstructions;
  final String couponCode;
  final double couponDiscount;
  final String cancellationNote;
  final String cancellationReason;
  final bool isPlatformFundedCoupon;

  const VendorOrderDetail({
    required this.order,
    required this.deliveryCharge,
    required this.taxAmount,
    required this.discountAmount,
    required this.subtotal,
    required this.deliveryInstructions,
    required this.couponCode,
    required this.couponDiscount,
    required this.cancellationNote,
    required this.cancellationReason,
    this.isPlatformFundedCoupon = false,
  });

  factory VendorOrderDetail.fromJson(Map<String, dynamic> json) {
    return VendorOrderDetail(
      order: VendorOrder.fromJson(json),
      deliveryCharge:
          double.tryParse((json['delivery_charge'] ?? '0').toString()) ?? 0.0,
      taxAmount: double.tryParse((json['tax_amount'] ?? '0').toString()) ?? 0.0,
      discountAmount:
          double.tryParse((json['discount_amount'] ?? '0').toString()) ?? 0.0,
      subtotal:
          double.tryParse((json['total_amount'] ?? '0').toString()) ?? 0.0,
      deliveryInstructions: json['delivery_instructions'] as String? ?? '',
      couponCode: json['coupon_code'] as String? ?? '',
      couponDiscount:
          double.tryParse((json['coupon_discount'] ?? '0').toString()) ?? 0.0,
      cancellationNote: json['cancellation_note'] as String? ?? '',
      cancellationReason: json['cancellation_reason'] as String? ?? '',
      isPlatformFundedCoupon: json['is_platform_funded_coupon'] as bool? ?? false,
    );
  }
}

// ── ViewModel ────────────────────────────────────────────────────────
enum OrdersStatus { initial, loading, loaded, error }

class OrdersViewModel extends ChangeNotifier {
  final ApiService _api;
  StreamSubscription<void>? _sessionExpiredSub;
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  OrdersViewModel({required ApiService apiService}) : _api = apiService {
    _sessionExpiredSub = ApiService.onSessionExpired.listen((_) {
      AppLogger.w('[Orders] Session cleared — stopping polling + wiping state');
      clearSession();
    });
  }

  /// Reset every vendor-scoped field. Called on explicit logout AND
  /// on 401 so the next signed-in vendor never sees the previous
  /// one's order lists or active-order badge count.
  void clearSession() {
    stopAutoRefresh();
    _wsSub?.cancel();
    _wsSub = null;
    _status = OrdersStatus.initial;
    _error = null;
    _newOrders = [];
    _preparingOrders = [];
    _readyOrders = [];
    _completedOrders = [];
    _cancelledOrders = [];
    _actionLoading.clear();
    _lastErrorCode = null;
    notifyListeners();
  }

  // ── WebSocket integration ──────────────────────────────────────────
  /// Call once after login to listen for real-time order events.
  /// On each relevant WS message, triggers an immediate silent refresh
  /// so the vendor sees new/updated orders without waiting for the poll.
  void listenToWebSocket(Stream<Map<String, dynamic>> wsStream) {
    _wsSub?.cancel();
    _wsSub = wsStream.listen((data) {
      final type = data['type'] as String? ?? '';
      if (type == 'new_notification' || type == 'order_update' ||
          type == 'new_order' || type == 'order_cancelled' ||
          type == 'order_status_updated' || type == 'status_update') {
        AppLogger.i('[Orders] WS event "$type" — refreshing');
        _silentRefresh();
      }
    });
  }

  OrdersStatus _status = OrdersStatus.initial;
  String? _error;

  // Five lists for five tabs
  List<VendorOrder> _newOrders = [];
  List<VendorOrder> _preparingOrders = [];
  List<VendorOrder> _readyOrders = [];
  List<VendorOrder> _completedOrders = [];
  List<VendorOrder> _cancelledOrders = [];

  // Action loading state — tracks which order id is being acted on
  final Set<int> _actionLoading = {};

  // Pagination limits for Completed / Cancelled tabs (load 10 at a time)
  static const _pageSize = 10;
  int _completedLimit = _pageSize;
  int _cancelledLimit = _pageSize;

  // Periodic auto-refresh (every 20 seconds) so vendors don't miss new orders
  static const _autoRefreshInterval = Duration(seconds: 20);
  Timer? _autoRefreshTimer;

  // ── Search & filter state ─────────────────────────────────────────
  String _searchQuery = '';
  DateTimeRange? _dateFilter;
  List<VendorOrder> _searchResults = [];
  bool _isSearching = false;
  bool _searchHasMore = false;
  int _searchPage = 1;
  bool _searchLoading = false;

  // Getters
  OrdersStatus get status => _status;
  String? get error => _error;
  List<VendorOrder> get newOrders => _newOrders;
  List<VendorOrder> get preparingOrders => _preparingOrders;
  List<VendorOrder> get readyOrders => _readyOrders;
  List<VendorOrder> get completedOrders => _completedOrders;
  List<VendorOrder> get cancelledOrders => _cancelledOrders;
  int get completedLimit => _completedLimit;
  int get cancelledLimit => _cancelledLimit;
  bool isActionLoading(int id) => _actionLoading.contains(id);

  // Search getters
  String get searchQuery => _searchQuery;
  DateTimeRange? get dateFilter => _dateFilter;
  List<VendorOrder> get searchResults => _searchResults;
  bool get isSearchActive => _isSearching;
  bool get searchHasMore => _searchHasMore;
  bool get searchLoading => _searchLoading;

  /// Search all order lists for a specific order by ID.
  VendorOrder? findOrderById(int id) {
    for (final list in [
      _newOrders,
      _preparingOrders,
      _readyOrders,
      _completedOrders,
      _cancelledOrders,
    ]) {
      for (final order in list) {
        if (order.id == id) return order;
      }
    }
    return null;
  }

  void loadMoreCompleted() {
    _completedLimit += _pageSize;
    notifyListeners();
  }

  void loadMoreCancelled() {
    _cancelledLimit += _pageSize;
    notifyListeners();
  }

  // ── Search & Filter ────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty && _dateFilter == null) {
      _isSearching = false;
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    _searchPage = 1;
    _searchResults = [];
    notifyListeners();
    _executeSearch();
  }

  void setDateFilter(DateTimeRange? range) {
    _dateFilter = range;
    if (_searchQuery.isEmpty && range == null) {
      _isSearching = false;
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    _searchPage = 1;
    _searchResults = [];
    notifyListeners();
    _executeSearch();
  }

  void clearSearch() {
    _searchQuery = '';
    _dateFilter = null;
    _isSearching = false;
    _searchResults = [];
    _searchPage = 1;
    _searchHasMore = false;
    notifyListeners();
  }

  void loadMoreSearchResults() {
    if (_searchLoading || !_searchHasMore) return;
    _searchPage++;
    _executeSearch(append: true);
  }

  Future<void> _executeSearch({bool append = false}) async {
    _searchLoading = true;
    if (!append) notifyListeners();

    try {
      final params = <String, dynamic>{
        'page': _searchPage,
        'per_page': 20,
      };
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_dateFilter != null) {
        params['date_from'] = _dateFilter!.start.toIso8601String().split('T').first;
        params['date_to'] = _dateFilter!.end.toIso8601String().split('T').first;
      }

      final response = await _api.get(
        ApiEndpoints.vendorOrders,
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final list = (data['orders'] as List<dynamic>? ?? [])
          .map((e) => VendorOrder.fromJson(e as Map<String, dynamic>))
          .toList();

      if (append) {
        _searchResults = [..._searchResults, ...list];
      } else {
        _searchResults = list;
      }
      _searchHasMore = data['has_more'] as bool? ?? false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      AppLogger.e('[Orders] search failed: ${e.message}');
    } catch (e) {
      AppLogger.e('[Orders] search unexpected: $e');
    }

    _searchLoading = false;
    notifyListeners();
  }

  // ── Fetch all four buckets in parallel ──────────────────────────
  Future<void> fetchOrders() async {
    _status = OrdersStatus.loading;
    _error = null;
    _completedLimit = _pageSize;
    _cancelledLimit = _pageSize;
    notifyListeners();

    try {
      // NOTE: The backend does an exact ORM filter (status=X), so we must
      // send one request per status value and combine the results ourselves.
      //
      // New tab       = pending (awaiting Accept) + confirmed (awaiting Start Preparing)
      // Preparing     = preparing only
      // Ready/Active  = ready + picked + on_the_way (keeps tracking alive)
      // Completed     = delivered + refunded  (strictly finished orders)
      // Cancelled     = cancelled only
      final results = await Future.wait([
        _fetchMultipleStatuses(['pending', 'confirmed']),
        _fetchMultipleStatuses(['preparing']),
        _fetchMultipleStatuses(['ready', 'picked', 'on_the_way']),
        _fetchMultipleStatuses(['delivered', 'refunded']),
        _fetchMultipleStatuses(['cancelled']),
      ]);

      _newOrders = results[0];
      _preparingOrders = results[1];
      _readyOrders = results[2];
      _completedOrders = results[3];
      _cancelledOrders = results[4];
      _status = OrdersStatus.loaded;
    } on DioException catch (e) {
      // If the request was cancelled or got a 401 (session expired, logging
      // out), return silently — the user is being redirected to login.
      // DO NOT set error state or call notifyListeners() to avoid UI jank.
      if (e.type == DioExceptionType.cancel ||
          e.response?.statusCode == 401) {
        stopAutoRefresh();
        return;
      }
      _error = _parseError(e);
      _status = OrdersStatus.error;
      AppLogger.e('fetchOrders DioException: ${e.response?.statusCode}');
    } catch (e, st) {
      _error = 'Unexpected error. Please try again.';
      _status = OrdersStatus.error;
      AppLogger.e('fetchOrders unexpected', e, st);
    }

    notifyListeners();
  }

  // Fetches multiple individual statuses and merges them (newest first)
  Future<List<VendorOrder>> _fetchMultipleStatuses(
    List<String> statuses,
  ) async {
    final lists = await Future.wait(statuses.map((s) => _fetchSingleStatus(s)));
    final combined = lists.expand((l) => l).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  Future<List<VendorOrder>> _fetchSingleStatus(String statusValue) async {
    try {
      final response = await _api.get(
        ApiEndpoints.vendorOrders,
        queryParameters: {'status': statusValue},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        AppLogger.w('[Orders] Unexpected response type: ${data.runtimeType}');
        return [];
      }
      final list = data['orders'] as List<dynamic>? ?? [];
      return list
          .map((e) => VendorOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // 401 or cancel (session expired / logging out) → rethrow so
      // fetchOrders() can exit early without updating UI.
      if (e.response?.statusCode == 401 ||
          e.type == DioExceptionType.cancel) {
        rethrow;
      }
      // A per-status error must NOT kill the whole fetch — log and return []
      AppLogger.e(
        '[Orders] _fetchSingleStatus($statusValue) '
        'HTTP ${e.response?.statusCode}: ${e.message}',
      );
      if (e.response?.statusCode == 500) {
        AppLogger.w(
          '[Orders] 500 on "$statusValue" — likely pending DB migration. '
          'Run: python manage.py migrate',
        );
      }
      return [];
    }
  }

  // ── Accept (pending → confirmed) ─────────────────────────────────
  Future<bool> acceptOrder(int orderId, {int estimatedPrepTime = 30}) async {
    return _doAction(
      orderId: orderId,
      call: () => _api.post(
        ApiEndpoints.orderAccept(orderId),
        data: {'estimated_preparation_time': estimatedPrepTime},
      ),
      onSuccess: (order) {
        // confirmed stays in the New tab — update in-place so the
        // 'Start Preparing' button appears immediately without a full refresh.
        final idx = _newOrders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          _newOrders[idx] = order;
        } else {
          _newOrders.insert(0, order);
        }
        // Anchor the prep-time countdown starting NOW. Persisted so
        // the MM:SS timer on the order card survives app restart.
        OrderTimerStore.instance
            .setDeadline(orderId, estimatedPrepTime);
      },
    );
  }

  // ── Reject (pending → cancelled) ─────────────────────────────────
  Future<bool> rejectOrder(
    int orderId, {
    String reason = 'Restaurant is busy',
    String cancellationReason = 'restaurant_busy',
  }) async {
    return _doAction(
      orderId: orderId,
      call: () => _api.post(
        ApiEndpoints.orderReject(orderId),
        data: {'reason': reason, 'cancellation_reason': cancellationReason},
      ),
      onSuccess: (_) {
        _newOrders.removeWhere((o) => o.id == orderId);
        OrderTimerStore.instance.clear(orderId);
      },
    );
  }

  // ── Start Preparing (confirmed → preparing) ────────────────────
  Future<bool> startPreparing(int orderId,
      {int? restartPrepMinutes}) async {
    return _doAction(
      orderId: orderId,
      call: () => _api.post(
        ApiEndpoints.orderStatus(orderId),
        data: {'status': 'preparing'},
      ),
      onSuccess: (order) {
        // Moves from New tab → Preparing tab
        _newOrders.removeWhere((o) => o.id == orderId);
        _preparingOrders.insert(0, order);
        // Optionally restart the countdown from "now + N" when the
        // caller passes a new prep duration (used by the Preparing
        // action button so the timer reflects actual kitchen start
        // rather than the accept time).
        if (restartPrepMinutes != null && restartPrepMinutes > 0) {
          OrderTimerStore.instance
              .setDeadline(orderId, restartPrepMinutes);
        }
      },
    );
  }

  // ── Mark as Ready (preparing → ready) ───────────────────────────
  Future<bool> markReady(int orderId) async {
    return _doAction(
      orderId: orderId,
      call: () => _api.post(
        ApiEndpoints.orderStatus(orderId),
        data: {'status': 'ready'},
      ),
      onSuccess: (order) {
        _preparingOrders.removeWhere((o) => o.id == orderId);
        _readyOrders.insert(0, order);
        // Dish is done — drop the countdown.
        OrderTimerStore.instance.clear(orderId);
      },
    );
  }

  // ── Generic action helper ─────────────────────────────────────────
  Future<bool> _doAction({
    required int orderId,
    required Future<Response> Function() call,
    required void Function(VendorOrder) onSuccess,
  }) async {
    _actionLoading.add(orderId);
    notifyListeners();

    try {
      final response = await call();
      final data = response.data as Map<String, dynamic>;
      final orderMap = data['order'] as Map<String, dynamic>?;
      final updated = orderMap != null
          ? VendorOrder.fromJson(orderMap)
          : _placeholder(orderId);
      onSuccess(updated);
      _actionLoading.remove(orderId);
      notifyListeners();
      // Silent background refresh to sync with server
      _silentRefresh().ignore();
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      AppLogger.e('Order action error: ${e.response?.data}');
      return false;
    } catch (e) {
      _error = 'Unexpected error.';
      return false;
    } finally {
      _actionLoading.remove(orderId);
      notifyListeners();
    }
  }

  // ── Silent background sync (no loading spinner) ───────────────────
  Future<void> _silentRefresh() async {
    try {
      final results = await Future.wait([
        _fetchMultipleStatuses(['pending', 'confirmed']),
        _fetchMultipleStatuses(['preparing']),
        _fetchMultipleStatuses(['ready', 'picked', 'on_the_way']),
        _fetchMultipleStatuses(['delivered', 'refunded']),
        _fetchMultipleStatuses(['cancelled']),
      ]);
      _newOrders = results[0];
      _preparingOrders = results[1];
      _readyOrders = results[2];
      _completedOrders = results[3];
      _cancelledOrders = results[4];
      notifyListeners();
    } catch (e) {
      // 401 / cancel → session expired, stop the auto-refresh timer and
      // return silently. No notifyListeners() — login screen is rendering.
      if (e is DioException &&
          (e.response?.statusCode == 401 ||
              e.type == DioExceptionType.cancel)) {
        stopAutoRefresh();
        return;
      }
      AppLogger.w('Silent refresh failed: $e');
      // Intentionally silent — user still has optimistic update
    }
  }

  VendorOrder _placeholder(int id) => VendorOrder(
    id: id,
    orderNumber: '#$id',
    customerName: '',
    customerPhone: '',
    status: 'updated',
    totalAmount: 0,
    itemsCount: 0,
    createdAt: DateTime.now(),
    paymentMethod: '',
    paymentStatus: 'pending',
    deliveryAddress: '',
    instructions: '',
    items: const [],
    itemsSummary: const [],
    orderType: 'delivery',
    isScheduled: false,
  );

  // ── Fetch full order detail (/orders/{id}/) ───────────────────────
  /// Last reason `fetchOrderDetail` failed — populated by the next
  /// fetch and consumed by the UI to render a specific error string
  /// instead of the older generic "Could not load order details" line.
  /// Keeping it on the VM (not the call site) means follow-up retries
  /// can pick up the new error too.
  String? _lastDetailError;
  String? get lastDetailError => _lastDetailError;

  Future<VendorOrderDetail?> fetchOrderDetail(int orderId) async {
    _lastDetailError = null;
    try {
      final response = await _api.get(ApiEndpoints.orderDetail(orderId));
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _lastDetailError =
            'Server returned an unexpected response (${data.runtimeType}).';
        AppLogger.e(
          'fetchOrderDetail($orderId): non-map body type=${data.runtimeType}',
        );
        return null;
      }
      return VendorOrderDetail.fromJson(data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      // Surface the most actionable message we can. 401 means the
      // token rotated out — the auth interceptor will eventually push
      // /login, but in the meantime tell the vendor what's happening
      // instead of hiding it behind "Could not load…".
      if (code == 401) {
        _lastDetailError = 'Session expired. Please log in again.';
      } else if (code == 403) {
        _lastDetailError = 'You don\'t have access to this order.';
      } else if (code == 404) {
        _lastDetailError = 'Order not found. It may have been removed.';
      } else if (code != null && code >= 500) {
        _lastDetailError =
            'Server error ($code). Please try again in a moment.';
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        _lastDetailError = 'Network issue. Check your connection and retry.';
      } else if (body is Map &&
          (body['error'] is String || body['detail'] is String)) {
        _lastDetailError = (body['error'] ?? body['detail']).toString();
      } else {
        _lastDetailError = 'Could not load order details.';
      }
      AppLogger.e(
        'fetchOrderDetail($orderId) failed: '
        'type=${e.type} status=$code body=$body',
      );
      return null;
    } catch (e, st) {
      // Most often a JSON parsing problem — log the trace so we can
      // pin down which field blew up. Don't swallow the type silently.
      _lastDetailError = 'Failed to read order details (${e.runtimeType}).';
      AppLogger.e('fetchOrderDetail($orderId) parse/unknown: $e\n$st');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Auto-refresh ────────────────────────────────────────────────
  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _silentRefresh();
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _sessionExpiredSub?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  // ── Error parser ─────────────────────────────────────────────────
  String _parseError(DioException e) {
    if (e.response == null) return 'Cannot reach server.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      // Subscription gates shipped with the 2026-04-20 backend update
      // return a structured `{error, code}` body where `code` is one
      // of SUBSCRIPTION_SUSPENDED / PLAN_LIMIT_EXCEEDED. We surface
      // the human-readable `error` verbatim — it already says "Please
      // renew your plan…" and the UI can deep-link to subscription
      // later by inspecting _lastErrorCode.
      final code = data['code'];
      if (data['error'] is String) {
        if (code == 'SUBSCRIPTION_SUSPENDED' ||
            code == 'PLAN_LIMIT_EXCEEDED') {
          _lastErrorCode = code as String;
        }
        return data['error'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['errors'] is Map) {
        final err = data['errors'] as Map;
        return err['error']?.toString() ?? err.values.first.toString();
      }
    }
    return 'Error (HTTP ${e.response!.statusCode})';
  }

  /// Last error's machine-readable `code` (e.g. 'SUBSCRIPTION_SUSPENDED'),
  /// null for generic errors. Lets the UI branch on specific gate
  /// failures to show a deep-link to subscription / upgrade screens
  /// instead of just a toast.
  String? _lastErrorCode;
  String? get lastErrorCode => _lastErrorCode;
  void clearLastErrorCode() => _lastErrorCode = null;
}
