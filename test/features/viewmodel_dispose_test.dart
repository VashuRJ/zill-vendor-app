/// [TEST 1] ViewModel Dispose Memory Leak Fix
///
/// Proves that calling async API methods AFTER dispose() does NOT throw
/// "A ChangeNotifier was used after being disposed" error.
///
/// Tests both BankTabViewModel and TicketViewModel.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vendor_app/core/services/api_service.dart';
import 'package:vendor_app/features/earnings/viewmodel/bank_tab_viewmodel.dart';
import 'package:vendor_app/features/support/viewmodel/ticket_viewmodel.dart';

// ── Mocks ──────────────────────────────────────────────────────────────
class MockApiService extends Mock implements ApiService {}

// ── Helpers ────────────────────────────────────────────────────────────
Response<dynamic> _fakeResponse(dynamic data, {int statusCode = 200}) =>
    Response(
      data: data,
      statusCode: statusCode,
      requestOptions: RequestOptions(path: ''),
    );

DioException _fakeDioError(int statusCode, dynamic data) => DioException(
      type: DioExceptionType.badResponse,
      requestOptions: RequestOptions(path: ''),
      response: Response(
        statusCode: statusCode,
        data: data,
        requestOptions: RequestOptions(path: ''),
      ),
    );

void main() {
  late MockApiService mockApi;

  setUp(() {
    mockApi = MockApiService();
    // Register fallback values for mocktail
    registerFallbackValue(RequestOptions(path: ''));
  });

  // ────────────────────────────────────────────────────────────────────
  //  BankTabViewModel — dispose safety
  // ────────────────────────────────────────────────────────────────────
  group('BankTabViewModel dispose safety', () {
    late BankTabViewModel vm;

    setUp(() {
      vm = BankTabViewModel(apiService: mockApi);
    });

    test('loadAll completes without error after dispose', () async {
      // Arrange: stub all 5 parallel API calls to return after a delay
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({'orders': []});
      });
      when(() => mockApi.get(any()))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({});
      });

      // Act: start loadAll, immediately dispose
      final future = vm.loadAll();
      vm.dispose();

      // Assert: future completes without throwing
      await expectLater(future, completes);
    });

    test('registerBankAccount completes without error after dispose', () async {
      when(() => mockApi.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({'message': 'ok'});
      });
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => _fakeResponse({'bank_account': null}),
      );

      final future = vm.registerBankAccount(
        holderName: 'Test',
        accountNumber: '1234567890',
        ifscCode: 'SBIN0001',
      );
      vm.dispose();

      await expectLater(future, completes);
    });

    test('requestPayout completes without error after dispose', () async {
      when(() => mockApi.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({'message': 'ok'});
      });
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => _fakeResponse({}),
      );

      final future = vm.requestPayout(500.0);
      vm.dispose();

      await expectLater(future, completes);
    });

    test('loadMoreSettlements completes without error after dispose', () async {
      // Set _hasMore = true by doing a partial load first
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({
          'settlements': [],
          'total': 100,
        });
      });
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => _fakeResponse({}),
      );

      // First load to set state
      await vm.loadAll();

      // Now dispose and try loadMore
      vm.dispose();
      // This should not throw
      await vm.loadMoreSettlements();
    });

    test('setFilter after dispose does not throw', () {
      vm.dispose();
      // Synchronous notifyListeners — should be guarded
      expect(() => vm.setFilter('Today'), returnsNormally);
    });

    test('clearPayoutReqStatus after dispose does not throw', () {
      vm.dispose();
      expect(() => vm.clearPayoutReqStatus(), returnsNormally);
    });

    test('notifyListeners count is zero after dispose', () {
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.dispose();

      // These should all be silently ignored
      vm.setFilter('Today');

      expect(notifyCount, 0, reason: '_notify() should skip after dispose');
    });

    test('loadAll with DioException after dispose does not throw', () async {
      when(() => mockApi.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw _fakeDioError(500, {'error': 'Server error'});
      });
      when(() => mockApi.get(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw _fakeDioError(500, {'error': 'Server error'});
      });

      final future = vm.loadAll();
      vm.dispose();

      await expectLater(future, completes);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  //  TicketViewModel — dispose safety
  // ────────────────────────────────────────────────────────────────────
  group('TicketViewModel dispose safety', () {
    late TicketViewModel vm;

    setUp(() {
      vm = TicketViewModel(apiService: mockApi);
    });

    test('fetchTickets completes without error after dispose', () async {
      when(() => mockApi.get(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({'tickets': []});
      });

      final future = vm.fetchTickets();
      vm.dispose();

      await expectLater(future, completes);
    });

    test('createTicket completes without error after dispose', () async {
      when(() => mockApi.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return _fakeResponse({'success': true}, statusCode: 201);
      });
      when(() => mockApi.get(any())).thenAnswer(
        (_) async => _fakeResponse({'tickets': []}),
      );

      final future = vm.createTicket(
        subject: 'Test',
        description: 'Test description here',
        category: 'order',
      );
      vm.dispose();

      await expectLater(future, completes);
    });

    test('createTicket with DioException after dispose does not throw', () async {
      when(() => mockApi.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw _fakeDioError(500, {'error': 'timeout'});
      });

      final future = vm.createTicket(
        subject: 'Test',
        description: 'Test description here',
        category: 'order',
      );
      vm.dispose();

      await expectLater(future, completes);
    });

    test('fetchTickets with network error after dispose does not throw', () async {
      when(() => mockApi.get(any())).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        );
      });

      final future = vm.fetchTickets();
      vm.dispose();

      await expectLater(future, completes);
    });

    test('notifyListeners count is zero after dispose', () {
      int notifyCount = 0;
      vm.addListener(() => notifyCount++);

      // Trigger a state change, verify listener fires
      // (before dispose)
      vm.fetchTickets(); // triggers _notify() for loading state
      expect(notifyCount, greaterThan(0));

      final countBeforeDispose = notifyCount;
      vm.dispose();

      // Try triggering after dispose — count should not increase
      vm.fetchTickets();
      expect(notifyCount, countBeforeDispose,
          reason: '_notify() should be silenced after dispose');
    });
  });
}
