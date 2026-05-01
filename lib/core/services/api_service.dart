// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/api_endpoints.dart';
import '../routing/app_router.dart';
import '../utils/app_logger.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final StorageService _storageService;
  final GlobalKey<NavigatorState>? _navigatorKey;

  /// Broadcast stream that fires whenever the session ends — both on
  /// 401-triggered logout AND on explicit logout via the Settings
  /// screen. Every stateful feature ViewModel MUST subscribe to this
  /// and clear its in-memory state, otherwise the next user to log in
  /// on this device sees the previous vendor's data (verified as a
  /// privacy incident: "Vasu confectioners" restaurant + prior order
  /// history shown to User B on 2026-04-21).
  static final _sessionExpiredController = StreamController<void>.broadcast();
  static Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  /// Fire the session-cleared event. Called from both the 401 logout
  /// path (`_clearAndLogout`) and `AuthViewModel.logout()` so every
  /// subscribed ViewModel flushes its state on either route.
  static void fireSessionCleared() {
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  ApiService({
    required StorageService storageService,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : _storageService = storageService,
       _navigatorKey = navigatorKey {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      _AuthInterceptor(_storageService, _dio, navigatorKey: _navigatorKey),
    );
    // Clean one-liner network logs (URL + status only; body on error)
    if (!kReleaseMode) {
      _dio.interceptors.add(_CleanLogInterceptor());
    }
  }

  Dio get dio => _dio;

  /// Expose the current access token for web-portal deep links.
  Future<String?> getAccessToken() => _storageService.getAccessToken();

  /// Called by AuthViewModel at the start of the logout finally-block so the
  /// interceptor immediately rejects any auto-refresh timer requests that fire
  /// during clearAll(), preventing a spurious _clearAndLogout() navigation.
  void signalLoggingOut() => _AuthInterceptor._isLoggingOut = true;

  /// Called after logout cleanup is complete so the next fresh login session
  /// can make protected requests normally.
  void resetLoggingOut() => _AuthInterceptor._isLoggingOut = false;

  /// Called after every successful login/OTP-login. Increments the generation
  /// counter so any in-flight 401 handlers from the previous session know they
  /// are stale and must not navigate or rotate the new session's refresh token.
  void incrementLoginGeneration() => _AuthInterceptor._loginGeneration++;

  // GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  // POST
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.post(path, data: data, queryParameters: queryParameters);
  }

  // PUT
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.put(path, data: data, queryParameters: queryParameters);
  }

  // PATCH
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.patch(path, data: data, queryParameters: queryParameters);
  }

  // DELETE
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  // Multipart POST (for image uploads — new item)
  Future<Response> uploadFile(String path, {required FormData formData}) async {
    return await _dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Multipart PATCH (for image uploads — edit item)
  Future<Response> patchMultipart(
    String path, {
    required FormData formData,
  }) async {
    return await _dio.patch(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Multipart PUT (for image uploads — edit item when PATCH is not allowed)
  Future<Response> putMultipart(
    String path, {
    required FormData formData,
  }) async {
    return await _dio.put(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}

/// JWT auth interceptor — production-grade for mobile vendor apps.
///
/// Key features:
/// 1. Proactive refresh: decodes JWT exp and refreshes ~2 min before expiry
///    so vendors never see a 401 during active use.
/// 2. Concurrent request queuing: if multiple requests trigger a refresh
///    simultaneously, only ONE refresh call is made; all others await the
///    same Completer, preventing token rotation races.
/// 3. Login-generation tracking: stale 401 handlers from a previous session
///    never overwrite the new session's tokens.
class _AuthInterceptor extends Interceptor {
  final StorageService _storageService;
  final Dio _dio;
  late final Dio _refreshDio;
  final GlobalKey<NavigatorState>? _navigatorKey;

  static bool _isLoggingOut = false;
  static int _loginGeneration = 0;

  /// If non-null, a refresh is already in-flight — new 401s await this
  /// instead of firing a duplicate refresh POST.
  Completer<String?>? _refreshCompleter;

  _AuthInterceptor(
    this._storageService,
    this._dio, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) : _navigatorKey = navigatorKey {
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  // ── Proactive refresh: decode JWT exp, refresh 2 min before expiry ──

  /// Extracts the `exp` claim from a JWT without a crypto library.
  /// Returns null if the token is malformed.
  static DateTime? _tokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Base64url → Base64 (Dart's base64 decoder needs padding)
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '=';  break;
      }
      final decoded = String.fromCharCodes(
        base64Url.decode(payload),
      );
      // Minimal JSON parse — only need "exp"
      final expMatch = RegExp(r'"exp"\s*:\s*(\d+)').firstMatch(decoded);
      if (expMatch == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        int.parse(expMatch.group(1)!) * 1000,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns true if the access token will expire within [buffer].
  /// Returns false if there is no token (caller handles that separately).
  Future<bool> _isTokenExpiringSoon({
    Duration buffer = const Duration(minutes: 2),
  }) async {
    final token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) return false;
    final exp = _tokenExpiry(token);
    if (exp == null) return false; // can't decode → let server decide
    return DateTime.now().toUtc().isAfter(exp.subtract(buffer));
  }

  /// Single-flight refresh: returns the new access token, or null on failure.
  Future<String?> _refreshTokens() async {
    // If a refresh is already in-flight, piggyback on it.
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    _refreshCompleter = Completer<String?>();
    final generation = _loginGeneration;

    try {
      final refreshToken = await _storageService.getRefreshToken();

      if (_loginGeneration != generation || refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final response = await _refreshDio.post(
        ApiEndpoints.tokenRefresh,
        data: {'refresh': refreshToken},
      );

      if (_loginGeneration != generation) {
        _refreshCompleter!.complete(null);
        return null;
      }

      if (response.statusCode == 200 && response.data['access'] != null) {
        final newAccess = response.data['access'].toString();
        final newRefresh =
            response.data['refresh']?.toString() ?? refreshToken;

        await _storageService.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );
        AppLogger.i('[Auth] Token refreshed proactively');
        _refreshCompleter!.complete(newAccess);
        return newAccess;
      }

      _refreshCompleter!.complete(null);
      return null;
    } catch (e) {
      AppLogger.e('[Auth] Token refresh failed', e);
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  // ── onRequest: attach token, proactively refresh if near-expiry ───────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Public endpoints (login, register, OTP, password reset) must ALWAYS
    // pass through — even when _isLoggingOut is true after a 401 session
    // expiry.  Without this bypass, the user cannot log back in.
    final noAuthPaths = [
      ApiEndpoints.login,
      ApiEndpoints.register,
      ApiEndpoints.tokenRefresh,
      ApiEndpoints.passwordResetRequest,
      ApiEndpoints.passwordResetConfirm,
      ApiEndpoints.otpSend,
      ApiEndpoints.otpVerify,
      ApiEndpoints.otpLogin,
      ApiEndpoints.vendorWaOtpSend,
      ApiEndpoints.vendorWaOtpVerify,
    ];

    final needsAuth = !noAuthPaths.any((p) => options.path.contains(p));
    if (!needsAuth) {
      handler.next(options);
      return;
    }

    // Block all AUTHENTICATED requests while logging out — but public
    // endpoints above have already been allowed through.
    if (_isLoggingOut) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'Session expired — logging out',
        ),
      );
      return;
    }

    () async {
      try {
        // Proactive refresh: if token expires within 2 min, refresh NOW
        // before the request goes out — vendor never sees a 401.
        if (await _isTokenExpiringSoon()) {
          AppLogger.i('[Auth] Token expiring soon — proactive refresh');
          await _refreshTokens();
        }

        final token = await _storageService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        } else {
          AppLogger.w(
            '[Auth] No token for ${options.method} ${options.path} — aborting',
          );
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'No auth token',
            ),
          );
        }
      } catch (e) {
        AppLogger.e('[Auth] getAccessToken error', e);
        handler.next(options);
      }
    }();
  }

  // ── onError: handle 401 with single-flight refresh + retry ────────────

  static const _retryKey = '_authRetried';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      if (_isLoggingOut) {
        return handler.next(err);
      }

      // Already retried once with a fresh token → don't loop, just logout.
      if (err.requestOptions.extra[_retryKey] == true) {
        AppLogger.e('[Auth] Retry still got 401 — clearing session');
        () async {
          await _clearAndLogout();
          handler.next(err);
        }();
        return;
      }

      AppLogger.w('[Auth] 401 received — attempting token refresh');
      final generation = _loginGeneration;

      () async {
        try {
          if (_loginGeneration != generation) {
            handler.next(err);
            return;
          }

          final newAccess = await _refreshTokens();

          if (_loginGeneration != generation) {
            handler.next(err);
            return;
          }

          if (newAccess != null) {
            // Mark as retried so a second 401 won't loop.
            err.requestOptions.extra[_retryKey] = true;
            err.requestOptions.headers['Authorization'] =
                'Bearer $newAccess';
            try {
              final retryResponse = await _dio.fetch(err.requestOptions);
              handler.resolve(retryResponse);
              return;
            } on DioException catch (retryErr) {
              if (retryErr.type == DioExceptionType.cancel) {
                handler.next(err);
                return;
              }
            }
            handler.next(err);
            return;
          }

          // Refresh returned null — session is dead.
          if (_loginGeneration == generation) {
            AppLogger.e('[Auth] Refresh failed — clearing session');
            await _clearAndLogout();
          }
          handler.next(err);
        } catch (_) {
          handler.next(err);
        }
      }();
      return;
    }

    handler.next(err);
  }

  /// Clear storage and force-navigate to login — **once only**.
  /// _isLoggingOut stays true until resetLoggingOut() is called after next login.
  Future<void> _clearAndLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    // Notify all ViewModels to kill their timers IMMEDIATELY
    ApiService._sessionExpiredController.add(null);

    await _storageService.clearAll();

    final nav = _navigatorKey?.currentState;
    if (nav != null) {
      AppLogger.w('[Auth] Session expired — redirecting to login');
      nav.pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
    }
    // DON'T auto-reset _isLoggingOut — it stays true until next login
    // calls resetLoggingOut() via AuthViewModel.logout/login
  }
}

/// Minimal network logger: one-line per request, body only on errors.
class _CleanLogInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.network(
      response.requestOptions.method,
      response.requestOptions.path,
      response.statusCode,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Skip logging for requests we intentionally cancelled in onRequest
    // (no token / logging out) — they have no server response to log.
    if (err.type == DioExceptionType.cancel && err.response == null) {
      handler.next(err);
      return;
    }
    AppLogger.networkError(
      err.requestOptions.method,
      err.requestOptions.path,
      err.response?.statusCode,
      err.response?.data,
    );
    handler.next(err);
  }
}
