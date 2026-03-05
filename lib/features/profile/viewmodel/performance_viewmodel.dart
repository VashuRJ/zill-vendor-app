import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

enum PerformanceStatus { initial, loading, loaded, error }

// ── Helpers ───────────────────────────────────────────────────────────────────
double _asD(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _asI(dynamic v) => (v is int) ? v : int.tryParse(v?.toString() ?? '0') ?? 0;

// ── Models ────────────────────────────────────────────────────────────────────

class PerformanceMetrics {
  final int totalOrders30d;
  final int completedOrders30d;
  final int cancelledByVendor30d;
  final int cancelledByCustomer30d;
  final int totalOrdersLifetime;
  final int cancelledByVendorLifetime;
  final double acceptanceRate;
  final double cancellationRate;
  final double completionRate;
  final double performanceScore;
  final String healthStatus;
  final int activeStrikes;
  final int totalPenalties;
  final double totalPenaltyAmount;
  final bool isSuspended;
  final String? suspendedUntil;
  final String suspensionReason;
  final String? lastCalculatedAt;

  const PerformanceMetrics({
    this.totalOrders30d = 0,
    this.completedOrders30d = 0,
    this.cancelledByVendor30d = 0,
    this.cancelledByCustomer30d = 0,
    this.totalOrdersLifetime = 0,
    this.cancelledByVendorLifetime = 0,
    this.acceptanceRate = 0,
    this.cancellationRate = 0,
    this.completionRate = 0,
    this.performanceScore = 0,
    this.healthStatus = 'excellent',
    this.activeStrikes = 0,
    this.totalPenalties = 0,
    this.totalPenaltyAmount = 0,
    this.isSuspended = false,
    this.suspendedUntil,
    this.suspensionReason = '',
    this.lastCalculatedAt,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      totalOrders30d: _asI(json['total_orders_30d']),
      completedOrders30d: _asI(json['completed_orders_30d']),
      cancelledByVendor30d: _asI(json['cancelled_by_vendor_30d']),
      cancelledByCustomer30d: _asI(json['cancelled_by_customer_30d']),
      totalOrdersLifetime: _asI(json['total_orders_lifetime']),
      cancelledByVendorLifetime: _asI(json['cancelled_by_vendor_lifetime']),
      acceptanceRate: _asD(json['acceptance_rate']),
      cancellationRate: _asD(json['cancellation_rate']),
      completionRate: _asD(json['completion_rate']),
      performanceScore: _asD(json['performance_score']),
      healthStatus: json['health_status'] as String? ?? 'excellent',
      activeStrikes: _asI(json['active_strikes']),
      totalPenalties: _asI(json['total_penalties']),
      totalPenaltyAmount: _asD(json['total_penalty_amount']),
      isSuspended: json['is_suspended'] as bool? ?? false,
      suspendedUntil: json['suspended_until'] as String?,
      suspensionReason: json['suspension_reason'] as String? ?? '',
      lastCalculatedAt: json['last_calculated_at'] as String?,
    );
  }
}

class RatingBreakdown {
  final double avgRestaurantRating;
  final double avgFoodRating;
  final double avgDeliveryRating;
  final int totalReviews;
  final Map<int, int> distribution; // key 1-5

  const RatingBreakdown({
    this.avgRestaurantRating = 0,
    this.avgFoodRating = 0,
    this.avgDeliveryRating = 0,
    this.totalReviews = 0,
    this.distribution = const {},
  });

  factory RatingBreakdown.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribution'] as Map<String, dynamic>? ?? {};
    final dist = <int, int>{};
    rawDist.forEach((k, v) {
      final key = int.tryParse(k);
      if (key != null) {
        dist[key] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      }
    });

    return RatingBreakdown(
      avgRestaurantRating: _asD(json['average_restaurant_rating']),
      avgFoodRating: _asD(json['average_food_rating']),
      avgDeliveryRating: _asD(json['average_delivery_rating']),
      totalReviews: (json['total_reviews'] is int)
          ? json['total_reviews'] as int
          : int.tryParse(json['total_reviews']?.toString() ?? '0') ?? 0,
      distribution: dist,
    );
  }
}

class PenaltySummary {
  final int totalPenalties;
  final int totalWarnings;
  final int totalFines;
  final int totalSuspensions;
  final int totalDeactivations;
  final double totalAmountDeducted;
  final int unresolvedCount;

