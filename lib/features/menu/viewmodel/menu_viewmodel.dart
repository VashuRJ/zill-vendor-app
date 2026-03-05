import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ── MenuItem ─────────────────────────────────────────────────────────
class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final double? discountedPrice;
  final double effectivePrice;
  final String imageUrl;
  final bool isVeg;
  final bool isVegan;
  final bool isGlutenFree;
  final String spiceLevel;
  final int? calories;
  final int? preparationTime; // minutes
  final int? serves; // number of people
  final bool isFeatured;
  final bool isBestseller;
  final bool isNew;
  final int? categoryId;
  final String categoryName;
  // Mutable — toggled by vendor
  bool isAvailable;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.discountedPrice,
    required this.effectivePrice,
    required this.imageUrl,
    required this.isVeg,
    required this.isVegan,
    required this.isGlutenFree,
    required this.spiceLevel,
    this.calories,
    this.preparationTime,
    this.serves,
    required this.isFeatured,
    required this.isBestseller,
    required this.isNew,
    this.categoryId,
    required this.categoryName,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      discountedPrice: json['discounted_price'] != null
          ? double.tryParse(json['discounted_price'].toString())
          : null,
      effectivePrice:
          double.tryParse(
            (json['effective_price'] ?? json['price'] ?? '0').toString(),
          ) ??
          0.0,
      imageUrl: json['image_url'] as String? ?? '',
      isVeg: json['is_veg'] as bool? ?? false,
      isVegan: json['is_vegan'] as bool? ?? false,
      isGlutenFree: json['is_gluten_free'] as bool? ?? false,
      spiceLevel: json['spice_level'] as String? ?? 'none',
      calories: (json['calories'] as num?)?.toInt(),
      preparationTime: (json['preparation_time'] as num?)?.toInt(),
      serves: (json['serves'] as num?)?.toInt(),
      isFeatured: json['is_featured'] as bool? ?? false,
      isBestseller: json['is_bestseller'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? false,
      categoryId: (json['category'] as num?)?.toInt(),
      categoryName: json['category_name'] as String? ?? 'Other',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  /// Case-insensitive search match on name and description.
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q);
  }
}

// ── MenuCategory ──────────────────────────────────────────────────────
class MenuCategory {
  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final int displayOrder;
  final List<MenuItem> items;

  MenuCategory({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.displayOrder,
    required this.items,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return MenuCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MenuItem.fromJson)
          .toList(),
    );
  }
}

// ── ViewModel ────────────────────────────────────────────────────────
enum MenuStatus { initial, loading, loaded, error }

class MenuViewModel extends ChangeNotifier {
  final ApiService _api;

  MenuViewModel({required ApiService apiService}) : _api = apiService;

  MenuStatus _status = MenuStatus.initial;
  String? _error;
  List<MenuCategory> _categories = [];

  // Per-item operation trackers
  final Set<int> _toggling = {};
  final Set<int> _deleting = {};
  bool _saving = false;

  // Search / filter state
  String _searchQuery = '';
  bool _vegOnly = false;
  bool _nonVegOnly = false;
  bool _availableOnly = false;

  // Bulk selection state
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _bulkUpdating = false;

  // ── Getters ──────────────────────────────────────────────────────
  MenuStatus get status => _status;
  String? get error => _error;
  List<MenuCategory> get categories => _categories;
  String get searchQuery => _searchQuery;
  bool get vegOnly => _vegOnly;
  bool get nonVegOnly => _nonVegOnly;
  bool get availableOnly => _availableOnly;
  bool get isSearchActive => _searchQuery.isNotEmpty;

  bool isToggling(int id) => _toggling.contains(id);
  bool isDeleting(int id) => _deleting.contains(id);
  bool get isSaving => _saving;

  bool get selectionMode => _selectionMode;
  Set<int> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;
  bool isSelected(int id) => _selectedIds.contains(id);
  bool get bulkUpdating => _bulkUpdating;

  int get totalItemCount => _categories.fold(0, (s, c) => s + c.items.length);

  int get totalAvailableCount => _categories.fold(
    0,
    (s, c) => s + c.items.where((i) => i.isAvailable).length,
  );

  /// Alias used by the stats row on MenuScreen.
  int get availableItemsCount => totalAvailableCount;

  int get outOfStockItemsCount => _categories.fold(
    0,
    (s, c) => s + c.items.where((i) => !i.isAvailable).length,
  );

