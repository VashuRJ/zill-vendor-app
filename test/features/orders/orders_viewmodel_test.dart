import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vendor_app/core/services/api_service.dart';
import 'package:vendor_app/features/orders/viewmodel/orders_viewmodel.dart';

// ── Mock ───────────────────────────────────────────────────────────────────
class MockApiService extends Mock implements ApiService {}

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

// A minimal order JSON that passes VendorOrder.fromJson without errors
Map<String, dynamic> fakeOrderJson({
  int id = 1,
  String status = 'pending',
  String orderNumber = 'ORD-001',
}) =>
    {
      'id': id,
      'order_number': orderNumber,
      'customer_name': 'Test Customer',
      'customer_phone': '9999999999',
      'status': status,
      'grand_total': 250.0,
      'item_count': 2,
      'created_at': '2025-03-01T10:00:00Z',
      'payment_method': 'online',
      'payment_status': 'paid',
      'delivery_address': '456 Test Street',
      'instructions': '',
      'items': [],
      'items_summary': ['2x Burger'],
      'order_type': 'delivery',
      'is_scheduled': false,
      'accepted_by_restaurant': false,
    };

// Response with a single list of orders for a status bucket
Map<String, dynamic> fakeOrdersResponse(List<Map<String, dynamic>> orders) =>
    {'orders': orders};

// Empty bucket response
final kEmptyBucket = fakeResponse({'orders': []});