  const PenaltySummary({
    this.totalPenalties = 0,
    this.totalWarnings = 0,
    this.totalFines = 0,
    this.totalSuspensions = 0,
    this.totalDeactivations = 0,
    this.totalAmountDeducted = 0,
    this.unresolvedCount = 0,
  });

  factory PenaltySummary.fromJson(Map<String, dynamic> json) {
    return PenaltySummary(
      totalPenalties: _asI(json['total_penalties']),
      totalWarnings: _asI(json['total_warnings']),
      totalFines: _asI(json['total_fines']),
      totalSuspensions: _asI(json['total_suspensions']),
      totalDeactivations: _asI(json['total_deactivations']),
      totalAmountDeducted: _asD(json['total_amount_deducted']),
      unresolvedCount: _asI(json['unresolved_count']),
    );
  }
}

class PenaltyRecord {
  final int id;
  final String penaltyType;
  final String penaltyTypeDisplay;
  final String severity; // warning | fine | suspension | deactivation
  final String severityDisplay;
  final int strikeNumber;
  final double penaltyAmount;
  final String reason;
  final bool autoApplied;
  final bool isResolved;
  final String? resolutionNote;
  final String? resolvedAt;
  final String? orderNumber;
  final String createdAt;

  const PenaltyRecord({
    required this.id,
    required this.penaltyType,
    required this.penaltyTypeDisplay,
    required this.severity,
    required this.severityDisplay,
    required this.strikeNumber,
    required this.penaltyAmount,
    required this.reason,
    required this.autoApplied,
    required this.isResolved,
    this.resolutionNote,
    this.resolvedAt,
    this.orderNumber,
    required this.createdAt,
  });

  factory PenaltyRecord.fromJson(Map<String, dynamic> json) {
    return PenaltyRecord(
      id: _asI(json['id']),
      penaltyType: json['penalty_type'] as String? ?? '',
      penaltyTypeDisplay: json['penalty_type_display'] as String? ?? '',
      severity: json['severity'] as String? ?? 'warning',
      severityDisplay: json['severity_display'] as String? ?? '',
      strikeNumber: _asI(json['strike_number']),
      penaltyAmount: _asD(json['penalty_amount']),
      reason: json['reason'] as String? ?? '',
      autoApplied: json['auto_applied'] as bool? ?? false,
      isResolved: json['is_resolved'] as bool? ?? false,
      resolutionNote: json['resolution_note'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      orderNumber: json['order_number'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────

class PerformanceViewModel extends ChangeNotifier {
  final ApiService _api;
  PerformanceViewModel({required ApiService apiService}) : _api = apiService;

  PerformanceStatus _status = PerformanceStatus.initial;
  PerformanceStatus get status => _status;
  bool get isLoading => _status == PerformanceStatus.loading;

  PerformanceMetrics _metrics = const PerformanceMetrics();
  PerformanceMetrics get metrics => _metrics;

  RatingBreakdown _ratings = const RatingBreakdown();
  RatingBreakdown get ratings => _ratings;

  PenaltySummary _penaltySummary = const PenaltySummary();
  PenaltySummary get penaltySummary => _penaltySummary;

  List<PenaltyRecord> _penalties = const [];
  List<PenaltyRecord> get penalties => _penalties;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAll() async {
    _status = PerformanceStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.get(ApiEndpoints.performance),
        _api.get(ApiEndpoints.penalties),
      ]);

      final perfRes = results[0];
      final penRes = results[1];

      // Performance response
      if (perfRes.statusCode == 200) {
        final data = perfRes.data as Map<String, dynamic>;
        if (data['performance'] != null) {
          _metrics = PerformanceMetrics.fromJson(
            data['performance'] as Map<String, dynamic>,
          );
        }
        if (data['rating_breakdown'] != null) {
          _ratings = RatingBreakdown.fromJson(
            data['rating_breakdown'] as Map<String, dynamic>,
          );
        }
      }

      // Penalties response
      if (penRes.statusCode == 200) {
        final data = penRes.data as Map<String, dynamic>;
        if (data['summary'] != null) {
          _penaltySummary = PenaltySummary.fromJson(
            data['summary'] as Map<String, dynamic>,
          );
        }
        if (data['penalties'] != null) {
          final list = data['penalties'] as List<dynamic>;
          _penalties = list
              .map((e) => PenaltyRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      _status = PerformanceStatus.loaded;
    } catch (e) {
      _status = PerformanceStatus.error;
      _errorMessage = e.toString();
      debugPrint('PerformanceViewModel.fetchAll error: $e');
    }

    notifyListeners();
  }
}
