import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../earnings/viewmodel/earnings_viewmodel.dart'
    show
        EarningsSummary,
        LifetimeEarnings,
        Payout,
        PayoutInfo,
        ThisWeekEarnings;

// ─────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────
class BankAccountData {
  final String holderName;

  /// Full account number (preferred). Backend now returns this as
  /// `account_number` so vendors can see their own saved number on
  /// their own dashboard without re-entering it just to verify.
  /// Empty when the backend doesn't include it (older deployments).
  final String accountNumber;

  /// Masked variant e.g. "XXXX1234" — kept as a fallback for older
  /// backends and as a privacy-friendly display option.
  final String maskedNumber;

  final String ifscCode;
  final String bankName;
  final String branchName;

  /// "savings" | "current"
  final String accountType;
  final String upiId;
  final bool isVerified;

  /// "pending" | "verified" | "failed"
  final String verificationStatus;
  final bool isActive;

  const BankAccountData({
    required this.holderName,
    required this.accountNumber,
    required this.maskedNumber,
    required this.ifscCode,
    required this.bankName,
    required this.branchName,
    required this.accountType,
    required this.upiId,
    required this.isVerified,
    required this.verificationStatus,
    required this.isActive,
  });

  /// Display-friendly account number — full when the backend sent
  /// it, falls back to the masked variant for older deployments.
  String get displayNumber =>
      accountNumber.isNotEmpty ? accountNumber : maskedNumber;

  factory BankAccountData.fromJson(Map<String, dynamic> j) => BankAccountData(
    holderName: _s(j['account_holder_name']),
    accountNumber: _s(j['account_number']),
    maskedNumber: _s(j['account_number_masked']),
    ifscCode: _s(j['ifsc_code']),
    bankName: _s(j['bank_name']),
    branchName: _s(j['branch_name']),
    accountType: _s(j['account_type']),
    upiId: _s(j['upi_id']),
    isVerified: j['is_verified'] as bool? ?? false,
    verificationStatus: _s(j['verification_status']),
    isActive: j['is_active'] as bool? ?? false,
  );

  static String _s(dynamic v) => v?.toString() ?? '';
}

// ─────────────────────────────────────────────────────────────────────
//  Status enum
// ─────────────────────────────────────────────────────────────────────
enum BankStatus {
  fetching, // GET in flight
  idle, // data ready — bankData may be null (no bank yet)
  saving, // POST in flight
  saved, // POST confirmed (transient, resets to idle)
  error, // any failure (see isFetchError for blocking vs. snackbar)
}

// ─────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────
class BankAccountViewModel extends ChangeNotifier {
  final ApiService _apiService;

  BankAccountViewModel({required ApiService apiService})
    : _apiService = apiService;

  // ── State ──────────────────────────────────────────────────────────
  BankStatus _status = BankStatus.fetching;
  BankAccountData? _bankData;
  PayoutInfo? _payoutInfo;
  ThisWeekEarnings? _thisWeek;
  LifetimeEarnings? _lifetime;
  List<Payout> _payouts = [];
  String? _errorMessage;
  bool _isFetchError = false;

  // ── Getters ────────────────────────────────────────────────────────
  BankStatus get status => _status;
  BankAccountData? get bankData => _bankData;
  PayoutInfo? get payoutInfo => _payoutInfo;
  ThisWeekEarnings? get thisWeek => _thisWeek;
  LifetimeEarnings? get lifetime => _lifetime;
  List<Payout> get payouts => _payouts;
  String? get errorMessage => _errorMessage;

  /// True when the failure is a blocking fetch error (full-screen).
  /// False when it is a save error (show as snackbar).
  bool get isFetchError => _isFetchError;

  bool get hasBank => _bankData != null;
  bool get isBusy =>
      _status == BankStatus.fetching || _status == BankStatus.saving;

  // ── Fetch ──────────────────────────────────────────────────────────
  Future<void> fetchBankAccount() async {
    _status = BankStatus.fetching;
    _isFetchError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch bank (required) + earnings + payouts (optional) in parallel
      final bankFuture = _apiService.get(ApiEndpoints.vendorBank);
      final earningsFuture = _apiService
          .get(ApiEndpoints.vendorEarnings)
          .then<Map<String, dynamic>?>(
            (r) => r.data as Map<String, dynamic>?,
          )
          .catchError((_) => null);
      final payoutsFuture = _apiService
          .get(ApiEndpoints.vendorPayouts)
          .then<Map<String, dynamic>?>(
            (r) => r.data as Map<String, dynamic>?,
          )
          .catchError((_) => null);

      final bankResp = await bankFuture;
      final body = bankResp.data as Map<String, dynamic>;
      final account = body['bank_account'];
      _bankData = account != null
          ? BankAccountData.fromJson(account as Map<String, dynamic>)
          : null;

      // Earnings data (optional — don't block on failure).
      // New shape: this_week + payout_info + lifetime + payout_history.
      final eData = await earningsFuture;
      if (eData != null) {
        final summary = EarningsSummary.fromJson(eData);
        _thisWeek = summary.thisWeek;
        _payoutInfo = summary.payoutInfo;
        _lifetime = summary.lifetime;
      }

      // Payouts data (optional — don't block on failure)
      final pData = await payoutsFuture;
      if (pData != null) {
        final rawList = (pData['payouts'] as List<dynamic>?) ?? [];
        _payouts = rawList
            .map((e) => Payout.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      _status = BankStatus.idle;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = BankStatus.error;
      _isFetchError = true;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = BankStatus.error;
      _isFetchError = true;
      debugPrint('[BankAccountViewModel] fetchBankAccount: $e');
    }
    notifyListeners();
  }

  // ── Register / Update ──────────────────────────────────────────────
  Future<void> registerBankAccount({
    required String holderName,
    required String accountNumber,
    required String ifscCode,
    String accountType = 'current',
    String? upiId,
  }) async {
    _status = BankStatus.saving;
    _isFetchError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'account_holder_name': holderName.trim(),
        'account_number': accountNumber.trim(),
        'ifsc_code': ifscCode.trim().toUpperCase(),
        'account_type': accountType,
        if (upiId != null && upiId.trim().isNotEmpty) 'upi_id': upiId.trim(),
      };

      await _apiService.post(ApiEndpoints.vendorBankRegister, data: payload);

      // Re-fetch to get the full bank record (server returns only partial).
      await fetchBankAccount(); // sets status = idle on success
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = BankStatus.error;
      _isFetchError = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _status = BankStatus.error;
      _isFetchError = false;
      debugPrint('[BankAccountViewModel] registerBankAccount: $e');
      notifyListeners();
    }
  }

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
