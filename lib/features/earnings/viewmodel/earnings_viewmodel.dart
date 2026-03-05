import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────
//  Models — keys match the Django response exactly
// ─────────────────────────────────────────────────────────────────────

class EarningsWallet {
  final double grossBalance;
  final double availableBalance;
  final double pendingSettlement;
  final double heldBalance;

  const EarningsWallet({
    required this.grossBalance,
    required this.availableBalance,
    required this.pendingSettlement,
    required this.heldBalance,
  });

  factory EarningsWallet.fromJson(Map<String, dynamic> j) => EarningsWallet(
    grossBalance: _d(j['gross_balance']),
    availableBalance: _d(j['available_balance']),
    pendingSettlement: _d(j['pending_settlement']),
    heldBalance: _d(j['held_balance']),
  );
}

class EarningsCommission {
  final double rate;
  final String rateDisplay;
  final String gstRate;

  const EarningsCommission({
    required this.rate,
    required this.rateDisplay,
    required this.gstRate,
  });

  factory EarningsCommission.fromJson(Map<String, dynamic> j) =>
      EarningsCommission(
        rate: _d(j['rate']),
        rateDisplay: j['rate_display']?.toString() ?? '',
        gstRate: j['gst_rate']?.toString() ?? '',
      );
}

class EarningsPending {
  final int orderCount;
  final double grossAmount;
  final double estimatedNet;

  const EarningsPending({
    required this.orderCount,
    required this.grossAmount,
    required this.estimatedNet,
  });

  factory EarningsPending.fromJson(Map<String, dynamic> j) => EarningsPending(
    orderCount: (j['order_count'] as num?)?.toInt() ?? 0,
    grossAmount: _d(j['gross_amount']),
    estimatedNet: _d(j['estimated_net']),
  );
}

class EarningsLifetime {
  final double grossEarnings;
  final double totalCommission;
  final double totalGst;
  final double totalSettlements;

  const EarningsLifetime({
    required this.grossEarnings,
    required this.totalCommission,
    required this.totalGst,
    required this.totalSettlements,
  });

  factory EarningsLifetime.fromJson(Map<String, dynamic> j) => EarningsLifetime(
    grossEarnings: _d(j['gross_earnings']),
    totalCommission: _d(j['total_commission']),
    totalGst: _d(j['total_gst']),
    totalSettlements: _d(j['total_settlements']),
  );
}

class EarningsSettlement {
  final String cycle;
  final double minAmount;

  const EarningsSettlement({required this.cycle, required this.minAmount});

  factory EarningsSettlement.fromJson(Map<String, dynamic> j) =>
      EarningsSettlement(
        cycle: j['cycle']?.toString() ?? 'weekly',
        minAmount: _d(j['min_amount']),
      );

  String get cycleDisplay {
    switch (cycle) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return cycle;
    }
  }
}

class Payout {
  final String payoutId;
  final double amount;
  final double fees;
  final double netAmount;
  final String mode;
  final String status;
  final String? utr;
  final String initiatedAt;
  final String? processedAt;
  final String? failureReason;

  const Payout({
    required this.payoutId,
    required this.amount,
    required this.fees,
    required this.netAmount,
    required this.mode,
    required this.status,
    this.utr,
    required this.initiatedAt,
    this.processedAt,
    this.failureReason,
  });

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        payoutId: j['payout_id']?.toString() ?? '',
        amount: _d(j['amount']),
        fees: _d(j['fees']),
        netAmount: _d(j['net_amount']),
        mode: j['mode']?.toString() ?? '',
        status: j['status']?.toString() ?? 'pending',
        utr: j['utr']?.toString(),
        initiatedAt: j['initiated_at']?.toString() ?? '',
        processedAt: j['processed_at']?.toString(),
        failureReason: j['failure_reason']?.toString(),
      );

  bool get isSuccessful => status == 'processed';
  bool get isFailed =>
      const ['failed', 'reversed', 'cancelled'].contains(status);
  bool get isPending =>
      const ['queued', 'pending', 'processing'].contains(status);
}

class RecentOrderEarning {
  final String orderNumber;
  final double subtotal;
  final double grossAmount;
  final double commission;
  final double gst;
  final double netAmount;

  /// Raw ISO-8601 string — stored as-is for display; never null.
  final String createdAt;

  const RecentOrderEarning({
    required this.orderNumber,
    required this.subtotal,
    required this.grossAmount,
    required this.commission,
    required this.gst,
    required this.netAmount,
    required this.createdAt,
  });

  factory RecentOrderEarning.fromJson(Map<String, dynamic> j) =>
      RecentOrderEarning(
        orderNumber: j['order_number']?.toString() ?? '',
        subtotal: _d(j['subtotal']),
        grossAmount: _d(j['gross_amount']),
        commission: _d(j['commission']),
        gst: _d(j['gst']),
        netAmount: _d(j['net_amount']),
        createdAt: j['created_at']?.toString() ?? '',
      );

  /// True if this order was placed today (UTC).
  bool get isToday {
    if (createdAt.isEmpty) return false;
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }
}

class EarningsSummary {
  final EarningsWallet wallet;
  final EarningsCommission commission;
  final EarningsPending pending;
  final EarningsLifetime lifetime;
  final EarningsSettlement settlement;
  final List<RecentOrderEarning> recentOrders;

  const EarningsSummary({
    required this.wallet,
    required this.commission,
    required this.pending,
    required this.lifetime,
    required this.settlement,
    required this.recentOrders,
  });

