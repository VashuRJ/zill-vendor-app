import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vendor_app/core/services/api_service.dart';
import 'package:vendor_app/core/services/push_notification_service.dart';
import 'package:vendor_app/core/services/storage_service.dart';
import 'package:vendor_app/core/services/websocket_service.dart';
import 'package:vendor_app/features/auth/viewmodel/auth_viewmodel.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────
class MockApiService extends Mock implements ApiService {}

class MockStorageService extends Mock implements StorageService {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockWebSocketService extends Mock implements WebSocketService {}

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

// WhatsApp OTP login response (existing vendor — action: "login")
const kWaOtpLoginBody = {
  'action': 'login',
  'tokens': {'access': 'acc_token_123', 'refresh': 'ref_token_456'},
  'user': {'id': 1, 'name': 'Raj Kitchen', 'user_type': 'vendor'},
};

// WhatsApp OTP response — new vendor needs name (action: "register_required")
const kWaOtpRegisterRequiredBody = {
  'action': 'register_required',
  'message': 'Please provide a restaurant name to complete registration.',
};

// WhatsApp OTP response — newly registered vendor (action: "registered")
const kWaOtpRegisteredBody = {
  'action': 'registered',
  'tokens': {'access': 'acc_token_789', 'refresh': 'ref_token_abc'},
  'user': {'id': 2, 'name': 'New Place', 'user_type': 'vendor'},
};

void main() {
  late MockApiService api;
  late MockStorageService storage;
  late MockPushNotificationService push;
  late MockWebSocketService ws;
  late AuthViewModel vm;

  setUp(() {
    api = MockApiService();
    storage = MockStorageService();
    push = MockPushNotificationService();
    ws = MockWebSocketService();

    vm = AuthViewModel(
      apiService: api,
      storageService: storage,
      pushService: push,
      wsService: ws,
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
  // requestWhatsAppOtp
  // ─────────────────────────────────────────────────────────────────────────
  group('requestWhatsAppOtp', () {
    test('returns success on 200', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => fakeResponse({'message': 'OTP sent via WhatsApp.'}),
      );

      final result = await vm.requestWhatsAppOtp(phone: '9876543210');

      expect(result.success, isTrue);
      expect(result.message, 'OTP sent via WhatsApp.');
    });

    test('returns failure with wait_time on 429 (rate limited)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(429, {'wait_time': 45}));

      final result = await vm.requestWhatsAppOtp(phone: '9876543210');

      expect(result.success, isFalse);
      expect(result.waitSeconds, 45);
      expect(result.message, contains('Too many'));
    });

    test('trims phone number before sending', () async {
      when(() => api.post(
            any(),
            data: {'phone': '9876543210'},
          )).thenAnswer((_) async => fakeResponse({'message': 'sent'}));

      await vm.requestWhatsAppOtp(phone: '  9876543210  ');

      verify(() => api.post(
            any(),
            data: {'phone': '9876543210'},
          )).called(1);
    });

    test('isWaOtpSendLoading is true during request then false after', () async {
      final loadingValues = <bool>[];
      vm.addListener(() => loadingValues.add(vm.isWaOtpSendLoading));

      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse({'message': 'sent'}));

      await vm.requestWhatsAppOtp(phone: '9876543210');

      expect(loadingValues, contains(true));
      expect(vm.isWaOtpSendLoading, isFalse);
    });

    test('returns friendly message on 503 (WhatsApp service unavailable)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(503, {}));

      final result = await vm.requestWhatsAppOtp(phone: '9876543210');

      expect(result.success, isFalse);
      expect(result.message, contains('WhatsApp service unavailable'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // verifyWhatsAppOtp
  // ─────────────────────────────────────────────────────────────────────────
  group('verifyWhatsAppOtp', () {
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

    test('returns success and authenticates existing vendor', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kWaOtpLoginBody));

      final result = await vm.verifyWhatsAppOtp(
        phone: '9876543210',
        otp: '123456',
      );

      expect(result.success, isTrue);
      expect(result.action, 'login');
      expect(vm.status, AuthStatus.authenticated);
      expect(vm.username, 'Raj Kitchen');
    });

    test('returns register_required for new vendor (no login yet)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kWaOtpRegisterRequiredBody));

      final result = await vm.verifyWhatsAppOtp(
        phone: '9999999999',
        otp: '654321',
      );

      expect(result.success, isTrue);
      expect(result.action, 'register_required');
      // Should NOT be authenticated yet
      expect(vm.status, isNot(AuthStatus.authenticated));
    });

    test('registers and authenticates new vendor with restaurant name', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kWaOtpRegisteredBody));

      final result = await vm.verifyWhatsAppOtp(
        phone: '9999999999',
        otp: '654321',
        restaurantName: 'New Place',
      );

      expect(result.success, isTrue);
      expect(result.action, 'registered');
      expect(vm.status, AuthStatus.authenticated);
      expect(vm.username, 'New Place');
    });

    test('saves tokens and user info to storage on login', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kWaOtpLoginBody));

      await vm.verifyWhatsAppOtp(phone: '9876543210', otp: '123456');

      verify(
        () => storage.saveTokens(
          accessToken: 'acc_token_123',
          refreshToken: 'ref_token_456',
        ),
      ).called(1);
    });

    test('returns failure on 400 (invalid OTP)', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(400, {'message': 'Invalid OTP'}));

      final result = await vm.verifyWhatsAppOtp(
        phone: '9876543210',
        otp: '000000',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Invalid OTP');
    });

    test('returns network error message when no response', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final result = await vm.verifyWhatsAppOtp(
        phone: '9876543210',
        otp: '123456',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Network error'));
    });

    test('isWaOtpVerifyLoading is true during request then false after', () async {
      final loadingValues = <bool>[];
      vm.addListener(() => loadingValues.add(vm.isWaOtpVerifyLoading));

      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse(kWaOtpLoginBody));

      await vm.verifyWhatsAppOtp(phone: '9876543210', otp: '123456');

      expect(loadingValues, contains(true));
      expect(vm.isWaOtpVerifyLoading, isFalse);
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
  // clearError
  // ─────────────────────────────────────────────────────────────────────────
  group('clearError', () {
    test('does NOT notify listeners when errorMessage is already null', () {
      var notified = false;
      vm.addListener(() => notified = true);

      vm.clearError(); // nothing to clear

      expect(notified, isFalse);
    });
  });
}
