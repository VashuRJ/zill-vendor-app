import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vendor_app/core/services/api_service.dart';
import 'package:vendor_app/features/menu/viewmodel/menu_viewmodel.dart';

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

// Builds a minimal menu item JSON
Map<String, dynamic> fakeItemJson({
  int id = 1,
  String name = 'Test Item',
  bool isVeg = true,
  bool isAvailable = true,
  int? categoryId,
}) =>
    {
      'id': id,
      'name': name,
      'description': 'A test menu item',
      'price': '150.00',
      'effective_price': '150.00',
      'image_url': '',
      'is_veg': isVeg,
      'is_vegan': false,
      'is_gluten_free': false,
      'spice_level': 'mild',
      'is_featured': false,
      'is_bestseller': false,
      'is_new': false,
      'category': categoryId,
      'category_name': 'Test Category',
      'is_available': isAvailable,
    };

// Builds a full menu response with categories
Map<String, dynamic> fakeMenuResponse({
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> uncategorizedItems = const [],
}) =>
    {
      'categories': categories,
      if (uncategorizedItems.isNotEmpty)
        'uncategorized_items': uncategorizedItems,
    };

// A single category with items
Map<String, dynamic> fakeCategoryJson({
  int id = 1,
  String name = 'Main Course',
  int displayOrder = 1,
  List<Map<String, dynamic>> items = const [],
}) =>
    {
      'id': id,
      'name': name,
      'description': '',
      'display_order': displayOrder,
      'items': items,
    };

