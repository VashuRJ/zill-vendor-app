// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/utils/app_logger.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  final PushNotificationService _pushService;
  final WebSocketService _wsService;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  String? _username;

  AuthViewModel({
    required ApiService apiService,
    required StorageService storageService,
    required PushNotificationService pushService,
    required WebSocketService wsService,
  }) : _apiService = apiService,
       _storageService = storageService,
       _pushService = pushService,
       _wsService = wsService;

  // Getters
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get username => _username;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // ----------------------------------------------------------------
  // Auto-login check (called from SplashScreen)
  // ----------------------------------------------------------------
  Future<void> checkAuthStatus() async {
    // Skip the intermediate loading notification — no widget on the splash
    // screen displays it, so it only triggers useless Consumer rebuilds
    // across the entire tree.

    try {
      final hasTokens = await _storageService.hasTokens();
      if (hasTokens) {
        _username = await _storageService.getUsername();
        _status = AuthStatus.authenticated;

        // Re-register FCM token on app relaunch (non-blocking)
        _pushService.initialize().catchError((e) {
          AppLogger.e('FCM init on auto-login failed: $e');
        });
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Logout
  // POST /api/users/logout/  Body: { "refresh": "..." }
  // ----------------------------------------------------------------
  Future<void> logout() async {
    try {
      // Unregister FCM token FIRST — while JWT is still valid
      await _pushService.unregister().catchError((_) {});

      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        await _apiService.post(
          ApiEndpoints.logout,
          data: {'refresh': refreshToken},
        );
      }
    } catch (_) {
      // Even if the API call fails, clear local storage
    } finally {
      // Disconnect all WebSocket connections immediately
      _wsService.disconnectAll();
      // Block any auto-refresh timer requests that fire during cleanup so they
      // don't trigger a spurious _clearAndLogout() while the user is on login.
      _apiService.signalLoggingOut();
      await _storageService.clearAll();
      _username = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      // _isLoggingOut stays true until next successful login calls resetLoggingOut()
      // This blocks ALL requests until user logs in again.
    }
  }

  // ----------------------------------------------------------------
  // WhatsApp OTP — Step 1: Send OTP to phone number
  // POST /api/users/vendor/auth/send-otp/
  // Payload: { "phone": "9876543210" }
  // ----------------------------------------------------------------
  bool _waOtpSendLoading = false;
  bool get isWaOtpSendLoading => _waOtpSendLoading;

  Future<({bool success, String message, int waitSeconds})> requestWhatsAppOtp({
    required String phone,
  }) async {
    _waOtpSendLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.vendorWaOtpSend,
        data: {'phone': phone.trim()},
      );

      AppLogger.i('WA OTP SEND — HTTP ${response.statusCode}');

      _waOtpSendLoading = false;
      notifyListeners();

      final body = response.data;
      String msg = 'OTP sent via WhatsApp.';
      if (body is Map<String, dynamic> && body.containsKey('message')) {
        msg = body['message'] as String;
      }
      return (success: true, message: msg, waitSeconds: 0);
    } on DioException catch (e) {
      AppLogger.e('WA OTP SEND FAILED — ${e.response?.statusCode}');

      _waOtpSendLoading = false;
      notifyListeners();

      int waitSeconds = 0;
      if (e.response?.statusCode == 429) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          waitSeconds = (data['wait_time'] as num?)?.toInt() ?? 60;
        }
      }
      return (success: false, message: _parseWaOtpError(e), waitSeconds: waitSeconds);
    } catch (e) {
      AppLogger.e('WA OTP SEND UNEXPECTED: $e');
      _waOtpSendLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.', waitSeconds: 0);
    }
  }

  // ----------------------------------------------------------------
  // WhatsApp OTP — Step 2: Verify OTP & authenticate (or register)
  // POST /api/users/vendor/auth/verify-otp/
  // Payload: { "phone": "...", "otp": "...", "name"?: "Restaurant Name" }
  // Response actions: "login" | "registered" | "register_required"
  // ----------------------------------------------------------------
  bool _waOtpVerifyLoading = false;
  bool get isWaOtpVerifyLoading => _waOtpVerifyLoading;

  Future<({bool success, String message, String action})> verifyWhatsAppOtp({
    required String phone,
    required String otp,
    String? restaurantName,
  }) async {
    _waOtpVerifyLoading = true;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'phone': phone.trim(),
        'otp': otp.trim(),
      };
      if (restaurantName != null && restaurantName.trim().isNotEmpty) {
        payload['name'] = restaurantName.trim();
      }

      final response = await _apiService.post(
        ApiEndpoints.vendorWaOtpVerify,
        data: payload,
      );

      AppLogger.i('WA OTP VERIFY — HTTP ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;
      final action = body['action'] as String? ?? 'login';

      _waOtpVerifyLoading = false;

      // New vendor needs to provide restaurant name — not a login yet
      if (action == 'register_required') {
        notifyListeners();
        return (success: true, message: body['message']?.toString() ?? '', action: action);
      }

      // Existing vendor login or new vendor just registered
      final tokens = body['tokens'] as Map<String, dynamic>;
      final user = body['user'] as Map<String, dynamic>;
      final displayName = (user['name'] as String?)?.trim() ?? '';

      await _storageService.saveTokens(
        accessToken: tokens['access'] as String,
        refreshToken: tokens['refresh'] as String,
      );
      await _storageService.saveUserInfo(
        userId: (user['id'] as num).toInt(),
        username: displayName.isNotEmpty ? displayName : phone.trim(),
        userType: user['user_type'] as String? ?? 'vendor',
      );

      _apiService.incrementLoginGeneration();
      _apiService.resetLoggingOut();

      _username = displayName.isNotEmpty ? displayName : phone.trim();
      _status = AuthStatus.authenticated;
      notifyListeners();

      _pushService.initialize().catchError((e) {
        AppLogger.e('FCM init after WA OTP login failed: $e');
      });

      return (success: true, message: 'Login successful.', action: action);
    } on DioException catch (e) {
      AppLogger.e('WA OTP VERIFY FAILED — ${e.response?.statusCode}');

      _waOtpVerifyLoading = false;
      notifyListeners();

      return (success: false, message: _parseWaOtpError(e), action: '');
    } catch (e) {
      AppLogger.e('WA OTP VERIFY UNEXPECTED: $e');
      _waOtpVerifyLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.', action: '');
    }
  }

  String _parseWaOtpError(DioException e) {
    if (e.response == null) return 'Network error. Please check your connection.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      final msg = _parseErrorBody(data);
      if (msg != null) return msg;
    }
    switch (e.response!.statusCode) {
      case 400:
        return 'Invalid OTP or phone number.';
      case 404:
        return 'No account found with this number.';
      case 429:
        return 'Too many attempts. Please wait a few minutes.';
      case 503:
        return 'WhatsApp service unavailable. Please try again.';
      default:
        return 'OTP verification failed. Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // Clear error message
  // ----------------------------------------------------------------
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------
  // Shared body parser — extracts the first human-readable message from
  // any Django REST Framework error response shape:
  //   { "message": "..." }
  //   { "error": { "details": {...}, "message": "..." } }
  //   { "errors": { "error": "...", "non_field_errors": [...] } }
  //   { "non_field_errors": ["..."] }
  //   { "otp"/"phone": ["..."] }
  //   { "detail": "..." }
  // Returns null if nothing recognised — caller falls back to status code.
  // ----------------------------------------------------------------
  static String? _parseErrorBody(Map<String, dynamic> data) {
    // { "message": "..." }
    if (data.containsKey('message') && data['message'] is String) {
      return data['message'] as String;
    }

    // { "error": { "details": {...}, "message": "...", ... } }
    if (data.containsKey('error')) {
      final err = data['error'];
      if (err is Map<String, dynamic>) {
        // Check details first — contains the specific field-level error
        if (err.containsKey('details')) {
          final details = err['details'];
          if (details is Map<String, dynamic>) {
            final extracted = _extractFirstString(details);
            if (extracted != null) return extracted;
          }
        }
        if (err.containsKey('message')) return err['message'].toString();
        final extracted = _extractFirstString(err);
        if (extracted != null) return extracted;
      }
      if (err is String) return err;
    }

    // { "errors": { "error": "...", "non_field_errors": [...] } }
    if (data.containsKey('errors')) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        if (errors.containsKey('error')) return errors['error'].toString();
        if (errors.containsKey('non_field_errors')) {
          final nfe = errors['non_field_errors'];
          return (nfe is List && nfe.isNotEmpty) ? nfe.first.toString() : nfe.toString();
        }
        final firstVal = errors.values.first;
        return (firstVal is List && firstVal.isNotEmpty)
            ? firstVal.first.toString()
            : firstVal.toString();
      }
    }

    // { "non_field_errors": ["..."] }
    if (data.containsKey('non_field_errors')) {
      final nfe = data['non_field_errors'];
      return (nfe is List && nfe.isNotEmpty) ? nfe.first.toString() : nfe.toString();
    }

    // Field-level list errors — otp, phone
    for (final key in ['otp', 'phone']) {
      if (data.containsKey(key)) {
        final val = data[key];
        if (val is List && val.isNotEmpty) return val.first.toString();
      }
    }

    // { "detail": "..." }
    if (data.containsKey('detail')) return data['detail'].toString();

    return null;
  }

  /// Recursively extracts the first human-readable string from a
  /// Django REST Framework error map.
  ///   { "error": ["Invalid OTP"] }  →  "Invalid OTP"
  ///   { "details": { "error": ["..."] } }  →  "..."
  static String? _extractFirstString(Map<String, dynamic> map) {
    for (final value in map.values) {
      if (value is String && value.isNotEmpty) return value;
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.isNotEmpty) return first;
      }
      if (value is Map<String, dynamic>) {
        final nested = _extractFirstString(value);
        if (nested != null) return nested;
      }
    }
    return null;
  }
}
