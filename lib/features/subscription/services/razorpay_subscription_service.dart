import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/utils/app_logger.dart';
import '../models/subscription_models.dart';

typedef RazorpaySuccessCallback = void Function(PaymentSuccessResponse);
typedef RazorpayErrorCallback = void Function(PaymentFailureResponse);
typedef RazorpayWalletCallback = void Function(ExternalWalletResponse);

class RazorpaySubscriptionService {
  Razorpay? _razorpay;
  RazorpayOrderData? _currentOrder;

  RazorpaySuccessCallback? _onSuccess;
  RazorpayErrorCallback? _onError;
  RazorpayWalletCallback? _onWallet;

  bool get isInitialized => _razorpay != null;

  void initialize({
    required RazorpaySuccessCallback onSuccess,
    required RazorpayErrorCallback onError,
    required RazorpayWalletCallback onWallet,
  }) {
    // Prevent duplicate listeners by clearing first
    dispose();

    _onSuccess = onSuccess;
    _onError = onError;
    _onWallet = onWallet;

    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    AppLogger.i('RazorpaySubscriptionService initialized');
  }

  void openCheckout({
    required RazorpayOrderData orderData,
    required String vendorName,
    required String vendorEmail,
    required String vendorPhone,
    required String razorpayKey,
    Color? themeColor,
  }) {
    if (_razorpay == null) {
      AppLogger.e('Razorpay not initialized. Call initialize() first.');
      return;
    }

    _currentOrder = orderData;

    final options = <String, dynamic>{
      'key': razorpayKey,
      'amount': orderData.amountPaise,
      'currency': orderData.currency,
      'name': 'Zill',
      'description': 'Subscription: ${orderData.planName}',
      'order_id': orderData.orderId,
      'prefill': {
        'name': vendorName,
        'email': vendorEmail,
        'contact': vendorPhone,
      },
      'theme': {
        'color': '#${(themeColor ?? const Color(0xFFFF6B35)).toARGB32().toRadixString(16).substring(2)}',
      },
      'notes': {
        'invoice_id': orderData.invoiceId,
        'type': 'subscription_fee',
      },
      'retry': {
        'enabled': true,
        'max_count': 2,
      },
    };

    try {
      _razorpay!.open(options);
      AppLogger.i('Razorpay checkout opened for order: ${orderData.orderId}');
    } catch (e) {
      AppLogger.e('Failed to open Razorpay checkout', e);
    }
  }

  // ── Native event handlers ─────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    AppLogger.i(
      'Razorpay payment success: ${response.paymentId} '
      'order: ${response.orderId}',
    );
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    AppLogger.e(
      'Razorpay payment error: code=${response.code} '
      'msg=${response.message}',
    );
    _onError?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    AppLogger.i('Razorpay external wallet: ${response.walletName}');
    _onWallet?.call(response);
  }

  // ── Getters ───────────────────────────────────────────────────────────

  RazorpayOrderData? get currentOrder => _currentOrder;

  // ── Cleanup — MUST be called in widget dispose() ──────────────────────

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _currentOrder = null;
    _onSuccess = null;
    _onError = null;
    _onWallet = null;
    AppLogger.d('RazorpaySubscriptionService disposed');
  }
}