void main() {
  late MockApiService api;
  late MenuViewModel vm;

  setUp(() {
    api = MockApiService();
    vm = MenuViewModel(apiService: api);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Initial state
  // ─────────────────────────────────────────────────────────────────────────
  group('Initial state', () {
    test('status is initial', () {
      expect(vm.status, MenuStatus.initial);
    });

    test('categories list is empty', () {
      expect(vm.categories, isEmpty);
    });

    test('no active filters', () {
      expect(vm.searchQuery, '');
      expect(vm.vegOnly, isFalse);
      expect(vm.nonVegOnly, isFalse);
      expect(vm.availableOnly, isFalse);
    });

    test('totals are zero', () {
      expect(vm.totalItemCount, 0);
      expect(vm.totalAvailableCount, 0);
      expect(vm.outOfStockItemsCount, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // fetchMenu
  // ─────────────────────────────────────────────────────────────────────────
  group('fetchMenu', () {
    test('sets status to loaded after successful fetch', () async {
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => fakeResponse(fakeMenuResponse()));

      await vm.fetchMenu();

      expect(vm.status, MenuStatus.loaded);
      expect(vm.error, isNull);
    });

    test('goes through loading → loaded state sequence', () async {
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => fakeResponse(fakeMenuResponse()));

      final states = <MenuStatus>[];
      vm.addListener(() => states.add(vm.status));

      await vm.fetchMenu();

      expect(states, containsAllInOrder([MenuStatus.loading, MenuStatus.loaded]));
    });

    test('populates categories from API response', () async {
      final categories = [
        fakeCategoryJson(id: 1, name: 'Starters', displayOrder: 1, items: [
          fakeItemJson(id: 11, name: 'Samosa'),
        ]),
        fakeCategoryJson(id: 2, name: 'Main Course', displayOrder: 2, items: [
          fakeItemJson(id: 21, name: 'Paneer Tikka'),
          fakeItemJson(id: 22, name: 'Butter Chicken', isVeg: false),
        ]),
      ];

      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));

      await vm.fetchMenu();

      expect(vm.categories.length, 2);
      expect(vm.totalItemCount, 3);
    });

    test('sorts categories by displayOrder ascending', () async {
      final categories = [
        fakeCategoryJson(id: 2, name: 'Desserts', displayOrder: 3),
        fakeCategoryJson(id: 1, name: 'Starters', displayOrder: 1),
        fakeCategoryJson(id: 3, name: 'Main', displayOrder: 2),
      ];

      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));

      await vm.fetchMenu();

      expect(vm.categories[0].name, 'Starters');
      expect(vm.categories[1].name, 'Main');
      expect(vm.categories[2].name, 'Desserts');
    });

    test('appends Uncategorized category for orphaned items', () async {
      final uncategorized = [fakeItemJson(id: 99, name: 'Orphan Item')];

      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(
              fakeMenuResponse(uncategorizedItems: uncategorized)));

      await vm.fetchMenu();

      expect(vm.categories.last.name, 'Uncategorized');
      expect(vm.categories.last.id, -1);
      expect(vm.categories.last.items.first.name, 'Orphan Item');
    });

    test('sets status to error on DioException', () async {
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(fakeDioError(500, {'message': 'Server error'}));

      await vm.fetchMenu();

      expect(vm.status, MenuStatus.error);
      expect(vm.error, isNotNull);
    });

    test('computes totalAvailableCount correctly', () async {
      final categories = [
        fakeCategoryJson(items: [
          fakeItemJson(id: 1, isAvailable: true),
          fakeItemJson(id: 2, isAvailable: false),
          fakeItemJson(id: 3, isAvailable: true),
        ]),
      ];
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));

      await vm.fetchMenu();

      expect(vm.totalItemCount, 3);
      expect(vm.totalAvailableCount, 2);
      expect(vm.outOfStockItemsCount, 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // toggleAvailability
  // ─────────────────────────────────────────────────────────────────────────
  group('toggleAvailability', () {
    setUp(() async {
      final categories = [
        fakeCategoryJson(items: [
          fakeItemJson(id: 10, isAvailable: true),
        ]),
      ];
      when(
              () => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));
      await vm.fetchMenu();
    });

    test('optimistically sets isAvailable before API call', () async {
      bool? availDuringCall;

      when(() => api.put(any(), data: any(named: 'data'))).thenAnswer((_) async {
        availDuringCall = vm.categories.first.items.first.isAvailable;
        return fakeResponse({});
      });

      await vm.toggleAvailability(10, newValue: false);

      // During the API call, the optimistic value should already be false
      expect(availDuringCall, isFalse);
      // After success, stays false
      expect(vm.categories.first.items.first.isAvailable, isFalse);
    });

    test('reverts isAvailable on API failure', () async {
      when(() => api.put(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(500, {}));

      await vm.toggleAvailability(10, newValue: false);

      // Should be reverted back to true (original value)
      expect(vm.categories.first.items.first.isAvailable, isTrue);
      expect(vm.error, isNotNull);
    });

    test('tracks toggling state for item id', () async {
      final togglingDuring = <bool>[];

      when(() => api.put(any(), data: any(named: 'data'))).thenAnswer((_) async {
        togglingDuring.add(vm.isToggling(10));
        return fakeResponse({});
      });

      await vm.toggleAvailability(10, newValue: false);

      expect(togglingDuring, contains(true));
      expect(vm.isToggling(10), isFalse); // cleared after
    });

    test('does nothing when item id does not exist', () async {
      // No API call should be made for a non-existent item
      await vm.toggleAvailability(999, newValue: false);

      verifyNever(() => api.put(any(), data: any(named: 'data')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // deleteItem
  // ─────────────────────────────────────────────────────────────────────────
  group('deleteItem', () {
    setUp(() async {
      final categories = [
        fakeCategoryJson(items: [
          fakeItemJson(id: 20, name: 'Samosa'),
          fakeItemJson(id: 21, name: 'Pakora'),
        ]),
      ];
      when(
              () => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));
      await vm.fetchMenu();
    });

    test('returns true and removes item from category on success', () async {
      when(() => api.delete(any())).thenAnswer((_) async => fakeResponse(null));

      final result = await vm.deleteItem(20);

      expect(result, isTrue);
      expect(
          vm.categories.first.items.any((i) => i.id == 20), isFalse);
      expect(vm.categories.first.items.any((i) => i.id == 21), isTrue);
    });

    test('returns false on DioException', () async {
      when(() => api.delete(any()))
          .thenThrow(fakeDioError(404, {'message': 'Not found'}));

      final result = await vm.deleteItem(20);

      expect(result, isFalse);
      expect(vm.error, isNotNull);
    });

    test('tracks deleting state for item id', () async {
      final deletingDuring = <bool>[];

      when(() => api.delete(any())).thenAnswer((_) async {
        deletingDuring.add(vm.isDeleting(20));
        return fakeResponse(null);
      });

      await vm.deleteItem(20);

      expect(deletingDuring, contains(true));
      expect(vm.isDeleting(20), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Search & Filter
  // ─────────────────────────────────────────────────────────────────────────
  group('Search and filters', () {
    setUp(() async {
      final categories = [
        fakeCategoryJson(id: 1, items: [
          fakeItemJson(id: 1, name: 'Paneer Tikka', isVeg: true, isAvailable: true),
          fakeItemJson(id: 2, name: 'Chicken Wings', isVeg: false, isAvailable: true),
          fakeItemJson(id: 3, name: 'Veg Burger', isVeg: true, isAvailable: false),
        ]),
      ];
      when(
              () => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));
      await vm.fetchMenu();
    });

    test('setSearch filters flatSearchResults by name', () {
      vm.setSearch('paneer');

      expect(vm.flatSearchResults.length, 1);
      expect(vm.flatSearchResults.first.name, 'Paneer Tikka');
    });

    test('setSearch is case-insensitive', () {
      vm.setSearch('CHICKEN');

      expect(vm.flatSearchResults.length, 1);
      expect(vm.flatSearchResults.first.name, 'Chicken Wings');
    });

    test('empty search returns all items', () {
      vm.setSearch('');
      expect(vm.flatSearchResults.length, 3);
    });

    test('setSearch notifies listeners only when query changes', () {
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);

      vm.setSearch('paneer');
      vm.setSearch('paneer'); // same value → no notification
      vm.setSearch('chicken'); // different → notification

      expect(notifyCount, 2);
    });

    test('isSearchActive is true when searchQuery is non-empty', () {
      expect(vm.isSearchActive, isFalse);
      vm.setSearch('pizza');
      expect(vm.isSearchActive, isTrue);
    });

    test('vegOnly filter shows only veg items', () {
      vm.toggleVegOnly();

      expect(vm.vegOnly, isTrue);
      expect(vm.flatSearchResults.every((i) => i.isVeg), isTrue);
      expect(vm.flatSearchResults.length, 2);
    });

    test('nonVegOnly filter shows only non-veg items', () {
      vm.toggleNonVegOnly();

      expect(vm.nonVegOnly, isTrue);
      expect(vm.flatSearchResults.every((i) => !i.isVeg), isTrue);
      expect(vm.flatSearchResults.length, 1);
    });

    test('vegOnly and nonVegOnly are mutually exclusive', () {
      vm.toggleVegOnly();
      expect(vm.vegOnly, isTrue);

      vm.toggleNonVegOnly(); // should unset vegOnly
      expect(vm.nonVegOnly, isTrue);
      expect(vm.vegOnly, isFalse);
    });

    test('availableOnly filter shows only available items', () {
      vm.toggleAvailableOnly();

      expect(vm.availableOnly, isTrue);
      expect(vm.flatSearchResults.every((i) => i.isAvailable), isTrue);
      expect(vm.flatSearchResults.length, 2);
    });

    test('clearFilters resets all filter state', () {
      vm.setSearch('paneer');
      vm.toggleVegOnly();
      vm.toggleAvailableOnly();

      vm.clearFilters();

      expect(vm.searchQuery, '');
      expect(vm.vegOnly, isFalse);
      expect(vm.availableOnly, isFalse);
      expect(vm.flatSearchResults.length, 3);
    });

    test('filteredItemsForCategory applies filters per category', () {
      vm.toggleVegOnly();

      final items = vm.filteredItemsForCategory(1);

      expect(items.every((i) => i.isVeg), isTrue);
    });

    test('filteredItemsForCategory returns empty for unknown category id', () {
      final items = vm.filteredItemsForCategory(999);
      expect(items, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bulk selection
  // ─────────────────────────────────────────────────────────────────────────
  group('Bulk selection', () {
    setUp(() async {
      final categories = [
        fakeCategoryJson(items: [
          fakeItemJson(id: 1),
          fakeItemJson(id: 2),
          fakeItemJson(id: 3),
        ]),
      ];
      when(
              () => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer(
            (_) async => fakeResponse(fakeMenuResponse(categories: categories)));
      await vm.fetchMenu();
    });

    test('toggleSelectionMode enters selection mode', () {
      expect(vm.selectionMode, isFalse);
      vm.toggleSelectionMode();
      expect(vm.selectionMode, isTrue);
    });

    test('toggleSelectionMode off clears selected ids', () {
      vm.toggleSelectionMode(); // enter
      vm.toggleItemSelection(1);
      vm.toggleItemSelection(2);

      vm.toggleSelectionMode(); // exit

      expect(vm.selectionMode, isFalse);
      expect(vm.selectedIds, isEmpty);
    });

    test('toggleItemSelection adds and removes item ids', () {
      vm.toggleItemSelection(1);
      expect(vm.selectedIds, contains(1));

      vm.toggleItemSelection(1); // toggle off
      expect(vm.selectedIds, isNot(contains(1)));
    });

    test('selectAll selects all items across categories', () {
      vm.selectAll();
      expect(vm.selectedCount, 3);
      expect(vm.selectedIds, containsAll([1, 2, 3]));
    });

    test('clearSelection empties selectedIds', () {
      vm.selectAll();
      vm.clearSelection();
      expect(vm.selectedIds, isEmpty);
    });

    test('isSelected returns correct state', () {
      vm.toggleItemSelection(2);
      expect(vm.isSelected(2), isTrue);
      expect(vm.isSelected(1), isFalse);
    });

    test('exitSelectionMode clears selection and mode', () {
      vm.toggleSelectionMode();
      vm.toggleItemSelection(1);
      vm.exitSelectionMode();

      expect(vm.selectionMode, isFalse);
      expect(vm.selectedIds, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Category CRUD
  // ─────────────────────────────────────────────────────────────────────────
  group('createCategory', () {
    test('returns true and refreshes menu on success', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => fakeResponse({'id': 10, 'name': 'Desserts'}));
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => fakeResponse(fakeMenuResponse()));

      final result =
          await vm.createCategory(name: 'Desserts', description: 'Sweet items');

      expect(result, isTrue);
    });

    test('returns false on DioException', () async {
      when(() => api.post(any(), data: any(named: 'data')))
          .thenThrow(fakeDioError(400, {'message': 'Name already exists'}));

      final result = await vm.createCategory(name: 'Duplicate');

      expect(result, isFalse);
      expect(vm.error, isNotNull);
    });
  });

  group('deleteCategory', () {
    test('returns true and refreshes menu on success', () async {
      when(() => api.delete(any()))
          .thenAnswer((_) async => fakeResponse(null));
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => fakeResponse(fakeMenuResponse()));

      final result = await vm.deleteCategory(5);

      expect(result, isTrue);
    });

    test('returns false on DioException', () async {
      when(() => api.delete(any()))
          .thenThrow(fakeDioError(404, {'message': 'Not found'}));

      final result = await vm.deleteCategory(999);

      expect(result, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // clearError
  // ─────────────────────────────────────────────────────────────────────────
  group('clearError', () {
    test('clears error and notifies listeners', () async {
      when(() => api.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenThrow(fakeDioError(500, {'message': 'Fail'}));
      await vm.fetchMenu();

      var notified = false;
      vm.addListener(() => notified = true);

      vm.clearError();

      expect(vm.error, isNull);
      expect(notified, isTrue);
    });
  });
}