  /// Sum of net_amount for orders that are from today.
  double get todayRevenue => recentOrders
      .where((o) => o.isToday)
      .fold(0.0, (sum, o) => sum + o.netAmount);

  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
    wallet: EarningsWallet.fromJson(
      (j['wallet'] as Map<String, dynamic>?) ?? {},
    ),
    commission: EarningsCommission.fromJson(
      (j['commission'] as Map<String, dynamic>?) ?? {},
    ),
    pending: EarningsPending.fromJson(
      (j['pending'] as Map<String, dynamic>?) ?? {},
    ),
    lifetime: EarningsLifetime.fromJson(
      (j['lifetime'] as Map<String, dynamic>?) ?? {},
    ),
    settlement: EarningsSettlement.fromJson(
      (j['settlement'] as Map<String, dynamic>?) ?? {},
    ),
    recentOrders: ((j['recent_orders'] as List<dynamic>?) ?? [])
        .map((e) => RecentOrderEarning.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────
//  Settlement history model
// ─────────────────────────────────────────────────────────────────────

class Settlement {
  final String settlementId;
  final String period;
  final int ordersCount;
  final double grossAmount;
  final double commissionAmount;
  final double commissionRate;
  final double taxOnCommission;
  final double deductions;
  final double netAmount;

  /// "pending" | "processing" | "completed" | "failed" | "on_hold"
  final String status;
  final String transactionId;
  final String createdAt;

  /// Nullable — null means not yet processed.
  final String? processedAt;

  const Settlement({
    required this.settlementId,
    required this.period,
    required this.ordersCount,
    required this.grossAmount,
    required this.commissionAmount,
    required this.commissionRate,
    required this.taxOnCommission,
    required this.deductions,
    required this.netAmount,
    required this.status,
    required this.transactionId,
    required this.createdAt,
    this.processedAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
    settlementId: j['settlement_id']?.toString() ?? '',
    period: j['period']?.toString() ?? '',
    ordersCount: (j['orders_count'] as num?)?.toInt() ?? 0,
    grossAmount: _d(j['gross_amount']),
    commissionAmount: _d(j['commission_amount']),
    commissionRate: _d(j['commission_rate']),
    taxOnCommission: _d(j['tax_on_commission']),
    deductions: _d(j['deductions']),
    netAmount: _d(j['net_amount']),
    status: j['status']?.toString() ?? 'pending',
    transactionId: j['transaction_id']?.toString() ?? '',
    createdAt: j['created_at']?.toString() ?? '',
    processedAt: j['processed_at']?.toString(),
  );
}

// ─────────────────────────────────────────────────────────────────────
//  Status enum
// ─────────────────────────────────────────────────────────────────────

enum EarningsStatus { fetching, idle, error }

// ─────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────

class EarningsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  EarningsViewModel({required ApiService apiService})
    : _apiService = apiService;

  // ── State ──────────────────────────────────────────────────────────
  EarningsStatus _status = EarningsStatus.fetching;
  EarningsSummary? _summary;
  List<Settlement> _settlements = [];
  int _totalSettlements = 0;
  String? _errorMessage;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _hasMore = true;

  // ── Getters ────────────────────────────────────────────────────────
  EarningsStatus get status => _status;
  EarningsSummary? get summary => _summary;
  List<Settlement> get settlements => List.unmodifiable(_settlements);
  int get totalSettlements => _totalSettlements;
  String? get errorMessage => _errorMessage;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasSummary => _summary != null;

  // ── Initial load — fires both requests in parallel ─────────────────
  Future<void> loadAll() async {
    _status = EarningsStatus.fetching;
    _errorMessage = null;
    _settlements = [];
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.get(ApiEndpoints.vendorEarnings),
        _apiService.get(
          ApiEndpoints.settlementHistory,
          queryParameters: {'page': 1, 'per_page': _perPage},
        ),
      ]);

      final earningsBody = results[0].data as Map<String, dynamic>;
      _summary = EarningsSummary.fromJson(earningsBody);

      final historyBody = results[1].data as Map<String, dynamic>;
      _totalSettlements = (historyBody['total'] as num?)?.toInt() ?? 0;
      final rawList = (historyBody['settlements'] as List<dynamic>?) ?? [];
      _settlements = rawList
          .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
          .toList();
      _hasMore = _settlements.length < _totalSettlements;

      _status = EarningsStatus.idle;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = EarningsStatus.error;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = EarningsStatus.error;
      debugPrint('[EarningsViewModel] loadAll: $e');
    }
    notifyListeners();
  }

  // ── Load more settlements (pagination) ────────────────────────────
  Future<void> loadMoreSettlements() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final resp = await _apiService.get(
        ApiEndpoints.settlementHistory,
        queryParameters: {'page': _currentPage, 'per_page': _perPage},
      );
      final body = resp.data as Map<String, dynamic>;
      final rawList = (body['settlements'] as List<dynamic>?) ?? [];
      final newItems = rawList
          .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
          .toList();
      _settlements = [..._settlements, ...newItems];
      _hasMore = _settlements.length < _totalSettlements;
    } on DioException catch (e) {
      debugPrint(
        '[EarningsViewModel] loadMoreSettlements: ${_parseDioError(e)}',
      );
      _currentPage--; // roll back so next attempt retries correct page
    } catch (e) {
      _currentPage--;
      debugPrint('[EarningsViewModel] loadMoreSettlements: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // ── Refresh ────────────────────────────────────────────────────────
  Future<void> refresh() => loadAll();

  // ── Helper ─────────────────────────────────────────────────────────
  String _parseDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          'Server error (${e.response?.statusCode})';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your network and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      default:
        return 'Network error. Please try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Shared helper — safe Decimal/double parse
// ─────────────────────────────────────────────────────────────────────
double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
