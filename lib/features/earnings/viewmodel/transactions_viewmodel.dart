import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import 'earnings_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────
//  Transaction Type
// ─────────────────────────────────────────────────────────────────────

enum TransactionType { orderEarning, payout, settlement }

// ─────────────────────────────────────────────────────────────────────
//  Unified Transaction Model
// ─────────────────────────────────────────────────────────────────────

class UnifiedTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final double netAmount;
  final String status;
  final DateTime date;
  final String description;
  final String referenceId;

  /// Extra metadata depending on type.
  final Map<String, dynamic> meta;

  const UnifiedTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.netAmount,
    required this.status,
    required this.date,
    required this.description,
    required this.referenceId,
    this.meta = const {},
  });

  // ── Convenience getters ────────────────────────────────────────────

  bool get isCredit =>
      type == TransactionType.orderEarning ||
      type == TransactionType.settlement;

  bool get isDebit => type == TransactionType.payout;

  String get typeLabel {
    switch (type) {
      case TransactionType.orderEarning:
        return 'Order Earning';
      case TransactionType.payout:
        return 'Bank Payout';
      case TransactionType.settlement:
        return 'Settlement';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case TransactionType.orderEarning:
        return Icons.shopping_bag_rounded;
      case TransactionType.payout:
        return Icons.account_balance_rounded;
      case TransactionType.settlement:
        return Icons.receipt_long_rounded;
    }
  }

  String get normalizedStatus {
    final s = status.toLowerCase();
    if (['processed', 'completed', 'delivered', 'success'].contains(s)) {
      return 'success';
    }
    if (['failed', 'reversed', 'cancelled'].contains(s)) return 'failed';
    if (['queued', 'pending', 'processing', 'on_hold'].contains(s)) {
      return 'pending';
    }
    return s;
  }

  String get statusLabel {
    switch (normalizedStatus) {
      case 'success':
        return 'Success';
      case 'failed':
        return 'Failed';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  // ── Factories — from backend JSON ──────────────────────────────────

  /// Build from a payout record (from `/payments/vendor/payouts/`).
  factory UnifiedTransaction.fromPayout(Payout p) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(p.initiatedAt).toLocal();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return UnifiedTransaction(
      id: p.payoutId,
      type: TransactionType.payout,
      amount: p.amount,
      netAmount: p.netAmount,
      status: p.status,
      date: parsedDate,
      description: 'Bank Payout (${p.mode})',
      referenceId: p.payoutId,
      meta: {
        'fees': p.fees,
        'mode': p.mode,
        'utr': p.utr,
        'failure_reason': p.failureReason,
      },
    );
  }

  /// Build from a settlement record (from `/payments/settlements/history/`).
  factory UnifiedTransaction.fromSettlement(Settlement s) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(s.createdAt).toLocal();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return UnifiedTransaction(
      id: s.settlementId,
      type: TransactionType.settlement,
      amount: s.grossAmount,
      netAmount: s.netAmount,
      status: s.status,
      date: parsedDate,
      description: 'Settlement (${s.ordersCount} orders)',
      referenceId: s.settlementId,
      meta: {
        'period': s.period,
        'commission': s.commissionAmount,
        'tax': s.taxOnCommission,
        'deductions': s.deductions,
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Filter State
// ─────────────────────────────────────────────────────────────────────

class TransactionFilter {
  final Set<TransactionType> types;
  final Set<String> statuses; // 'success', 'pending', 'failed'
  final DateTimeRange? dateRange;

  const TransactionFilter({
    this.types = const {},
    this.statuses = const {},
    this.dateRange,
  });

  bool get isEmpty => types.isEmpty && statuses.isEmpty && dateRange == null;

  TransactionFilter copyWith({
    Set<TransactionType>? types,
    Set<String>? statuses,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return TransactionFilter(
      types: types ?? this.types,
      statuses: statuses ?? this.statuses,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (types.isNotEmpty) count++;
    if (statuses.isNotEmpty) count++;
    if (dateRange != null) count++;
    return count;
  }
}

// ─────────────────────────────────────────────────────────────────────
//  ViewModel Status
// ─────────────────────────────────────────────────────────────────────

enum TransactionsStatus { loading, idle, error }

// ─────────────────────────────────────────────────────────────────────
//  Transactions ViewModel
// ─────────────────────────────────────────────────────────────────────

class TransactionsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  TransactionsViewModel({required ApiService apiService})
    : _apiService = apiService;

  // ── State ──────────────────────────────────────────────────────────
  TransactionsStatus _status = TransactionsStatus.loading;
  List<UnifiedTransaction> _allTransactions = [];
  String? _errorMessage;
  TransactionFilter _filter = const TransactionFilter();

  // ── Getters ────────────────────────────────────────────────────────
  TransactionsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  TransactionFilter get filter => _filter;

  /// Filtered + sorted (newest first).
  List<UnifiedTransaction> get transactions {
    var list = List<UnifiedTransaction>.from(_allTransactions);

    // Apply type filter
    if (_filter.types.isNotEmpty) {
      list = list.where((t) => _filter.types.contains(t.type)).toList();
    }

    // Apply status filter
    if (_filter.statuses.isNotEmpty) {
      list = list
          .where((t) => _filter.statuses.contains(t.normalizedStatus))
          .toList();
    }

    // Apply date range filter
    if (_filter.dateRange != null) {
      final start = _filter.dateRange!.start;
      final end = _filter.dateRange!.end.add(
        const Duration(days: 1),
      ); // inclusive end
      list = list
          .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
          .toList();
    }

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  int get totalCount => _allTransactions.length;
  int get filteredCount => transactions.length;
  bool get hasActiveFilters => !_filter.isEmpty;

  // ── Load all data ──────────────────────────────────────────────────
  Future<void> loadAll() async {
    _status = TransactionsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _apiService.get(ApiEndpoints.vendorEarnings)
            .then<dynamic>((r) => r).catchError((Object e) => e),
        _apiService.get(ApiEndpoints.vendorPayouts)
            .then<dynamic>((r) => r).catchError((Object e) => e),
        _apiService
            .get(
              ApiEndpoints.settlementHistory,
              queryParameters: {'page': 1, 'per_page': 50},
            )
            .then<dynamic>((r) => r)
            .catchError((Object e) => e),
      ]);

      final List<UnifiedTransaction> combined = [];

      // ── Parse weekly settlements (payout_history in new earnings shape) ──
      if (results[0] is Response) {
        try {
          final body = (results[0] as Response).data as Map<String, dynamic>;
          final history = (body['payout_history'] as List<dynamic>?) ?? [];
          for (final h in history) {
            final m = h as Map<String, dynamic>;
            DateTime parsedDate;
            try {
              parsedDate = DateTime.parse(
                m['paid_on']?.toString() ??
                    m['period_end']?.toString() ??
                    DateTime.now().toIso8601String(),
              ).toLocal();
            } catch (_) {
              parsedDate = DateTime.now();
            }
            final amt = (m['amount'] is num)
                ? (m['amount'] as num).toDouble()
                : double.tryParse(m['amount']?.toString() ?? '') ?? 0.0;
            combined.add(UnifiedTransaction(
              id: m['settlement_id']?.toString() ?? '',
              type: TransactionType.settlement,
              amount: amt,
              netAmount: amt,
              status: m['status']?.toString() ?? 'pending',
              date: parsedDate,
              description: 'Weekly Payout (${m['period'] ?? ''})',
              referenceId: m['settlement_id']?.toString() ?? '',
              meta: {'utr': m['utr'] ?? ''},
            ));
          }
        } catch (e) {
          debugPrint('[TransactionsVM] parse payout_history: $e');
        }
      }

      // ── Parse payouts ────────────────────────────────────────────
      if (results[1] is Response) {
        try {
          final body = (results[1] as Response).data;
          List<dynamic> rawPayouts = [];
          if (body is Map<String, dynamic>) {
            rawPayouts = (body['payouts'] as List<dynamic>?) ?? [];
          } else if (body is List) {
            rawPayouts = body;
          }
          for (final p in rawPayouts) {
            combined.add(
              UnifiedTransaction.fromPayout(
                Payout.fromJson(p as Map<String, dynamic>),
              ),
            );
          }
        } catch (e) {
          debugPrint('[TransactionsVM] parse payouts: $e');
        }
      }

      // ── Parse settlements ────────────────────────────────────────
      if (results[2] is Response) {
        try {
          final body = (results[2] as Response).data as Map<String, dynamic>;
          final rawSettlements = (body['settlements'] as List<dynamic>?) ?? [];
          for (final s in rawSettlements) {
            combined.add(
              UnifiedTransaction.fromSettlement(
                Settlement.fromJson(s as Map<String, dynamic>),
              ),
            );
          }
        } catch (e) {
          debugPrint('[TransactionsVM] parse settlements: $e');
        }
      }

      // Sort newest first
      combined.sort((a, b) => b.date.compareTo(a.date));
      _allTransactions = combined;

      if (combined.isEmpty &&
          results[0] is! Response &&
          results[1] is! Response &&
          results[2] is! Response) {
        _errorMessage = _errorFrom(results[0]);
        _status = TransactionsStatus.error;
      } else {
        _status = TransactionsStatus.idle;
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = TransactionsStatus.error;
      debugPrint('[TransactionsVM] loadAll: $e');
    }
    notifyListeners();
  }

  // ── Filter ─────────────────────────────────────────────────────────
  void setFilter(TransactionFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  void clearFilters() {
    _filter = const TransactionFilter();
    notifyListeners();
  }

  // ── Refresh ────────────────────────────────────────────────────────
  Future<void> refresh() => loadAll();

  // ── Helpers ────────────────────────────────────────────────────────
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
