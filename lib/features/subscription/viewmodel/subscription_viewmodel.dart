import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/subscription_models.dart';

enum SubscriptionStatus {
  initial,
  loading,
  subscribing,
  verifying,
  loaded,
  error,
}

class SubscriptionViewModel extends ChangeNotifier {
  final ApiService _apiService;
  StreamSubscription<void>? _sessionClearedSub;

  SubscriptionViewModel({required ApiService apiService})
      : _apiService = apiService {
    _sessionClearedSub =
        ApiService.onSessionExpired.listen((_) => clearSession());
  }

  @override
  void dispose() {
    _sessionClearedSub?.cancel();
    super.dispose();
  }

  /// Flush the previous vendor's subscription + invoices so the next
  /// vendor's plan screen doesn't briefly flash another restaurant's
  /// "Current Plan" badge before the fresh /subscription/my/ fetch.
  void clearSession() {
    _status = SubscriptionStatus.initial;
    _errorMessage = null;
    _plans = [];
    _mySubscription = null;
    _invoices = [];
    _showAnnual = false;
    _subscribingPlanPk = null;
    _pendingInvoiceId = null;
    _pendingPaymentId = null;
    _pendingSignature = null;
    notifyListeners();
  }

  // ── State ─────────────────────────────────────────────────────────────
  SubscriptionStatus _status = SubscriptionStatus.initial;
  String? _errorMessage;
  List<SubscriptionPlan> _plans = [];
  VendorSubscription? _mySubscription;
  List<SubscriptionInvoice> _invoices = [];
  double _gstRate = 18.0;

  // Billing toggle state for UI
  bool _showAnnual = false;

  // Which plan PK is currently subscribing. Only ONE plan can be in-flight
  // at a time, but tracking the PK lets the UI spin ONLY the tapped card's
  // button (previously `isSubscribing` was a single boolean, so all plan
  // cards rendered a spinner when any one was submitted — confusing UX).
  int? _subscribingPlanPk;

  // Pending verification data — survives network drops so user can retry
  String? _pendingInvoiceId;
  String? _pendingPaymentId;
  String? _pendingSignature;

  // ── Getters ───────────────────────────────────────────────────────────
  SubscriptionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<SubscriptionPlan> get plans => _plans;
  VendorSubscription? get mySubscription => _mySubscription;
  List<SubscriptionInvoice> get invoices => _invoices;
  double get gstRate => _gstRate;
  bool get showAnnual => _showAnnual;
  bool get isLoading => _status == SubscriptionStatus.loading;
  bool get isSubscribing => _status == SubscriptionStatus.subscribing;
  bool get isVerifying => _status == SubscriptionStatus.verifying;
  bool get hasSubscription => _mySubscription != null;
  bool get hasPendingVerification => _pendingPaymentId != null;

  /// True only for the specific plan the user tapped. Use this (not
  /// [isSubscribing]) in plan-card buttons so only the tapped card spins.
  bool isSubscribingPlan(int planPk) => _subscribingPlanPk == planPk;

  // ── Reset status (e.g. after Razorpay back-button / error) ───────────
  void resetStatus() {
    _status = SubscriptionStatus.loaded;
    _subscribingPlanPk = null;
    notifyListeners();
  }

  // ── Toggle billing cycle (UI only) ───────────────────────────────────
  void toggleBillingCycle() {
    _showAnnual = !_showAnnual;
    notifyListeners();
  }

  // ── Fetch available plans ─────────────────────────────────────────────
  Future<void> fetchPlans() async {
    _status = SubscriptionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.subscriptionPlans);
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      final rawPlans = data['plans'] as List<dynamic>? ?? [];
      _plans = rawPlans
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .toList();

      _gstRate = _toDouble(data['gst_rate']) > 0
          ? _toDouble(data['gst_rate'])
          : 18.0;

      // Also capture current subscription if returned alongside plans
      if (data['current_subscription'] is Map<String, dynamic>) {
        _mySubscription = VendorSubscription.fromJson(
          data['current_subscription'] as Map<String, dynamic>,
        );
      }

