import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_logger.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  final PushNotificationService _pushService;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  String? _username;

  AuthViewModel({
    required ApiService apiService,
    required StorageService storageService,
    required PushNotificationService pushService,
  }) : _apiService = apiService,
       _storageService = storageService,
       _pushService = pushService;

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
  // Login
  // POST /api/users/login/vendor/
  // Payload: { "login": "<username|email|phone>", "password": "..." }
  // Headers: Content-Type: application/json (set globally in ApiService)
  // ----------------------------------------------------------------
  Future<bool> login({
    required String loginId,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final fullUrl = '${ApiEndpoints.baseUrl}${ApiEndpoints.login}';
    final payload = {'login': loginId.trim(), 'password': password};

    AppLogger.i('LOGIN REQUEST → $fullUrl');

    try {
      final response = await _apiService.post(
        ApiEndpoints.login,
        data: payload,
      );

      AppLogger.i('LOGIN SUCCESS — HTTP ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;
      // Vendor login wraps response under "data" key via APIResponse.success()
      final data = body['data'] as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      await _storageService.saveTokens(
        accessToken: tokens['access'] as String,
        refreshToken: tokens['refresh'] as String,
      );
      await _storageService.saveUserInfo(
        userId: (user['id'] as num).toInt(),
        username: user['username'] as String,
        userType: user['user_type'] as String,
      );

      // Invalidate any in-flight 401 handlers from a previous session so they
      // don't consume the new refresh token or navigate back to login.
      _apiService.incrementLoginGeneration();

      _username = user['username'] as String;
      _status = AuthStatus.authenticated;
      notifyListeners();

      // Register FCM token with backend (non-blocking)
      _pushService.initialize().catchError((e) {
        AppLogger.e('FCM init after login failed: $e');
      });

      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      AppLogger.e('LOGIN FAILED — HTTP $statusCode');

      if (statusCode == 404) {
        AppLogger.e(
          '404 — Wrong URL! Check ApiEndpoints.login path. Hit: $fullUrl',
        );
      } else if (statusCode == 400) {
        AppLogger.w('400 — Bad request. Server message: ${e.response?.data}');
      }

      _errorMessage = _parseDioError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e, st) {
      AppLogger.e('LOGIN UNEXPECTED ERROR', e, st);
      _errorMessage = 'Unexpected error. Please try again.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
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
      // Block any auto-refresh timer requests that fire during cleanup so they
      // don't trigger a spurious _clearAndLogout() while the user is on login.
      _apiService.signalLoggingOut();
      await _storageService.clearAll();
      _username = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      // Reset after a short delay — tokens are already cleared so Fix 1
      // (reject when no token) handles any timer requests that fire after this.
      Future.delayed(const Duration(seconds: 2), _apiService.resetLoggingOut);
    }
  }

  // ----------------------------------------------------------------
  // Password Reset Request
  // POST /api/users/password-reset/request/
  // Payload: { "email": "..." }
  // ----------------------------------------------------------------
  bool _resetLoading = false;
  bool get isResetLoading => _resetLoading;

  Future<({bool success, String message})> requestPasswordReset({
    required String email,
  }) async {
    _resetLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.passwordResetRequest,
        data: {'email': email.trim()},
      );

      AppLogger.i('PASSWORD RESET REQUEST — HTTP ${response.statusCode}');

      _resetLoading = false;
      notifyListeners();

      // Extract success message from response if available
      final body = response.data;
      String msg = 'Password reset link sent to your email.';
      if (body is Map<String, dynamic> && body.containsKey('message')) {
        msg = body['message'] as String;
      }
      return (success: true, message: msg);
    } on DioException catch (e) {
      AppLogger.e('PASSWORD RESET FAILED — ${e.response?.statusCode}');

      _resetLoading = false;
      notifyListeners();

      return (success: false, message: _parseResetError(e));
    } catch (e) {
      AppLogger.e('PASSWORD RESET UNEXPECTED: $e');
      _resetLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.');
    }
  }

  // ----------------------------------------------------------------
  // Password Reset — Step 2: Confirm with OTP + new password
  // POST /api/users/password-reset/confirm/
  // Payload: { "email": "...", "otp": "...", "new_password": "...", "confirm_password": "..." }
  // ----------------------------------------------------------------
  Future<({bool success, String message})> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _resetLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.passwordResetConfirm,
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );

      AppLogger.i('PASSWORD RESET CONFIRM — HTTP ${response.statusCode}');

      _resetLoading = false;
      notifyListeners();

      final body = response.data;
      String msg = 'Password reset successful.';
      if (body is Map<String, dynamic> && body.containsKey('message')) {
        msg = body['message'] as String;
      }
      return (success: true, message: msg);
    } on DioException catch (e) {
      AppLogger.e('PASSWORD RESET CONFIRM FAILED — ${e.response?.statusCode}');

      _resetLoading = false;
      notifyListeners();

      return (success: false, message: _parseResetError(e));
    } catch (e) {
      AppLogger.e('PASSWORD RESET CONFIRM UNEXPECTED: $e');
      _resetLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.');
    }
  }

  // ----------------------------------------------------------------
  // Password Reset — Step 2: Verify OTP (before setting new password)
  // POST /api/users/otp/verify/
  // Payload: { "email": "...", "otp": "...", "purpose": "password_reset" }
  // ----------------------------------------------------------------
  bool _otpResetVerifyLoading = false;
  bool get isOtpResetVerifyLoading => _otpResetVerifyLoading;

  Future<({bool success, String message})> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    _otpResetVerifyLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.otpVerify,
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'purpose': 'password_reset',
        },
      );

      AppLogger.i('OTP VERIFY (reset) — HTTP ${response.statusCode}');

      _otpResetVerifyLoading = false;
      notifyListeners();

      return (success: true, message: 'OTP verified.');
    } on DioException catch (e) {
      AppLogger.e('OTP VERIFY (reset) FAILED — ${e.response?.statusCode}');
      _otpResetVerifyLoading = false;
      notifyListeners();
      return (success: false, message: _parseResetError(e));
    } catch (e) {
      AppLogger.e('OTP VERIFY (reset) UNEXPECTED: $e');
      _otpResetVerifyLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.');
    }
  }

  String _parseResetError(DioException e) {
    if (e.response == null) return 'Network error. Please check your connection.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      final msg = _parseErrorBody(data);
      if (msg != null) return msg;
    }
    switch (e.response!.statusCode) {
      case 404:
        return 'No account found with this email address.';
      case 429:
        return 'Too many requests. Please wait a few minutes.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Could not send reset link. Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // OTP Login — Step 1: Request OTP
  // POST /api/users/otp/send/   Payload: { "email": "...", "purpose": "login" }
  // ----------------------------------------------------------------
  bool _otpSendLoading = false;
  bool get isOtpSendLoading => _otpSendLoading;

  Future<({bool success, String message, int waitSeconds})> requestOtp({
    required String email,
  }) async {
    _otpSendLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.otpSend,
        data: {'email': email.trim(), 'purpose': 'login'},
      );

      AppLogger.i('OTP SEND — HTTP ${response.statusCode}');

      _otpSendLoading = false;
      notifyListeners();

      final body = response.data;
      String msg = 'OTP sent successfully.';
      if (body is Map<String, dynamic> && body.containsKey('message')) {
        msg = body['message'] as String;
      }
      return (success: true, message: msg, waitSeconds: 0);
    } on DioException catch (e) {
      AppLogger.e('OTP SEND FAILED — ${e.response?.statusCode}');

      _otpSendLoading = false;
      notifyListeners();

      // Extract server-side wait_time for 429 so the UI can show a countdown.
      int waitSeconds = 0;
      if (e.response?.statusCode == 429) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          waitSeconds = (data['wait_time'] as num?)?.toInt() ?? 0;
        }
      }
      return (success: false, message: _parseOtpError(e), waitSeconds: waitSeconds);
    } catch (e) {
      AppLogger.e('OTP SEND UNEXPECTED: $e');
      _otpSendLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.', waitSeconds: 0);
    }
  }

  // ----------------------------------------------------------------
  // OTP Login — Step 2: Verify OTP & authenticate
  // POST /api/users/otp/login/   Payload: { "email": "...", "otp": "..." }
  // Response: { tokens: { access, refresh }, user: { id, username, user_type } }
  // ----------------------------------------------------------------
  bool _otpVerifyLoading = false;
  bool get isOtpVerifyLoading => _otpVerifyLoading;

  Future<({bool success, String message})> verifyOtpAndLogin({
    required String email,
    required String otp,
  }) async {
    _otpVerifyLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiEndpoints.otpLogin,
        data: {'email': email.trim(), 'otp': otp.trim()},
      );

      AppLogger.i('OTP LOGIN SUCCESS — HTTP ${response.statusCode}');

      final body = response.data as Map<String, dynamic>;
      final tokens = body['tokens'] as Map<String, dynamic>;
      final user = body['user'] as Map<String, dynamic>;

      await _storageService.saveTokens(
        accessToken: tokens['access'] as String,
        refreshToken: tokens['refresh'] as String,
      );
      await _storageService.saveUserInfo(
        userId: (user['id'] as num).toInt(),
        username: user['username'] as String,
        userType: user['user_type'] as String,
      );

      // Invalidate any in-flight 401 handlers from a previous session so they
      // don't consume the new refresh token or navigate back to login.
      _apiService.incrementLoginGeneration();

      _username = user['username'] as String;
      _status = AuthStatus.authenticated;
      _otpVerifyLoading = false;
      notifyListeners();

      // Register FCM token with backend (non-blocking)
      _pushService.initialize().catchError((e) {
        AppLogger.e('FCM init after OTP login failed: $e');
      });

      return (success: true, message: 'Login successful.');
    } on DioException catch (e) {
      AppLogger.e('OTP LOGIN FAILED — ${e.response?.statusCode}');

      _otpVerifyLoading = false;
      notifyListeners();

      return (success: false, message: _parseOtpError(e));
    } catch (e) {
      AppLogger.e('OTP LOGIN UNEXPECTED: $e');
      _otpVerifyLoading = false;
      notifyListeners();
      return (success: false, message: 'Unexpected error. Please try again.');
    }
  }

  String _parseOtpError(DioException e) {
    if (e.response == null) return 'Network error. Please check your connection.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      final msg = _parseErrorBody(data);
      if (msg != null) return msg;
    }
    switch (e.response!.statusCode) {
      case 400:
        return 'Invalid OTP or email address.';
      case 404:
        return 'No vendor account found with this email address.';
      case 429:
        return 'Too many attempts. Please wait a few minutes.';
      case 500:
        return 'Server error. Please try again later.';
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
  // Parse DioException → human-readable message (login-specific fallbacks)
  // ----------------------------------------------------------------
  String _parseDioError(DioException e) {
    if (e.response == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timed out. Please check your internet.';
        case DioExceptionType.connectionError:
          return 'Cannot reach server. Make sure the backend is running on port 8000.';
        default:
          return 'Network error. Please check your connection.';
      }
    }

    final statusCode = e.response!.statusCode;

    // 401: always show a friendly credentials message regardless of body.
    if (statusCode == 401) {
      return 'Incorrect email or password. Please try again.';
    }

    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      final msg = _parseErrorBody(data);
      if (msg != null) return msg;
    }

    switch (statusCode) {
      case 400:
        return 'Incorrect email or password. Please try again.';
      case 403:
        return 'Access denied. This account may not have vendor access.';
      case 429:
        return 'Too many login attempts. Please wait a few minutes.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Login failed (error $statusCode). Please try again.';
    }
  }

  // ----------------------------------------------------------------
  // Shared body parser — extracts the first human-readable message from
  // any Django REST Framework error response shape:
  //   { "message": "..." }
  //   { "error": { "details": {...}, "message": "..." } }
  //   { "errors": { "error": "...", "non_field_errors": [...] } }
  //   { "non_field_errors": ["..."] }
  //   { "otp"/"email": ["..."] }
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

    // Field-level list errors — otp, email
    for (final key in ['otp', 'email']) {
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
  ///   { "error": ["Invalid password"] }  →  "Invalid password"
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
