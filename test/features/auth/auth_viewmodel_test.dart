import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vendor_app/core/services/api_service.dart';
import 'package:vendor_app/core/services/push_notification_service.dart';
import 'package:vendor_app/core/services/storage_service.dart';
import 'package:vendor_app/features/auth/viewmodel/auth_viewmodel.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────
class MockApiService extends Mock implements ApiService {}

class MockStorageService extends Mock implements StorageService {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

// ── Helpers ────────────────────────────────────────────────────────────────
Response<dynamic> fakeResponse(dynamic data, {int statusCode = 200}) =>
    Response(
      data: data,
      statusCode: statusCode,
      requestOptions: RequestOptions(path: ''),
    );

DioException fakeDioError(int statusCode, dynamic data) => DioException(
      type: DioExceptionType.badResponse,
      requestOptions: RequestOptions(path: ''),
      response: Response(
        data: data,
        statusCode: statusCode,
        requestOptions: RequestOptions(path: ''),
      ),
    );

// Successful login response body (vendor login wraps under "data" key)
const kLoginSuccessBody = {
  'data': {
    'tokens': {'access': 'acc_token_123', 'refresh': 'ref_token_456'},
    'user': {'id': 1, 'username': 'raj_vendor', 'user_type': 'vendor'},
  },
};

// OTP login response (flat — no "data" wrapper)
const kOtpLoginSuccessBody = {
  'tokens': {'access': 'acc_token_123', 'refresh': 'ref_token_456'},
  'user': {'id': 1, 'username': 'raj_vendor', 'user_type': 'vendor'},
};

void main() {
  late MockApiService api;
  late MockStorageService storage;
  late MockPushNotificationService push;
  late AuthViewModel vm;

  setUp(() {
    api = MockApiService();
    storage = MockStorageService();
    push = MockPushNotificationService();

    vm = AuthViewModel(
      apiService: api,
      storageService: storage,
      pushService: push,
    );

    // Push service: always succeeds silently in tests
    when(() => push.initialize()).thenAnswer((_) async {});
    when(() => push.unregister()).thenAnswer((_) async {});
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Initial state
  // ─────────────────────────────────────────────────────────────────────────
  group('Initial state', () {
    test('status starts as initial', () {
      expect(vm.status, AuthStatus.initial);
    });

    test('isAuthenticated is false initially', () {
      expect(vm.isAuthenticated, isFalse);
    });

    test('isLoading is false initially', () {
      expect(vm.isLoading, isFalse);
    });

    test('errorMessage is null initially', () {
      expect(vm.errorMessage, isNull);
    });

    test('username is null initially', () {
      expect(vm.username, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // checkAuthStatus
  // ─────────────────────────────────────────────────────────────────────────
  group('checkAuthStatus', () {
    test('sets authenticated + username when tokens exist in storage', () async {
      when(() => storage.hasTokens()).thenAnswer((_) async => true);
      when(() => storage.getUsername()).thenAnswer((_) async => 'raj_vendor');

      await vm.checkAuthStatus();

      expect(vm.status, AuthStatus.authenticated);
      expect(vm.username, 'raj_vendor');
      expect(vm.isAuthenticated, isTrue);
    });

    test('sets unauthenticated when no tokens in storage', () async {
      when(() => storage.hasTokens()).thenAnswer((_) async => false);

      await vm.checkAuthStatus();

      expect(vm.status, AuthStatus.unauthenticated);
      expect(vm.isAuthenticated, isFalse);
    });

    test('sets unauthenticated when storage throws an exception', () async {
      when(() => storage.hasTokens()).thenThrow(Exception('storage failure'));

      await vm.checkAuthStatus();

      expect(vm.status, AuthStatus.unauthenticated);
    });

    test('notifies listeners after check', () async {
      when(() => storage.hasTokens()).thenAnswer((_) async => false);

      var notified = false;
      vm.addListener(() => notified = true);

      await vm.checkAuthStatus();

      expect(notified, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // login
  // ─────────────────────────────────────────────────────────────────────────
  group('login', () {
    setUp(() {
      when(
        () => storage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => storage.saveUserInfo(
          userId: any(named: 'userId'),
          username: any(named: 'username'),
          userType: any(named: 'userType'),
        ),
      ).thenAnswer((_) async {});
    });

    test('returns true and sets authenticated on 200 success', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kLoginSuccessBody));

      final result =
          await vm.login(loginId: 'raj@test.com', password: 'secret');

      expect(result, isTrue);
      expect(vm.status, AuthStatus.authenticated);
      expect(vm.username, 'raj_vendor');
      expect(vm.errorMessage, isNull);
    });

    test('saves tokens and user info to storage on success', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kLoginSuccessBody));

      await vm.login(loginId: 'raj@test.com', password: 'secret');

      verify(
        () => storage.saveTokens(
          accessToken: 'acc_token_123',
          refreshToken: 'ref_token_456',
        ),
      ).called(1);

      verify(
        () => storage.saveUserInfo(
          userId: 1,
          username: 'raj_vendor',
          userType: 'vendor',
        ),
      ).called(1);
    });

    test('goes through loading state before authenticating', () async {
      final states = <AuthStatus>[];
      vm.addListener(() => states.add(vm.status));

      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kLoginSuccessBody));

      await vm.login(loginId: 'raj@test.com', password: 'secret');

      expect(states, containsAllInOrder([AuthStatus.loading, AuthStatus.authenticated]));
    });

    test('trims whitespace from loginId before sending', () async {
      when(() => api.post(
            any(),
            data: {'login': 'raj@test.com', 'password': 'secret'},
          )).thenAnswer((_) async => fakeResponse(kLoginSuccessBody));

      await vm.login(loginId: '  raj@test.com  ', password: 'secret');

      verify(() => api.post(
            any(),
            data: {'login': 'raj@test.com', 'password': 'secret'},
          )).called(1);
    });

    test('returns false and sets error on 401 (wrong credentials)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(401, {'detail': 'Invalid credentials'}));

      final result =
          await vm.login(loginId: 'wrong@test.com', password: 'bad');

      expect(result, isFalse);
      expect(vm.status, AuthStatus.error);
      expect(
        vm.errorMessage,
        'Incorrect email or password. Please try again.',
      );
    });

    test('returns false with vendor-access error on 403', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(403, {'detail': 'Forbidden'}));

      final result = await vm.login(loginId: 'a@b.com', password: 'p');

      expect(result, isFalse);
      // The 'detail' key is parsed directly before the status-code switch,
      // so the server's raw message is returned as-is.
      expect(vm.errorMessage, 'Forbidden');
    });

    test('returns false with rate-limit message on 429', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(429, {}));

      await vm.login(loginId: 'a@b.com', password: 'p');

      expect(vm.errorMessage, contains('Too many'));
    });

    test('parses DRF message shape: { "message": "..." }', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenThrow(
        fakeDioError(400, {'message': 'Account is deactivated'}),
      );

      await vm.login(loginId: 'a@b.com', password: 'p');

      expect(vm.errorMessage, 'Account is deactivated');
    });

    test('parses DRF non_field_errors shape', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenThrow(
        fakeDioError(400, {
          'non_field_errors': ['Unable to log in with provided credentials.'],
        }),
      );

      await vm.login(loginId: 'a@b.com', password: 'p');

      expect(vm.errorMessage, 'Unable to log in with provided credentials.');
    });

