// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
//
//  Models for the auto-payout earnings flow.
//  Backend: GET /api/payments/vendor/earnings/
//  (this_week + payout_info + lifetime + payout_history)
//
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────
//  Shared helper — safe Decimal/double parse
// ─────────────────────────────────────────────────────────────────────
double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────
//  this_week.daily_breakdown[*]
// ─────────────────────────────────────────────────────────────────────
class DailyEarning {
  final DateTime date;
  final int orders;
  final double earnings;

  const DailyEarning({
    required this.date,
    required this.orders,
    required this.earnings,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> j) => DailyEarning(
        date: _date(j['date']) ?? DateTime.now(),
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        earnings: _d(j['earnings']),
      );

  /// "Mon", "Tue" etc. — used as bar-chart x-axis label.
  String get shortDay {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(date.weekday - 1) % 7];
  }
}

// ─────────────────────────────────────────────────────────────────────
//  this_week
// ─────────────────────────────────────────────────────────────────────
class ThisWeekEarnings {
  final String periodLabel;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int totalOrders;
  final double grossEarnings;
  final double commissionDeducted;
  final double gstDeducted;
  final double penalties;
  final double netEarnings;
  final List<DailyEarning> dailyBreakdown;

  const ThisWeekEarnings({
    this.periodLabel = '',
    this.periodStart,
    this.periodEnd,
    this.totalOrders = 0,
    this.grossEarnings = 0,
    this.commissionDeducted = 0,
    this.gstDeducted = 0,
    this.penalties = 0,
    this.netEarnings = 0,
    this.dailyBreakdown = const [],
  });

