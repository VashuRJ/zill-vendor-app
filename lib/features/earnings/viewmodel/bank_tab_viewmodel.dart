import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import 'earnings_viewmodel.dart';

// Re-export the BankAccountData model so the screen can use it.
export '../../../features/profile/viewmodel/bank_account_viewmodel.dart'
    show BankAccountData;

import '../../../features/profile/viewmodel/bank_account_viewmodel.dart'
    show BankAccountData;

// ─────────────────────────────────────────────────────────────────────
//  Safe double parse (local)
// ─────────────────────────────────────────────────────────────────────
double _dLocal(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

// ─────────────────────────────────────────────────────────────────────
//  Models for /vendors/earnings/ response
// ─────────────────────────────────────────────────────────────────────

class PeriodStats {
  final double total;
  final int count;
  const PeriodStats({required this.total, required this.count});
}

class ChartDayData {
  final String day;
  final double amount;
  const ChartDayData({required this.day, required this.amount});
}

class VendorRecentTransaction {
  final int id;
  final String orderId;
  final double amount;
  final String date;
  final String status;
  final String customer;

  const VendorRecentTransaction({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.date,
    required this.status,
    required this.customer,
  });

  factory VendorRecentTransaction.fromJson(Map<String, dynamic> j) =>
      VendorRecentTransaction(
        id: (j['id'] as num?)?.toInt() ?? 0,
        orderId: j['order_id']?.toString() ?? '',
        amount: _dLocal(j['amount']),
        date: j['date']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        customer: j['customer']?.toString() ?? 'Guest',
      );
}

// ─────────────────────────────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────────────────────────────

enum BankTabStatus { fetching, idle, error }

enum PayoutRequestStatus { idle, requesting, success, error }

// ─────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────

class BankTabViewModel extends ChangeNotifier {
  final ApiService _apiService;
  bool _isDisposed = false;

  BankTabViewModel({required ApiService apiService}) : _apiService = apiService;

  /// Expose the API service for child navigations (e.g. TransactionsScreen).
  ApiService get apiService => _apiService;

  /// Safe notifyListeners — skips if already disposed.
  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── Earnings state ──────────────────────────────────────────────────
  BankTabStatus _status = BankTabStatus.fetching;
  EarningsSummary? _summary;
  String? _earningsError;

  // ── Bank state ──────────────────────────────────────────────────────
  BankAccountData? _bankData;
  bool _bankLoading = true;
  String? _bankError;
  bool _bankSaving = false;
  String? _bankSaveError;

  // ── Payouts state ──────────────────────────────────────────────────
  List<Payout> _payouts = [];
  bool _payoutsLoading = true;
  String? _payoutsError;
  int _totalPayouts = 0;

  // ── Payout request state ───────────────────────────────────────────
  PayoutRequestStatus _payoutReqStatus = PayoutRequestStatus.idle;
  String? _payoutReqError;

  // ── Settlements state (paginated) ──────────────────────────────────
  List<Settlement> _settlements = [];
  int _totalSettlements = 0;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _hasMore = true;

  // ── Time filter state ────────────────────────────────────────────
  String _selectedFilter = 'This Month';
  DateTimeRange? _customDateRange;

  // ── Vendor computed stats (from /vendors/earnings/) ──────────────
  double _vendorTotalEarnings = 0.0;
  int _vendorTotalOrders = 0;
  double _vendorAvgOrderValue = 0.0;
  Map<String, PeriodStats> _periodStats = {};
  List<ChartDayData> _chartDayData = [];
  List<VendorRecentTransaction> _vendorRecentTransactions = [];

  // ── Getters ────────────────────────────────────────────────────────
  BankTabStatus get status => _status;
  EarningsSummary? get summary => _summary;
  String? get earningsError => _earningsError;

  BankAccountData? get bankData => _bankData;
  bool get bankLoading => _bankLoading;
  String? get bankError => _bankError;
  bool get bankSaving => _bankSaving;
  String? get bankSaveError => _bankSaveError;

  List<Payout> get payouts => List.unmodifiable(_payouts);
  bool get payoutsLoading => _payoutsLoading;
  String? get payoutsError => _payoutsError;
  int get totalPayouts => _totalPayouts;

  PayoutRequestStatus get payoutReqStatus => _payoutReqStatus;
  String? get payoutReqError => _payoutReqError;

  List<Settlement> get settlements => List.unmodifiable(_settlements);
  int get totalSettlements => _totalSettlements;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  String get selectedFilter => _selectedFilter;
  DateTimeRange? get customDateRange => _customDateRange;

  double get vendorTotalEarnings => _vendorTotalEarnings;
  int get vendorTotalOrders => _vendorTotalOrders;
  double get vendorAvgOrderValue => _vendorAvgOrderValue;
  List<ChartDayData> get chartDayData => List.unmodifiable(_chartDayData);
  List<VendorRecentTransaction> get vendorRecentTransactions =>
      List.unmodifiable(_vendorRecentTransactions);

  /// Period stats matching the active time filter.
  PeriodStats get filteredPeriodStats {
    switch (_selectedFilter) {
      case 'Today':
        return _periodStats['today'] ?? const PeriodStats(total: 0, count: 0);
      case 'This Week':
        return _periodStats['week'] ?? const PeriodStats(total: 0, count: 0);
      case 'This Month':
        return _periodStats['month'] ?? const PeriodStats(total: 0, count: 0);
      default:
        // Custom range — fall back to client-side filtering
        final orders = filteredRecentOrders;
        return PeriodStats(
          total: orders.fold(0.0, (sum, o) => sum + o.netAmount),
          count: orders.length,
        );
    }
  }

  // ── Computed ───────────────────────────────────────────────────────
  bool get isInitialLoading => _status == BankTabStatus.fetching;
  bool get hasSummary => _summary != null;
  bool get hasBank => _bankData != null;
  bool get bankVerified => _bankData?.isVerified ?? false;
  bool get canRequestPayout =>
      hasBank &&
      bankVerified &&
      _summary != null &&
      _summary!.wallet.availableBalance > 0;

  // ── Time filter ────────────────────────────────────────────────────
  void setFilter(String filter, {DateTimeRange? customRange}) {
    _selectedFilter = filter;
    _customDateRange = filter == 'Custom' ? customRange : null;
    _notify();
  }

  /// Returns the date range implied by the current filter.
  DateTimeRange get activeDateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedFilter) {
      case 'Today':
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case 'This Week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(
          start: weekStart,
          end: today.add(const Duration(days: 1)),
        );
      case 'Custom':
        if (_customDateRange != null) return _customDateRange!;
        // Fallback to This Month
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: today.add(const Duration(days: 1)),
        );
      case 'This Month':
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: today.add(const Duration(days: 1)),
        );
    }
  }

  /// Recent orders filtered by the active date range.
  List<RecentOrderEarning> get filteredRecentOrders {
    final range = activeDateRange;
    return (_summary?.recentOrders ?? []).where((o) {
      if (o.createdAt.isEmpty) return false;
      try {
        final dt = DateTime.parse(o.createdAt).toLocal();
        return !dt.isBefore(range.start) && dt.isBefore(range.end);
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // ── Initial load — 5 parallel calls ─────────────────────────────────
  Future<void> loadAll() async {
    _status = BankTabStatus.fetching;
    _earningsError = null;
    _bankError = null;
    _payoutsError = null;
    _bankLoading = true;
    _payoutsLoading = true;
    _settlements = [];
    _currentPage = 1;
    _hasMore = true;
    _notify();

    final results = await Future.wait<dynamic>([
      _apiService
          .get(ApiEndpoints.vendorEarnings)
          .then<dynamic>((r) => r)
          .catchError((Object e) => e),
      _apiService
          .get(ApiEndpoints.vendorBank)
          .then<dynamic>((r) => r)
          .catchError((Object e) => e),
      _apiService
          .get(ApiEndpoints.vendorPayouts)
          .then<dynamic>((r) => r)
          .catchError((Object e) => e),
      _apiService
          .get(
            ApiEndpoints.settlementHistory,
            queryParameters: {'page': 1, 'per_page': _perPage},
          )
          .then<dynamic>((r) => r)
          .catchError((Object e) => e),
      // 5th call: computed vendor earnings from /vendors/earnings/
      _apiService
          .get(ApiEndpoints.earnings)
          .then<dynamic>((r) => r)
          .catchError((Object e) => e),
    ]);

    // ── Parse earnings ─────────────────────────────────────────────
    if (results[0] is Response) {
      try {
        final body = (results[0] as Response).data as Map<String, dynamic>;
        _summary = EarningsSummary.fromJson(body);
      } catch (e) {
        _earningsError = 'Could not parse earnings data.';
        debugPrint('[BankTab] earnings parse: $e');
      }
    } else {
      _earningsError = _errorFrom(results[0]);
    }

    // ── Parse bank ─────────────────────────────────────────────────
    if (results[1] is Response) {
      try {
        final body = (results[1] as Response).data as Map<String, dynamic>;
        final account = body['bank_account'];
        _bankData = account != null
            ? BankAccountData.fromJson(account as Map<String, dynamic>)
            : null;
      } catch (e) {
        _bankError = 'Could not parse bank data.';
        debugPrint('[BankTab] bank parse: $e');
      }
    } else {
      _bankError = _errorFrom(results[1]);
    }
    _bankLoading = false;

    // ── Parse payouts ──────────────────────────────────────────────
    if (results[2] is Response) {
      try {
        final body = (results[2] as Response).data;
        if (body is Map<String, dynamic>) {
          final rawList = (body['payouts'] as List<dynamic>?) ?? [];
          _payouts = rawList
              .map((e) => Payout.fromJson(e as Map<String, dynamic>))
              .toList();
          _totalPayouts = (body['total'] as num?)?.toInt() ?? _payouts.length;
        } else if (body is List) {
          _payouts = body
              .map((e) => Payout.fromJson(e as Map<String, dynamic>))
              .toList();
          _totalPayouts = _payouts.length;
        }
      } catch (e) {
        _payoutsError = 'Could not parse payouts data.';
        debugPrint('[BankTab] payouts parse: $e');
      }
    } else {
      _payoutsError = _errorFrom(results[2]);
    }
    _payoutsLoading = false;

    // ── Parse settlements ──────────────────────────────────────────
    if (results[3] is Response) {
      try {
        final body = (results[3] as Response).data as Map<String, dynamic>;
        _totalSettlements = (body['total'] as num?)?.toInt() ?? 0;
        final rawList = (body['settlements'] as List<dynamic>?) ?? [];
        _settlements = rawList
            .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
            .toList();
        _hasMore = _settlements.length < _totalSettlements;
      } catch (e) {
        debugPrint('[BankTab] settlements parse: $e');
      }
    }

    // ── Parse vendor computed earnings (/vendors/earnings/) ────────
    if (results[4] is Response) {
      try {
        final body = (results[4] as Response).data as Map<String, dynamic>;
        _vendorTotalEarnings = _dLocal(body['total_earnings']);
        _vendorTotalOrders = (body['total_orders'] as num?)?.toInt() ?? 0;
        _vendorAvgOrderValue = _dLocal(body['avg_order_value']);

        final periods = body['periods'] as Map<String, dynamic>?;
        if (periods != null) {
          _periodStats = {};
          periods.forEach((k, v) {
            final p = v as Map<String, dynamic>;
            _periodStats[k] = PeriodStats(
              total: _dLocal(p['total']),
              count: (p['count'] as num?)?.toInt() ?? 0,
            );
          });
        }

        _chartDayData = ((body['chart_data'] as List?) ?? []).map((e) {
          final m = e as Map<String, dynamic>;
          return ChartDayData(
            day: m['day']?.toString() ?? '',
            amount: _dLocal(m['amount']),
          );
        }).toList();

        debugPrint(
          '[BankTab] chartDayData parsed: ${_chartDayData.length} entries',
        );

        _vendorRecentTransactions =
            ((body['recent_transactions'] as List?) ?? [])
                .map(
                  (e) => VendorRecentTransaction.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList();

        debugPrint(
          '[BankTab] recentTransactions parsed: ${_vendorRecentTransactions.length} entries',
        );
      } catch (e) {
        debugPrint('[BankTab] vendor earnings parse ERROR: $e');
      }
    } else {
      debugPrint('[BankTab] /vendors/earnings/ call failed: ${results[4]}');
    }

    // Determine overall status
    final allFailed =
        _earningsError != null && _bankError != null && _payoutsError != null;
    _status = allFailed ? BankTabStatus.error : BankTabStatus.idle;
    _notify();
  }

  // ── Register / Update bank ──────────────────────────────────────────
  Future<bool> registerBankAccount({
    required String holderName,
    required String accountNumber,
    required String ifscCode,
    String accountType = 'current',
    String? upiId,
  }) async {
    _bankSaving = true;
    _bankSaveError = null;
    _notify();

    try {
      final payload = <String, dynamic>{
        'account_holder_name': holderName.trim(),
        'account_number': accountNumber.trim(),
        'ifsc_code': ifscCode.trim().toUpperCase(),
        'account_type': accountType,
        if (upiId != null && upiId.trim().isNotEmpty) 'upi_id': upiId.trim(),
      };

      await _apiService.post(ApiEndpoints.vendorBankRegister, data: payload);

      // Re-fetch bank data to get the full record from server.
      try {
        final resp = await _apiService.get(ApiEndpoints.vendorBank);
        final body = resp.data as Map<String, dynamic>;
        final account = body['bank_account'];
        _bankData = account != null
            ? BankAccountData.fromJson(account as Map<String, dynamic>)
            : null;
      } catch (_) {
        // Even if re-fetch fails, the save succeeded.
      }

      _bankSaving = false;
      _notify();
      return true;
    } on DioException catch (e) {
      _bankSaveError = _parseDioError(e);
      _bankSaving = false;
      _notify();
      return false;
    } catch (e) {
      _bankSaveError = 'An unexpected error occurred. Please try again.';
      _bankSaving = false;
      debugPrint('[BankTab] registerBank: $e');
      _notify();
      return false;
    }
  }

  // ── Request payout ──────────────────────────────────────────────────
  Future<bool> requestPayout(double amount) async {
    _payoutReqStatus = PayoutRequestStatus.requesting;
    _payoutReqError = null;
    _notify();

    try {
      await _apiService.post(
        ApiEndpoints.vendorPayoutRequest,
        data: {'amount': amount},
      );
      _payoutReqStatus = PayoutRequestStatus.success;
      _notify();

      // Refresh earnings (balance changed) and payouts list silently.
      await Future.wait([_refreshEarnings(), _refreshPayouts()]);
      return true;
    } on DioException catch (e) {
      _payoutReqError = _parseDioError(e);
      _payoutReqStatus = PayoutRequestStatus.error;
      _notify();
      return false;
    } catch (e) {
      _payoutReqError = 'Failed to request payout. Please try again.';
      _payoutReqStatus = PayoutRequestStatus.error;
      debugPrint('[BankTab] requestPayout: $e');
      _notify();
      return false;
    }
  }

  void clearPayoutReqStatus() {
    _payoutReqStatus = PayoutRequestStatus.idle;
    _payoutReqError = null;
    _notify();
  }

  // ── Load more settlements (pagination) ──────────────────────────────
  Future<void> loadMoreSettlements() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _notify();

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
    } catch (e) {
      _currentPage--;
      debugPrint('[BankTab] loadMoreSettlements: $e');
    }

    _isLoadingMore = false;
    _notify();
  }

  // ── Refresh ────────────────────────────────────────────────────────
  Future<void> refresh() => loadAll();

  // ── Private helpers ────────────────────────────────────────────────
  Future<void> _refreshEarnings() async {
    try {
      final resp = await _apiService.get(ApiEndpoints.vendorEarnings);
      final body = resp.data as Map<String, dynamic>;
      _summary = EarningsSummary.fromJson(body);
      _notify();
    } catch (_) {}
  }

  Future<void> _refreshPayouts() async {
    try {
      final resp = await _apiService.get(ApiEndpoints.vendorPayouts);
      final body = resp.data;
      if (body is Map<String, dynamic>) {
        final rawList = (body['payouts'] as List<dynamic>?) ?? [];
        _payouts = rawList
            .map((e) => Payout.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalPayouts = (body['total'] as num?)?.toInt() ?? _payouts.length;
      } else if (body is List) {
        _payouts = body
            .map((e) => Payout.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalPayouts = _payouts.length;
      }
      _notify();
    } catch (_) {}
  }

  String _errorFrom(dynamic result) {
    if (result is DioException) return _parseDioError(result);
    return 'Network error. Please try again.';
  }

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