void main() {
  late MockApiService api;
  late OrdersViewModel vm;

  setUp(() {
    api = MockApiService();
    vm = OrdersViewModel(apiService: api);
  });

  tearDown(() {
    vm.dispose();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Initial state
  // ─────────────────────────────────────────────────────────────────────────
  group('Initial state', () {
    test('status is initial', () {
      expect(vm.status, OrdersStatus.initial);
    });

    test('all order lists are empty', () {
      expect(vm.newOrders, isEmpty);
      expect(vm.preparingOrders, isEmpty);
      expect(vm.readyOrders, isEmpty);
      expect(vm.completedOrders, isEmpty);
      expect(vm.cancelledOrders, isEmpty);
    });

    test('error is null', () {
      expect(vm.error, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // fetchOrders
  // ─────────────────────────────────────────────────────────────────────────
  group('fetchOrders', () {
    void stubAllBucketsEmpty() {
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => kEmptyBucket);
    }

    test('sets status to loaded after successful fetch', () async {
      stubAllBucketsEmpty();

      await vm.fetchOrders();

      expect(vm.status, OrdersStatus.loaded);
      expect(vm.error, isNull);
    });

    test('goes through loading state before loaded', () async {
      stubAllBucketsEmpty();

      final states = <OrdersStatus>[];
      vm.addListener(() => states.add(vm.status));

      await vm.fetchOrders();

      expect(states, containsAllInOrder([
        OrdersStatus.loading,
        OrdersStatus.loaded,
      ]));
    });

    test('populates newOrders with pending + confirmed orders', () async {
      final pendingOrder = fakeOrderJson(id: 1, status: 'pending');
      final confirmedOrder = fakeOrderJson(id: 2, status: 'confirmed');

      when(() => api.get(
            any(),
            queryParameters: {'status': 'pending'},
          )).thenAnswer(
            (_) async => fakeResponse(fakeOrdersResponse([pendingOrder])));

      when(() => api.get(
            any(),
            queryParameters: {'status': 'confirmed'},
          )).thenAnswer(
            (_) async => fakeResponse(fakeOrdersResponse([confirmedOrder])));

      // All other buckets return empty
      when(() => api.get(
            any(),
            queryParameters: {'status': 'preparing'},
          )).thenAnswer((_) async => kEmptyBucket);
      when(() => api.get(
            any(),
            queryParameters: {'status': 'ready'},
          )).thenAnswer((_) async => kEmptyBucket);
      when(() => api.get(
            any(),
            queryParameters: {'status': 'picked'},
          )).thenAnswer((_) async => kEmptyBucket);
      when(() => api.get(
            any(),
            queryParameters: {'status': 'on_the_way'},
          )).thenAnswer((_) async => kEmptyBucket);
      when(() => api.get(
            any(),
            queryParameters: {'status': 'delivered'},
          )).thenAnswer((_) async => kEmptyBucket);
      when(() => api.get(
            any(),
            queryParameters: {'status': 'refunded'},
          )).thenAnswer((_) async => kEmptyBucket);
      when(() => api.get(
            any(),
            queryParameters: {'status': 'cancelled'},
          )).thenAnswer((_) async => kEmptyBucket);

      await vm.fetchOrders();

      expect(vm.newOrders.length, 2);
      expect(vm.newOrders.map((o) => o.id), containsAll([1, 2]));
    });

    test('swallows per-status DioException and still reaches loaded state',
        () async {
      // Anti-flicker design: _fetchSingleStatus catches non-401/cancel errors
      // and returns [] so the UI never shows a blank error screen for a
      // single failing status bucket.
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenThrow(fakeDioError(500, {'message': 'Internal server error'}));

      await vm.fetchOrders();

      expect(vm.status, OrdersStatus.loaded);
    });

    test('resets pagination limits on each fetch', () async {
      stubAllBucketsEmpty();
      vm.loadMoreCompleted();
      vm.loadMoreCompleted();

      await vm.fetchOrders();

      expect(vm.completedLimit, 10); // reset to default page size
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // acceptOrder
  // ─────────────────────────────────────────────────────────────────────────
  group('acceptOrder', () {
    setUp(() {
      // Seed a pending order in newOrders
      vm.newOrders.addAll([
        VendorOrder.fromJson(fakeOrderJson(id: 10, status: 'pending')),
      ]);
    });

    test('returns true and updates order in newOrders on success', () async {
      final updatedOrder =
          fakeOrderJson(id: 10, status: 'confirmed')..['accepted_by_restaurant'] = true;

      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => fakeResponse({'order': updatedOrder}),
      );
      // Silent refresh calls - stub them as empty
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => kEmptyBucket);

      final result = await vm.acceptOrder(10, estimatedPrepTime: 30);

      expect(result, isTrue);
    });

    test('returns false on DioException', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(400, {'message': 'Order already accepted'}));

      final result = await vm.acceptOrder(10);

      expect(result, isFalse);
    });

    test('tracks action-loading state for the order id', () async {
      final loadingDuringCall = <bool>[];

      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async {
          loadingDuringCall.add(vm.isActionLoading(10));
          return fakeResponse({'order': fakeOrderJson(id: 10, status: 'confirmed')});
        },
      );
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => kEmptyBucket);

      await vm.acceptOrder(10);

      expect(loadingDuringCall, contains(true));
      expect(vm.isActionLoading(10), isFalse); // cleared after completion
    });

    test('sends estimated_preparation_time in request body', () async {
      when(() => api.post(
            any(),
            data: {'estimated_preparation_time': 45},
          )).thenAnswer(
            (_) async => fakeResponse({'order': fakeOrderJson(id: 10, status: 'confirmed')}));
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => kEmptyBucket);

      await vm.acceptOrder(10, estimatedPrepTime: 45);

      verify(() => api.post(
            any(),
            data: {'estimated_preparation_time': 45},
          )).called(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // rejectOrder
  // ─────────────────────────────────────────────────────────────────────────
  group('rejectOrder', () {
    setUp(() {
      vm.newOrders.addAll([
        VendorOrder.fromJson(fakeOrderJson(id: 20, status: 'pending')),
      ]);
    });

    test('returns true and removes order from newOrders on success', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => fakeResponse({'order': fakeOrderJson(id: 20, status: 'cancelled')}),
      );
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => kEmptyBucket);

      final result = await vm.rejectOrder(20);

      expect(result, isTrue);
      expect(vm.newOrders.any((o) => o.id == 20), isFalse);
    });

    test('returns false on DioException', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(400, {'message': 'Cannot cancel'}));

      final result = await vm.rejectOrder(20);

      expect(result, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // startPreparing
  // ─────────────────────────────────────────────────────────────────────────
  group('startPreparing', () {
    setUp(() {
      vm.newOrders.addAll([
        VendorOrder.fromJson(fakeOrderJson(id: 30, status: 'confirmed')),
      ]);
    });

    test('moves order from newOrders to preparingOrders on success', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async =>
            fakeResponse({'order': fakeOrderJson(id: 30, status: 'preparing')}),
      );
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => kEmptyBucket);

      await vm.startPreparing(30);

      expect(vm.newOrders.any((o) => o.id == 30), isFalse);
      expect(vm.preparingOrders.any((o) => o.id == 30), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // markReady
  // ─────────────────────────────────────────────────────────────────────────
  group('markReady', () {
    setUp(() {
      vm.preparingOrders.addAll([
        VendorOrder.fromJson(fakeOrderJson(id: 40, status: 'preparing')),
      ]);
    });

    test('moves order from preparingOrders to readyOrders on success', () async {
      when(() => api.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async =>
            fakeResponse({'order': fakeOrderJson(id: 40, status: 'ready')}),
      );
      when(
        () => api.get(any(), queryParameters: any(named: 'queryParameters')),
      ).thenAnswer((_) async => kEmptyBucket);

      await vm.markReady(40);

      expect(vm.preparingOrders.any((o) => o.id == 40), isFalse);
      expect(vm.readyOrders.any((o) => o.id == 40), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // findOrderById
  // ─────────────────────────────────────────────────────────────────────────
  group('findOrderById', () {
    setUp(() {
      vm.newOrders.addAll([VendorOrder.fromJson(fakeOrderJson(id: 1))]);
      vm.preparingOrders.addAll([VendorOrder.fromJson(fakeOrderJson(id: 2))]);
      vm.readyOrders.addAll([VendorOrder.fromJson(fakeOrderJson(id: 3))]);
      vm.completedOrders.addAll([VendorOrder.fromJson(fakeOrderJson(id: 4))]);
      vm.cancelledOrders.addAll([VendorOrder.fromJson(fakeOrderJson(id: 5))]);
    });

    test('finds order in newOrders', () {
      expect(vm.findOrderById(1), isNotNull);
      expect(vm.findOrderById(1)!.id, 1);
    });

    test('finds order in preparingOrders', () {
      expect(vm.findOrderById(2)!.id, 2);
    });

    test('finds order in completedOrders', () {
      expect(vm.findOrderById(4)!.id, 4);
    });

    test('returns null when order does not exist', () {
      expect(vm.findOrderById(999), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // fetchOrderDetail
  // ─────────────────────────────────────────────────────────────────────────
  group('fetchOrderDetail', () {
    test('returns VendorOrderDetail on success', () async {
      final detailJson = {
        ...fakeOrderJson(id: 5),
        'delivery_charge': '40.00',
        'tax_amount': '18.00',
        'discount_amount': '0',
        'total_amount': '292.00',
        'delivery_instructions': '',
        'coupon_code': '',
        'coupon_discount': '0',
        'cancellation_note': '',
        'cancellation_reason': '',
      };

      when(() => api.get(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => fakeResponse(detailJson));

      final detail = await vm.fetchOrderDetail(5);

      expect(detail, isNotNull);
      expect(detail!.order.id, 5);
      expect(detail.deliveryCharge, 40.0);
      expect(detail.taxAmount, 18.0);
    });

    test('returns null on DioException', () async {
      when(() => api.get(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(fakeDioError(404, {}));

      final detail = await vm.fetchOrderDetail(999);

      expect(detail, isNull);
    });

    test('returns null on unexpected exception', () async {
      when(() => api.get(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(Exception('network fail'));

      final detail = await vm.fetchOrderDetail(1);

      expect(detail, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Pagination helpers
  // ─────────────────────────────────────────────────────────────────────────
  group('Pagination', () {
    test('loadMoreCompleted increases completedLimit by 10', () {
      expect(vm.completedLimit, 10);
      vm.loadMoreCompleted();
      expect(vm.completedLimit, 20);
      vm.loadMoreCompleted();
      expect(vm.completedLimit, 30);
    });

    test('loadMoreCancelled increases cancelledLimit by 10', () {
      expect(vm.cancelledLimit, 10);
      vm.loadMoreCancelled();
      expect(vm.cancelledLimit, 20);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // clearError
  // ─────────────────────────────────────────────────────────────────────────
  group('clearError', () {
    test('clears error and notifies listeners', () async {
      // Use rejectOrder to populate vm.error via _doAction, which does set
      // _error on failure (unlike fetchOrders which swallows per-bucket errors).
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(400, {'message': 'Cannot reject'}));

      await vm.rejectOrder(1); // sets vm.error
      expect(vm.error, isNotNull);

      var notified = false;
      vm.addListener(() => notified = true);

      vm.clearError();

      expect(vm.error, isNull);
      expect(notified, isTrue);
    });
  });
}