  // ── Search / filter API ──────────────────────────────────────────
  void setSearch(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void toggleVegOnly() {
    _vegOnly = !_vegOnly;
    if (_vegOnly) _nonVegOnly = false; // mutually exclusive
    notifyListeners();
  }

  void toggleNonVegOnly() {
    _nonVegOnly = !_nonVegOnly;
    if (_nonVegOnly) _vegOnly = false; // mutually exclusive
    notifyListeners();
  }

  void toggleAvailableOnly() {
    _availableOnly = !_availableOnly;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _vegOnly = false;
    _nonVegOnly = false;
    _availableOnly = false;
    notifyListeners();
  }

  // ── Filtered items per category (used in tabs) ───────────────────
  List<MenuItem> filteredItemsForCategory(int categoryId) {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => MenuCategory(
        id: 0,
        name: '',
        description: '',
        displayOrder: 0,
        items: [],
      ),
    );
    return _applyFilters(cat.items).toList();
  }

  // ── Flat cross-category search results ──────────────────────────
  List<MenuItem> get flatSearchResults =>
      _applyFilters(_categories.expand((c) => c.items)).toList();

  Iterable<MenuItem> _applyFilters(Iterable<MenuItem> items) =>
      items.where((item) {
        if (_searchQuery.isNotEmpty && !item.matchesSearch(_searchQuery)) {
          return false;
        }
        if (_vegOnly && !item.isVeg) return false;
        if (_nonVegOnly && item.isVeg) return false;
        if (_availableOnly && !item.isAvailable) return false;
        return true;
      });

  // ── Fetch ─────────────────────────────────────────────────────────
  Future<void> fetchMenu() async {
    _status = MenuStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiEndpoints.menuCategories);
      final data = response.data as Map<String, dynamic>;
      final rawList = data['categories'] as List<dynamic>? ?? [];

      _categories =
          rawList
              .whereType<Map<String, dynamic>>()
              .map(MenuCategory.fromJson)
              .toList()
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // ── Orphaned / uncategorized items ──────────────────────────
      // The backend returns items that have no active category under
      // the 'uncategorized_items' key so they are never silently dropped.
      final rawUncategorized = data['uncategorized_items'] as List<dynamic>?;
      if (rawUncategorized != null && rawUncategorized.isNotEmpty) {
        final uncatItems = rawUncategorized
            .whereType<Map<String, dynamic>>()
            .map(MenuItem.fromJson)
            .toList();
        _categories.add(
          MenuCategory(
            id: -1,
            name: 'Uncategorized',
            description: 'Items not assigned to a category',
            displayOrder: 9999,
            items: uncatItems,
          ),
        );
      }

