import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

enum AnalyticsStatus { initial, loading, loaded, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsMetrics {
  final double totalRevenue;
  final int totalOrders;
  final int newCustomers;
  final double avgRating;

  const AnalyticsMetrics({
    this.totalRevenue = 0,
    this.totalOrders = 0,
    this.newCustomers = 0,
    this.avgRating = 0,
  });

  factory AnalyticsMetrics.fromJson(Map<String, dynamic> json) {
    return AnalyticsMetrics(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      newCustomers: (json['new_customers'] as num?)?.toInt() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RevenueTrendPoint {
  final DateTime date;
  final double total;

  const RevenueTrendPoint({required this.date, required this.total});

  factory RevenueTrendPoint.fromJson(Map<String, dynamic> json) {
    DateTime parsed;
    try {
      parsed = DateTime.parse(json['date'] as String? ?? '');
    } catch (_) {
      parsed = DateTime.now();
    }
    return RevenueTrendPoint(
      date: parsed,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderStatusCount {
  final String status;
  final int count;

  const OrderStatusCount({required this.status, required this.count});

  factory OrderStatusCount.fromJson(Map<String, dynamic> json) {
    return OrderStatusCount(
      status: (json['status'] as String? ?? 'unknown').toLowerCase().trim(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName {
    switch (status) {
      case 'completed':
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
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
        return 'In Transit';
      case 'refunded':
        return 'Refunded';
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }
}

class TopSellingItem {
  final String name;
  final int orders;
  final double revenue;
  final String? image;

  const TopSellingItem({
    required this.name,
    required this.orders,
    required this.revenue,
    this.image,
  });

  factory TopSellingItem.fromJson(Map<String, dynamic> json) {
    return TopSellingItem(
      name: json['name'] as String? ?? 'Unknown',
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      image: json['image'] as String?,
    );
  }
}

class PaymentMethodCount {
  final String method;
  final int count;

  const PaymentMethodCount({required this.method, required this.count});

  factory PaymentMethodCount.fromJson(Map<String, dynamic> json) {
    return PaymentMethodCount(
      method: json['payment_method'] as String? ?? 'other',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName {
    switch (method.toLowerCase()) {
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      case 'cod':
      case 'cash':
        return 'Cash';
      case 'wallet':
        return 'Wallet';
      case 'net_banking':
      case 'netbanking':
        return 'Net Banking';
      default:
        if (method.isEmpty) return 'Other';
        return method[0].toUpperCase() + method.substring(1);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Aggregate data holder
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsData {
  final AnalyticsMetrics metrics;
  final List<RevenueTrendPoint> revenueTrend;
  final List<OrderStatusCount> orderStatus;
  final List<TopSellingItem> topItems;
  final List<PaymentMethodCount> paymentMethods;

  const AnalyticsData({
    this.metrics = const AnalyticsMetrics(),
    this.revenueTrend = const [],
    this.orderStatus = const [],
    this.topItems = const [],
    this.paymentMethods = const [],
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      metrics: AnalyticsMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>? ?? {},
      ),
      revenueTrend: (json['revenue_trend'] as List<dynamic>? ?? [])
          .map((e) => RevenueTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      orderStatus: (json['order_status'] as List<dynamic>? ?? [])
          .map((e) => OrderStatusCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      topItems: (json['top_items'] as List<dynamic>? ?? [])
          .map((e) => TopSellingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentMethods: (json['payment_methods'] as List<dynamic>? ?? [])
          .map((e) => PaymentMethodCount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Maximum daily revenue in the trend (for scaling the bar chart).
  double get maxRevenue {
    if (revenueTrend.isEmpty) return 0;
    return revenueTrend
        .map((e) => e.total)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Total orders across all statuses.
  int get totalStatusOrders =>
      orderStatus.fold(0, (sum, e) => sum + e.count);
}

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────────────

class AnalyticsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  AnalyticsStatus _status = AnalyticsStatus.initial;
  AnalyticsData _data = const AnalyticsData();
  String? _errorMessage;

  // Date range filter
  DateTime? _startDate;
  DateTime? _endDate;

  AnalyticsViewModel({required ApiService apiService})
      : _apiService = apiService;

  // ── Getters ──────────────────────────────────────────────────────────────
  AnalyticsStatus get status => _status;
  AnalyticsData get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AnalyticsStatus.loading;
  bool get hasData => _status == AnalyticsStatus.loaded;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  // ── Fetch ────────────────────────────────────────────────────────────────
  Future<void> fetchAnalytics() async {
    _status = AnalyticsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> params = {};
      if (_startDate != null) {
        params['startDate'] = _formatDate(_startDate!);
      }
      if (_endDate != null) {
        params['endDate'] = _formatDate(_endDate!);
      }

      final response = await _apiService.get(
        ApiEndpoints.analytics,
        queryParameters: params.isNotEmpty ? params : null,
      );

      _data = AnalyticsData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _status = AnalyticsStatus.loaded;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _status = AnalyticsStatus.error;
    } catch (e) {
      debugPrint('[Analytics] unexpected error: $e');
      _errorMessage = 'Failed to load analytics data.';
      _status = AnalyticsStatus.error;
    }
    notifyListeners();
  }

  // ── Date range helpers ───────────────────────────────────────────────────
  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    fetchAnalytics();
  }

  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    fetchAnalytics();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Private ──────────────────────────────────────────────────────────────
  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _parseError(DioException e) {
    if (e.response == null) {
      return e.type == DioExceptionType.connectionError
          ? 'Cannot reach server. Is Django running on port 8000?'
          : 'Network error. Please check your connection.';
    }
    final data = e.response!.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['error'] is String) return data['error'] as String;
      if (data['detail'] != null) return data['detail'].toString();
    }
    return 'Error ${e.response!.statusCode}. Could not load analytics.';
  }
}
