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

/// Interceptor to attach JWT token and handle 401 refresh.
/// Uses plain Interceptor (not QueuedInterceptor) so all requests are dispatched
/// in parallel. The async getAccessToken() is handled via .then() so
/// handler.next() is guaranteed to be called only after the token resolves,
/// without turning onRequest into an async void (which Dio ignores).
class _AuthInterceptor extends Interceptor {
  final StorageService _storageService;
  final Dio _dio;
  final GlobalKey<NavigatorState>? _navigatorKey;

  /// Static lock — prevents multiple simultaneous 401s from each triggering
  /// their own logout + navigation, which causes ghosting / flickering.
  static bool _isLoggingOut = false;

  /// Incremented on every successful login. Any 401 handler that was started
  /// before the most recent login is "stale" — it must not navigate or
  /// consume/rotate the new session's refresh token.
  static int _loginGeneration = 0;

  _AuthInterceptor(
    this._storageService,
    this._dio, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) : _navigatorKey = navigatorKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // If we're already in the process of logging out, reject immediately
    // so no new API calls pile up and trigger more 401s.
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

    // Skip auth header for public endpoints
    final noAuthPaths = [
      ApiEndpoints.login,
      ApiEndpoints.register,
      ApiEndpoints.tokenRefresh,
      ApiEndpoints.passwordResetRequest,
      ApiEndpoints.passwordResetConfirm,
      ApiEndpoints.otpSend,
      ApiEndpoints.otpVerify,
      ApiEndpoints.otpLogin,
    ];

    final needsAuth = !noAuthPaths.any((p) => options.path.contains(p));

    if (!needsAuth) {
      handler.next(options);
      return;
    }

    // Use .then() — never async void, so Dio always awaits the resolution
    _storageService
        .getAccessToken()
        .then((token) {
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          } else {
            // No token in storage → user is logged out. Reject immediately
            // so the request never reaches the server and triggers a 401 →
            // refresh → _clearAndLogout() cycle that would rebuild the login
            // screen while the user is typing.
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
        })
        .catchError((e) {
          AppLogger.e('[Auth] getAccessToken error', e);
          handler.next(options); // proceed without token rather than hanging
        });
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // If another 401 already triggered logout, don't duplicate the work.
      if (_isLoggingOut) {
        return handler.next(err);
      }

      AppLogger.w('[Auth] 401 received — attempting token refresh');

      // Snapshot the login generation BEFORE any async work. If the user
      // logs in again while this handler is awaiting, the generation will
      // have changed and we must discard this stale 401 without navigating
      // or consuming the new session's refresh token.
      final generation = _loginGeneration;

      // Async IIFE — avoids Dart 3.x .catchError() return-type runtime checks.
      () async {
        try {
          final refreshToken = await _storageService.getRefreshToken();

          // Stale check — new login happened while we were awaiting storage.
          if (_loginGeneration != generation) {
            handler.next(err);
            return;
          }

          if (refreshToken == null) {
            AppLogger.e('[Auth] No refresh token — clearing session');
            await _clearAndLogout();
            handler.next(err);
            return;
          }

          try {
            final response = await Dio().post(
              '${ApiEndpoints.baseUrl}${ApiEndpoints.tokenRefresh}',
              data: {'refresh': refreshToken},
            );

            // Stale check — new login happened while the refresh POST was
            // in-flight. Don't overwrite the new session's tokens.
            if (_loginGeneration != generation) {
              handler.next(err);
              return;
            }

            if (response.statusCode == 200) {
              final newAccess = response.data['access'] as String;
              final newRefresh =
                  response.data['refresh'] as String? ?? refreshToken;

              await _storageService.saveTokens(
                accessToken: newAccess,
                refreshToken: newRefresh,
              );

              AppLogger.i('[Auth] Token refreshed — retrying request');
              err.requestOptions.headers['Authorization'] =
                  'Bearer $newAccess';
              try {
                final retryResponse = await _dio.fetch(err.requestOptions);
                handler.resolve(retryResponse);
                return;
              } on DioException catch (retryErr) {
                // Retry was cancelled because _isLoggingOut is true — logout
                // is already in progress. Pass the original 401 up silently
                // so _silentRefresh can stop the timer. Do NOT navigate.
                if (retryErr.type == DioExceptionType.cancel) {
                  handler.next(err);
                  return;
                }
                // Retry got another server error — fall through to handler.next
              }
              handler.next(err);
              return;
            }
          } catch (e) {
            // Refresh POST itself failed (network error or 400/401 from server).
            // Only navigate if this 401 is still from the current session.
            if (_loginGeneration == generation) {
              AppLogger.e('[Auth] Token refresh failed — clearing session', e);
              await _clearAndLogout();
            }
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
  Future<void> _clearAndLogout() async {
    if (_isLoggingOut) return; // already in progress
    _isLoggingOut = true;

    await _storageService.clearAll();

    final nav = _navigatorKey?.currentState;
    if (nav != null) {
      AppLogger.w('[Auth] Session expired — redirecting to login');
      nav.pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
    }

    // Reset the lock after a short delay so the next fresh login session
    // can hit 401 → refresh normally again.
    Future.delayed(const Duration(seconds: 2), () {
      _isLoggingOut = false;
    });
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