      _status = MenuStatus.loaded;
      debugPrint(
        '✅ [Menu] ${_categories.length} categories, $totalItemCount items',
      );
    } on DioException catch (e) {
      _error = _parseError(e);
      _status = MenuStatus.error;
      debugPrint('❌ [Menu] fetchMenu: ${e.response?.statusCode} ${e.message}');
    } catch (e, st) {
      _error = 'Unexpected error. Please try again.';
      _status = MenuStatus.error;
      debugPrint('❌ [Menu] unexpected: $e\n$st');
    }

    notifyListeners();
  }

  // ── Toggle availability ──────────────────────────────────────────
  /// Optimistically flips [isAvailable] immediately; reverts on failure.
  Future<void> toggleAvailability(int itemId, {required bool newValue}) async {
    // Find the item across all categories
    MenuItem? target;
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (item.id == itemId) {
          target = item;
          break;
        }
      }
      if (target != null) break;
    }
    if (target == null) return;

    // Optimistic update
    target.isAvailable = newValue;
    _toggling.add(itemId);
    notifyListeners();

    try {
      await _api.put(
        ApiEndpoints.menuItemDetail(itemId),
        data: {'is_available': newValue.toString()},
      );
      debugPrint('✅ [Menu] item $itemId → is_available=$newValue');
    } on DioException catch (e) {
      // Revert
      target.isAvailable = !newValue;
      _error = _parseError(e);
      debugPrint('❌ [Menu] toggle failed: ${e.response?.statusCode}');
    } catch (e) {
      target.isAvailable = !newValue;
      _error = 'Could not update item. Please try again.';
    } finally {
      _toggling.remove(itemId);
      notifyListeners();
    }
  }

  // ── Delete item ──────────────────────────────────────────────────
  Future<bool> deleteItem(int itemId) async {
    _deleting.add(itemId);
    notifyListeners();
    try {
      await _api.delete(ApiEndpoints.menuItemDetail(itemId));
      for (final cat in _categories) {
        cat.items.removeWhere((item) => item.id == itemId);
      }
      debugPrint('✅ [Menu] deleted item $itemId');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [Menu] delete failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not delete item. Please try again.';
      return false;
    } finally {
      _deleting.remove(itemId);
      notifyListeners();
    }
  }

  // ── Add item ──────────────────────────────────────────────────────
  Future<bool> addItem(FormData formData) async {
    _saving = true;
    notifyListeners();
    try {
      await _api.uploadFile(ApiEndpoints.menuItems, formData: formData);
      await fetchMenu();
      debugPrint('✅ [Menu] new item added');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [Menu] addItem failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not add item. Please try again.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ── Update item ───────────────────────────────────────────────────
  Future<bool> updateItem(int id, FormData formData) async {
    _saving = true;
    notifyListeners();
    try {
      await _api.putMultipart(
        ApiEndpoints.menuItemDetail(id),
        formData: formData,
      );
      await fetchMenu();
      debugPrint('✅ [Menu] updated item $id');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [Menu] updateItem failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not update item. Please try again.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ── Bulk Selection ─────────────────────────────────────────────

  void toggleSelectionMode() {
    _selectionMode = !_selectionMode;
    if (!_selectionMode) _selectedIds.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    _selectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleItemSelection(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.clear();
    for (final cat in _categories) {
      for (final item in cat.items) {
        _selectedIds.add(item.id);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// Concurrently updates availability for all selected items.
  Future<int> bulkUpdateAvailability({required bool available}) async {
    if (_selectedIds.isEmpty) return 0;
    _bulkUpdating = true;
    notifyListeners();

    final ids = Set<int>.from(_selectedIds);
    int successCount = 0;

    // Optimistic local update
    for (final cat in _categories) {
      for (final item in cat.items) {
        if (ids.contains(item.id)) item.isAvailable = available;
      }
    }
    notifyListeners();

    // Fire concurrent PUT requests
    final futures = ids.map((id) async {
      try {
        await _api.put(
          ApiEndpoints.menuItemDetail(id),
          data: {'is_available': available.toString()},
        );
        successCount++;
      } on DioException catch (e) {
        debugPrint('❌ [Menu] bulk toggle $id failed: ${e.response?.statusCode}');
      }
    });
    await Future.wait(futures);

    // If any failed, re-fetch to get accurate state
    if (successCount < ids.length) {
      _error = '${ids.length - successCount} item(s) failed to update.';
      await fetchMenu();
    }

    debugPrint('✅ [Menu] bulk update: $successCount/${ids.length} → available=$available');

    _bulkUpdating = false;
    _selectedIds.clear();
    _selectionMode = false;
    notifyListeners();
    return successCount;
  }

  // ── Category CRUD ───────────────────────────────────────────────

  Future<bool> createCategory({
    required String name,
    String description = '',
  }) async {
    _saving = true;
    notifyListeners();
    try {
      await _api.post(
        ApiEndpoints.menuCategories,
        data: {'name': name, 'description': description},
      );
      await fetchMenu();
      debugPrint('✅ [Menu] category created: $name');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [Menu] createCategory failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not create category.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> updateCategory(int id, {
    required String name,
    String description = '',
  }) async {
    _saving = true;
    notifyListeners();
    try {
      await _api.put(
        ApiEndpoints.menuCategoryDetail(id),
        data: {'name': name, 'description': description},
      );
      await fetchMenu();
      debugPrint('✅ [Menu] category $id updated: $name');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [Menu] updateCategory failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not update category.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCategory(int id) async {
    _saving = true;
    notifyListeners();
    try {
      await _api.delete(ApiEndpoints.menuCategoryDetail(id));
      await fetchMenu();
      debugPrint('✅ [Menu] category $id deleted');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [Menu] deleteCategory failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not delete category.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Error parser ─────────────────────────────────────────────────
  String _parseError(DioException e) {
    if (e.response == null) return 'Cannot reach server.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['error'] is String) return data['error'] as String;
    }
    return 'Error (HTTP ${e.response!.statusCode})';
  }
}