    test('parses nested error.message shape', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenThrow(
        fakeDioError(400, {
          'error': {'message': 'Phone number not verified'},
        }),
      );

      await vm.login(loginId: 'a@b.com', password: 'p');

      expect(vm.errorMessage, 'Phone number not verified');
    });

    test('returns connection-timeout message when no server response', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await vm.login(loginId: 'a@b.com', password: 'p');

      expect(result, isFalse);
      expect(vm.errorMessage, contains('timed out'));
    });

    test('returns cannot-reach-server message on connectionError', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await vm.login(loginId: 'a@b.com', password: 'p');

      expect(vm.errorMessage, contains('Cannot reach server'));
    });

    test('handles unexpected non-Dio exception gracefully', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(Exception('unknown'));

      final result = await vm.login(loginId: 'a@b.com', password: 'p');

      expect(result, isFalse);
      expect(vm.status, AuthStatus.error);
      expect(vm.errorMessage, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // logout
  // ─────────────────────────────────────────────────────────────────────────
  group('logout', () {
    test('clears storage and sets status to unauthenticated', () async {
      when(() => storage.getRefreshToken())
          .thenAnswer((_) async => 'ref_token_456');
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse({'message': 'logged out'}));
      when(() => storage.clearAll()).thenAnswer((_) async {});

      await vm.logout();

      expect(vm.status, AuthStatus.unauthenticated);
      expect(vm.username, isNull);
      verify(() => storage.clearAll()).called(1);
    });

    test('still clears local storage even when logout API call fails', () async {
      when(() => storage.getRefreshToken())
          .thenAnswer((_) async => 'ref_token_456');
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(500, {}));
      when(() => storage.clearAll()).thenAnswer((_) async {});

      await vm.logout();

      expect(vm.status, AuthStatus.unauthenticated);
      verify(() => storage.clearAll()).called(1);
    });

    test('unregisters FCM push token on logout', () async {
      when(() => storage.getRefreshToken()).thenAnswer((_) async => null);
      when(() => storage.clearAll()).thenAnswer((_) async {});

      await vm.logout();

      verify(() => push.unregister()).called(1);
    });

    test('skips API call when no refresh token in storage', () async {
      when(() => storage.getRefreshToken()).thenAnswer((_) async => null);
      when(() => storage.clearAll()).thenAnswer((_) async {});

      await vm.logout();

      verifyNever(() => api.post(any(), data: any(named: 'data')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // requestPasswordReset
  // ─────────────────────────────────────────────────────────────────────────
  group('requestPasswordReset', () {
    test('returns success: true with server message on 200', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => fakeResponse({'message': 'OTP sent to your email'}),
      );

      final result =
          await vm.requestPasswordReset(email: 'vendor@test.com');

      expect(result.success, isTrue);
      expect(result.message, 'OTP sent to your email');
    });

    test('uses fallback message when server response has no message field',
        () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse({}));

      final result = await vm.requestPasswordReset(email: 'v@test.com');

      expect(result.success, isTrue);
      expect(result.message, isNotEmpty);
    });

    test('returns success: false with 404 (email not found)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(404, {}));

      final result = await vm.requestPasswordReset(email: 'nobody@test.com');

      expect(result.success, isFalse);
      expect(result.message, contains('No account found'));
    });

    test('isResetLoading is true during request then false after', () async {
      final loadingValues = <bool>[];
      vm.addListener(() => loadingValues.add(vm.isResetLoading));

      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse({'message': 'sent'}));

      await vm.requestPasswordReset(email: 'v@test.com');

      expect(loadingValues, contains(true));
      expect(vm.isResetLoading, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // requestOtp
  // ─────────────────────────────────────────────────────────────────────────
  group('requestOtp', () {
    test('returns success on 200', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => fakeResponse({'message': 'OTP sent successfully.'}),
      );

      final result = await vm.requestOtp(email: 'vendor@test.com');

      expect(result.success, isTrue);
      expect(result.message, 'OTP sent successfully.');
    });

    test('sends purpose=login in the request payload', () async {
      when(() => api.post(
            any(),
            data: {'email': 'vendor@test.com', 'purpose': 'login'},
          )).thenAnswer((_) async => fakeResponse({'message': 'sent'}));

      await vm.requestOtp(email: 'vendor@test.com');

      verify(() => api.post(
            any(),
            data: {'email': 'vendor@test.com', 'purpose': 'login'},
          )).called(1);
    });

    test('returns failure on 429 (rate limited)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(429, {}));

      final result = await vm.requestOtp(email: 'vendor@test.com');

      expect(result.success, isFalse);
      expect(result.message, contains('Too many'));
    });

    test('isOtpSendLoading is true during request then false after', () async {
      final loadingValues = <bool>[];
      vm.addListener(() => loadingValues.add(vm.isOtpSendLoading));

      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse({'message': 'sent'}));

      await vm.requestOtp(email: 'vendor@test.com');

      expect(loadingValues, contains(true));
      expect(vm.isOtpSendLoading, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // verifyOtpAndLogin
  // ─────────────────────────────────────────────────────────────────────────
  group('verifyOtpAndLogin', () {
    setUp(() {
      when(
        () => storage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.saveUserInfo(
          userId: any(named: 'userId'),
          username: any(named: 'username'),
          userType: any(named: 'userType'),
        ),
      ).thenAnswer((_) async {});
    });

    test('returns success and authenticates on valid OTP', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kOtpLoginSuccessBody));

      final result = await vm.verifyOtpAndLogin(
        email: 'vendor@test.com',
        otp: '123456',
      );

      expect(result.success, isTrue);
      expect(vm.status, AuthStatus.authenticated);
      expect(vm.username, 'raj_vendor');
    });

    test('returns failure on 400 (invalid OTP)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(400, {'message': 'Invalid OTP'}));

      final result = await vm.verifyOtpAndLogin(
        email: 'vendor@test.com',
        otp: '000000',
      );

      expect(result.success, isFalse);
      expect(result.message, isNotEmpty);
    });

    test('returns failure on 404 (no vendor account)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(404, {}));

      final result = await vm.verifyOtpAndLogin(
        email: 'unknown@test.com',
        otp: '123456',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('No vendor account'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // clearError
  // ─────────────────────────────────────────────────────────────────────────
  group('clearError', () {
    test('clears error message and notifies listeners', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(401, {}));
      await vm.login(loginId: 'x', password: 'y');
      expect(vm.errorMessage, isNotNull);

      var notified = false;
      vm.addListener(() => notified = true);

      vm.clearError();

      expect(vm.errorMessage, isNull);
      expect(notified, isTrue);
    });

    test('does NOT notify listeners when errorMessage is already null', () {
      var notified = false;
      vm.addListener(() => notified = true);

      vm.clearError(); // nothing to clear

      expect(notified, isFalse);
    });
  });
}
