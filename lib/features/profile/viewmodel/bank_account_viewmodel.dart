import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../earnings/viewmodel/earnings_viewmodel.dart'
    show EarningsCommission, EarningsSettlement, EarningsWallet, Payout;

// ─────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────
class BankAccountData {
  final String holderName;

  /// Server already returns a masked string e.g. "XXXX1234"
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

  factory BankAccountData.fromJson(Map<String, dynamic> j) => BankAccountData(
    holderName: _s(j['account_holder_name']),
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
  EarningsWallet? _wallet;
  EarningsCommission? _commission;
  EarningsSettlement? _settlement;
  List<Payout> _payouts = [];
  String? _errorMessage;
  bool _isFetchError = false;

  // ── Getters ────────────────────────────────────────────────────────
  BankStatus get status => _status;
  BankAccountData? get bankData => _bankData;
  EarningsWallet? get wallet => _wallet;
  EarningsCommission? get commission => _commission;
  EarningsSettlement? get settlement => _settlement;
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

      // Earnings data (optional — don't block on failure)
      final eData = await earningsFuture;
      if (eData != null) {
        final w = eData['wallet'];
        if (w is Map<String, dynamic>) {
          _wallet = EarningsWallet.fromJson(w);
        }
        final c = eData['commission'];
        if (c is Map<String, dynamic>) {
          _commission = EarningsCommission.fromJson(c);
        }
        final s = eData['settlement'];
        if (s is Map<String, dynamic>) {
          _settlement = EarningsSettlement.fromJson(s);
        }
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