  factory ThisWeekEarnings.fromJson(Map<String, dynamic> j) => ThisWeekEarnings(
        periodLabel: j['period']?.toString() ?? '',
        periodStart: _date(j['period_start']),
        periodEnd: _date(j['period_end']),
        totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
        grossEarnings: _d(j['gross_earnings']),
        commissionDeducted: _d(j['commission_deducted']),
        gstDeducted: _d(j['gst_deducted']),
        penalties: _d(j['penalties']),
        netEarnings: _d(j['net_earnings']),
        dailyBreakdown: ((j['daily_breakdown'] as List?) ?? const [])
            .map((e) => DailyEarning.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// True if any day this week had at least one order — used to decide
  /// whether to render the chart or an empty-state placeholder.
  bool get hasAnyActivity =>
      dailyBreakdown.any((d) => d.orders > 0 || d.earnings > 0);

  double get peakDailyEarning =>
      dailyBreakdown.fold<double>(0, (m, d) => d.earnings > m ? d.earnings : m);
}

// ─────────────────────────────────────────────────────────────────────
//  payout_info
// ─────────────────────────────────────────────────────────────────────
enum BankStatus { verified, pendingVerification, notAdded, unknown }

BankStatus _bankStatusFrom(String? raw) {
  switch (raw) {
    case 'verified':
      return BankStatus.verified;
    case 'pending_verification':
      return BankStatus.pendingVerification;
    case 'not_added':
      return BankStatus.notAdded;
    default:
      return BankStatus.unknown;
  }
}

class PayoutInfo {
  final DateTime? nextPayoutDate;
  final double estimatedAmount;
  final String bankAccount;
  final BankStatus bankStatus;
  final String payoutSchedule;
  final double minimumPayout;
  final double carryForwardAmount;
  final String message;

  const PayoutInfo({
    this.nextPayoutDate,
    this.estimatedAmount = 0,
    this.bankAccount = 'Not added',
    this.bankStatus = BankStatus.unknown,
    this.payoutSchedule = 'Every Monday',
    this.minimumPayout = 0,
    this.carryForwardAmount = 0,
    this.message = '',
  });

  factory PayoutInfo.fromJson(Map<String, dynamic> j) => PayoutInfo(
        nextPayoutDate: _date(j['next_payout_date']),
        estimatedAmount: _d(j['estimated_amount']),
        bankAccount: j['bank_account']?.toString() ?? 'Not added',
        bankStatus: _bankStatusFrom(j['bank_status']?.toString()),
        payoutSchedule: j['payout_schedule']?.toString() ?? 'Every Monday',
        minimumPayout: _d(j['minimum_payout']),
        carryForwardAmount: _d(j['carry_forward_amount']),
        message: j['message']?.toString() ?? '',
      );

  bool get bankReady => bankStatus == BankStatus.verified;
  bool get hasCarryForward => carryForwardAmount > 0;
  bool get belowMinPayout =>
      minimumPayout > 0 && estimatedAmount > 0 && estimatedAmount < minimumPayout;
}

// ─────────────────────────────────────────────────────────────────────
//  lifetime
// ─────────────────────────────────────────────────────────────────────
class LifetimeEarnings {
  final double totalEarned;
  final double totalPaidOut;
  final double totalCommission;
  final double totalGst;
  final double totalPenalties;

  const LifetimeEarnings({
    this.totalEarned = 0,
    this.totalPaidOut = 0,
    this.totalCommission = 0,
    this.totalGst = 0,
    this.totalPenalties = 0,
  });

  factory LifetimeEarnings.fromJson(Map<String, dynamic> j) => LifetimeEarnings(
        totalEarned: _d(j['total_earned']),
        totalPaidOut: _d(j['total_paid_out']),
        totalCommission: _d(j['total_commission']),
        totalGst: _d(j['total_gst']),
        totalPenalties: _d(j['total_penalties']),
      );
}

// ─────────────────────────────────────────────────────────────────────
//  payout_history[*]
// ─────────────────────────────────────────────────────────────────────
class PayoutHistoryEntry {
  final String settlementId;
  final String periodLabel;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double amount;
  final String status;
  final String statusDisplay;
  final String utr;
  final DateTime? paidOn;

  const PayoutHistoryEntry({
    required this.settlementId,
    this.periodLabel = '',
    this.periodStart,
    this.periodEnd,
    this.amount = 0,
    this.status = 'pending',
    this.statusDisplay = 'Pending',
    this.utr = '',
    this.paidOn,
  });

  factory PayoutHistoryEntry.fromJson(Map<String, dynamic> j) =>
      PayoutHistoryEntry(
        settlementId: j['settlement_id']?.toString() ?? '',
        periodLabel: j['period']?.toString() ?? '',
        periodStart: _date(j['period_start']),
        periodEnd: _date(j['period_end']),
        amount: _d(j['amount']),
        status: j['status']?.toString() ?? 'pending',
        statusDisplay: j['status_display']?.toString() ?? 'Pending',
        utr: j['utr']?.toString() ?? '',
        paidOn: _date(j['paid_on']),
      );

  bool get isPaid => status == 'completed' || status == 'processed';
  bool get isAwaitingBank => status == 'awaiting_bank_info';
  bool get isFailed =>
      const ['failed', 'reversed', 'cancelled'].contains(status);
}

// ─────────────────────────────────────────────────────────────────────
//  Aggregate summary — root response
// ─────────────────────────────────────────────────────────────────────
class EarningsSummary {
  final ThisWeekEarnings thisWeek;
  final PayoutInfo payoutInfo;
  final LifetimeEarnings lifetime;
  final List<PayoutHistoryEntry> payoutHistory;

  const EarningsSummary({
    this.thisWeek = const ThisWeekEarnings(),
    this.payoutInfo = const PayoutInfo(),
    this.lifetime = const LifetimeEarnings(),
    this.payoutHistory = const [],
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
        thisWeek: ThisWeekEarnings.fromJson(
          (j['this_week'] as Map<String, dynamic>?) ?? const {},
        ),
        payoutInfo: PayoutInfo.fromJson(
          (j['payout_info'] as Map<String, dynamic>?) ?? const {},
        ),
        lifetime: LifetimeEarnings.fromJson(
          (j['lifetime'] as Map<String, dynamic>?) ?? const {},
        ),
        payoutHistory: ((j['payout_history'] as List?) ?? const [])
            .map((e) => PayoutHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Surface awaiting_bank settlements first — vendor must update bank to
  /// unblock these.
  PayoutHistoryEntry? get firstAwaitingBank {
    for (final p in payoutHistory) {
      if (p.isAwaitingBank) return p;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Standalone Payout (from /payments/vendor/payouts/)
//  Kept here so other ViewModels (transactions_viewmodel) can reuse it.
// ─────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────
//  Standalone Settlement (from /payments/settlements/history/)
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
  final String status;
  final String transactionId;
  final String createdAt;
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
//  ViewModel — used standalone (e.g. transactions screen calls loadAll).
// ─────────────────────────────────────────────────────────────────────
class EarningsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  EarningsViewModel({required ApiService apiService})
      : _apiService = apiService;

  EarningsStatus _status = EarningsStatus.fetching;
  EarningsSummary? _summary;
  List<Settlement> _settlements = [];
  int _totalSettlements = 0;
  String? _errorMessage;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _hasMore = true;

  EarningsStatus get status => _status;
  EarningsSummary? get summary => _summary;
  List<Settlement> get settlements => List.unmodifiable(_settlements);
  int get totalSettlements => _totalSettlements;
  String? get errorMessage => _errorMessage;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasSummary => _summary != null;

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

      _summary = EarningsSummary.fromJson(
        results[0].data as Map<String, dynamic>,
      );

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
      _currentPage--;
    } catch (e) {
      _currentPage--;
      debugPrint('[EarningsViewModel] loadMoreSettlements: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> refresh() => loadAll();

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