      _status = SubscriptionStatus.loaded;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = SubscriptionStatus.error;
      AppLogger.e('fetchPlans failed', e);
    } catch (e) {
      _errorMessage = 'Failed to load plans';
      _status = SubscriptionStatus.error;
      AppLogger.e('fetchPlans unexpected', e);
    }
    notifyListeners();
  }

  /// True when the backend reports at least one active subscription
  /// plan. Drives the "paused" UI on My Subscription so vendors with
  /// active subs aren't shown live pricing / billing dates while
  /// admin has globally disabled plans (price reset, GST reconfig,
  /// re-launch). Defaults to `true` so the UI stays normal until the
  /// first fetch resolves; flips to `false` only when the backend
  /// explicitly says so.
  bool _subscriptionsEnabled = true;
  bool get subscriptionsEnabled => _subscriptionsEnabled;

  // ── Fetch my current subscription + invoices ──────────────────────────
  Future<void> fetchMySubscription() async {
    _status = SubscriptionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.mySubscription);
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      // Read the global pause flag. Backend computes this as
      // `SubscriptionPlan.objects.filter(is_active=True).exists()`,
      // and the renewal cron honours the same flag — so when it's
      // false here we know no charge is going to fire either.
      _subscriptionsEnabled = data['subscriptions_enabled'] as bool? ?? true;

      if (data['subscription'] is Map<String, dynamic>) {
        _mySubscription = VendorSubscription.fromJson(
          data['subscription'] as Map<String, dynamic>,
        );
      } else {
        _mySubscription = null;
      }

      final rawInvoices = data['invoices'] as List<dynamic>? ?? [];
      _invoices = rawInvoices
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionInvoice.fromJson)
          .toList();

      _status = SubscriptionStatus.loaded;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = SubscriptionStatus.error;
      AppLogger.e('fetchMySubscription failed', e);
    } catch (e) {
      _errorMessage = 'Failed to load subscription';
      _status = SubscriptionStatus.error;
      AppLogger.e('fetchMySubscription unexpected', e);
    }
    notifyListeners();
  }

  // ── Subscribe to a plan → returns Razorpay order data ─────────────────
  // Backend expects integer PK `plan_id`, not the string plan_id field.
  Future<RazorpayOrderData?> initiateSubscribe(int planPk) async {
    // Double-tap guard — reject if already in-flight
    if (_status == SubscriptionStatus.subscribing ||
        _status == SubscriptionStatus.verifying) {
      return null;
    }
    _status = SubscriptionStatus.subscribing;
    _subscribingPlanPk = planPk;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.subscribe,
        data: {
          'plan_id': planPk,
          'billing_cycle': _showAnnual ? 'annual' : 'monthly',
        },
      );
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      // If trial was started (no payment needed)
      // Backend returns: {trial: true, subscription_id, status: "trial", ...}
      if (data['trial'] == true) {
        _status = SubscriptionStatus.loaded;
        _subscribingPlanPk = null;
        notifyListeners();
        // Refresh subscription from /my/ to get full object
        fetchMySubscription();
        return null;
      }

      // Payment required — backend returns flat Razorpay order fields
      final orderData = RazorpayOrderData.fromJson(data);
      _status = SubscriptionStatus.loaded;
      _subscribingPlanPk = null;
      notifyListeners();
      return orderData;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = SubscriptionStatus.error;
      _subscribingPlanPk = null;
      notifyListeners();
      AppLogger.e('initiateSubscribe failed', e);
      return null;
    } catch (e) {
      _errorMessage = 'Failed to start subscription';
      _status = SubscriptionStatus.error;
      _subscribingPlanPk = null;
      notifyListeners();
      AppLogger.e('initiateSubscribe unexpected', e);
      return null;
    }
  }

  // ── Verify Razorpay payment with backend ──────────────────────────────
  Future<bool> verifyPayment({
    required String invoiceId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    // Store credentials so they survive network drops for retry
    _pendingInvoiceId = invoiceId;
    _pendingPaymentId = razorpayPaymentId;
    _pendingSignature = razorpaySignature;

    _status = SubscriptionStatus.verifying;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        ApiEndpoints.verifySubscriptionPayment,
        data: {
          'invoice_id': invoiceId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        },
      );
      // Backend returns flat {subscription_status, plan_name} — not full object.
      // Refresh full subscription from /my/ endpoint.
      _clearPendingVerification();
      _status = SubscriptionStatus.loaded;
      notifyListeners();
      fetchMySubscription();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = SubscriptionStatus.error;
      notifyListeners();
      AppLogger.e('verifyPayment failed', e);
      return false;
    } catch (e) {
      _errorMessage = 'Payment verification failed';
      _status = SubscriptionStatus.error;
      notifyListeners();
      AppLogger.e('verifyPayment unexpected', e);
      return false;
    }
  }

  // ── Retry a failed verification (network-drop recovery) ─────────────
  Future<bool> retryVerification() async {
    if (_pendingPaymentId == null ||
        _pendingInvoiceId == null ||
        _pendingSignature == null) {
      return false;
    }
    return verifyPayment(
      invoiceId: _pendingInvoiceId!,
      razorpayPaymentId: _pendingPaymentId!,
      razorpaySignature: _pendingSignature!,
    );
  }

  void _clearPendingVerification() {
    _pendingInvoiceId = null;
    _pendingPaymentId = null;
    _pendingSignature = null;
  }

  // ── Cancel subscription ───────────────────────────────────────────────
  Future<bool> cancelSubscription({
    String reason = '',
    bool atPeriodEnd = true,
  }) async {
    _status = SubscriptionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post(
        ApiEndpoints.cancelSubscription,
        data: {
          'reason': reason,
          'at_period_end': atPeriodEnd,
        },
      );
      // Backend returns flat {status, cancel_at_period_end, end_date}.
      // Refresh full subscription from /my/ endpoint.
      _status = SubscriptionStatus.loaded;
      notifyListeners();
      fetchMySubscription();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = SubscriptionStatus.error;
      notifyListeners();
      AppLogger.e('cancelSubscription failed', e);
      return false;
    } catch (e) {
      _errorMessage = 'Failed to cancel subscription';
      _status = SubscriptionStatus.error;
      notifyListeners();
      AppLogger.e('cancelSubscription unexpected', e);
      return false;
    }
  }

  // ── Retry / pay advance (for failed or upcoming invoices) ─────────────
  // Backend finds the pending invoice from auth context — empty POST body.
  Future<RazorpayOrderData?> retryPayment() async {
    // Double-tap guard — reject if already in-flight
    if (_status == SubscriptionStatus.subscribing ||
        _status == SubscriptionStatus.verifying) {
      return null;
    }
    _status = SubscriptionStatus.subscribing;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiEndpoints.payAdvance);
      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? body;

      final orderData = RazorpayOrderData.fromJson(data);
      _status = SubscriptionStatus.loaded;
      notifyListeners();
      return orderData;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = SubscriptionStatus.error;
      notifyListeners();
      AppLogger.e('retryPayment failed', e);
      return null;
    } catch (e) {
      _errorMessage = 'Failed to initiate payment';
      _status = SubscriptionStatus.error;
      notifyListeners();
      AppLogger.e('retryPayment unexpected', e);
      return null;
    }
  }

  // ── Error parser (matches AuthViewModel pattern) ──────────────────────
  static String _parseDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('message') && data['message'] is String) {
        return data['message'] as String;
      }
      if (data.containsKey('error') && data['error'] is String) {
        return data['error'] as String;
      }
      if (data.containsKey('detail') && data['detail'] is String) {
        return data['detail'] as String;
      }
    }
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please login again.';
    }
    if (e.response?.statusCode == 403) {
      return 'You do not have permission for this action';
    }
    return 'Something went wrong. Please try again.';
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
