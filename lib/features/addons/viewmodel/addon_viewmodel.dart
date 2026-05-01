import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ── AddonItem Model ─────────────────────────────────────────────────
class AddonItem {
  final int? id;
  final String name;
  final double price;
  final bool isVeg;
  final bool isAvailable;
  final int displayOrder;

  const AddonItem({
    this.id,
    required this.name,
    required this.price,
    this.isVeg = true,
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  factory AddonItem.fromJson(Map<String, dynamic> json) {
    return AddonItem(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      price: double.tryParse((json['price'] ?? '0').toString()) ?? 0.0,
      isVeg: json['is_veg'] as bool? ?? true,
      isAvailable: json['is_available'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'price': price,
    'is_veg': isVeg,
    'is_available': isAvailable,
    'display_order': displayOrder,
  };
}

// ── AddonGroup Model ────────────────────────────────────────────────
class AddonGroup {
  final int id;
  final String name;
  final String description;
  final String selectionType; // 'single' or 'multiple'
  final bool isRequired;
  final int minSelections;
  final int maxSelections;
  final List<AddonItem> items;

  const AddonGroup({
    required this.id,
    required this.name,
    this.description = '',
    this.selectionType = 'multiple',
    this.isRequired = false,
    this.minSelections = 0,
    this.maxSelections = 5,
    this.items = const [],
  });

  factory AddonGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return AddonGroup(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      selectionType: json['selection_type'] as String? ?? 'multiple',
      isRequired: json['is_required'] as bool? ?? false,
      minSelections: (json['min_selections'] as num?)?.toInt() ?? 0,
      maxSelections: (json['max_selections'] as num?)?.toInt() ?? 5,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(AddonItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'selection_type': selectionType,
    'is_required': isRequired,
    'min_selections': minSelections,
    'max_selections': maxSelections,
    'items': items.map((i) => i.toJson()).toList(),
  };

  int get availableItemCount => items.where((i) => i.isAvailable).length;
}

// ── ViewModel ───────────────────────────────────────────────────────
enum AddonStatus { initial, loading, loaded, error }

class AddonViewModel extends ChangeNotifier {
  final ApiService _api;
  StreamSubscription<void>? _sessionClearedSub;

  AddonViewModel({required ApiService apiService}) : _api = apiService {
    _sessionClearedSub =
        ApiService.onSessionExpired.listen((_) => clearSession());
  }

  @override
  void dispose() {
    _sessionClearedSub?.cancel();
    super.dispose();
  }

  /// Flush addon groups so they don't leak from one vendor to the
  /// next after logout + login on the same device.
  void clearSession() {
    _status = AddonStatus.initial;
    _error = null;
    _groups = [];
    _saving = false;
    _deleting.clear();
    notifyListeners();
  }

  AddonStatus _status = AddonStatus.initial;
  String? _error;
  List<AddonGroup> _groups = [];
  bool _saving = false;
  final Set<int> _deleting = {};

  // ── Getters ────────────────────────────────────────────────────────
  AddonStatus get status => _status;
  String? get error => _error;
  List<AddonGroup> get groups => _groups;
  bool get isSaving => _saving;
  bool isDeleting(int id) => _deleting.contains(id);

  // ── Fetch all addon groups ─────────────────────────────────────────
  Future<void> fetchGroups() async {
    _status = AddonStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiEndpoints.addonGroups);
      final data = response.data;

      List<dynamic> rawList;
      if (data is Map<String, dynamic>) {
        rawList = data['results'] as List<dynamic>? ??
            data['addon_groups'] as List<dynamic>? ??
            <dynamic>[];
      } else if (data is List) {
        rawList = data;
      } else {
        rawList = [];
      }

      _groups = rawList
          .whereType<Map<String, dynamic>>()
          .map(AddonGroup.fromJson)
          .toList();

      _status = AddonStatus.loaded;
      debugPrint('✅ [Addons] ${_groups.length} addon groups loaded');
    } on DioException catch (e) {
      _error = _parseError(e);
      _status = AddonStatus.error;
    } catch (e, st) {
      _error = 'Unexpected error loading addon groups.';
      _status = AddonStatus.error;
      debugPrint('❌ [Addons] $e\n$st');
    }

    notifyListeners();
  }

  // ── Create addon group ─────────────────────────────────────────────
  Future<bool> createGroup(AddonGroup group) async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await _api.post(ApiEndpoints.addonGroups, data: group.toJson());
      await fetchGroups();
      debugPrint('✅ [Addons] group created: ${group.name}');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      return false;
    } catch (e) {
      _error = 'Could not create addon group.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ── Update addon group ─────────────────────────────────────────────
  Future<bool> updateGroup(int groupId, AddonGroup group) async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await _api.put(
        ApiEndpoints.addonGroupDetail(groupId),
        data: group.toJson(),
      );
      await fetchGroups();
      debugPrint('✅ [Addons] group $groupId updated');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      return false;
    } catch (e) {
      _error = 'Could not update addon group.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ── Delete addon group ─────────────────────────────────────────────
  Future<bool> deleteGroup(int groupId) async {
    _deleting.add(groupId);
    notifyListeners();

    try {
      await _api.delete(ApiEndpoints.addonGroupDetail(groupId));
      _groups.removeWhere((g) => g.id == groupId);
      debugPrint('✅ [Addons] group $groupId deleted');
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _deleting.remove(groupId);
      notifyListeners();
    }
  }

  // ── Link addon group to menu item ──────────────────────────────────
  Future<bool> linkToMenuItem(int itemId, int groupId) async {
    try {
      await _api.post(ApiEndpoints.menuItemAddonLink(itemId, groupId));
      debugPrint('✅ [Addons] linked group $groupId to item $itemId');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  // ── Unlink addon group from menu item ──────────────────────────────
  Future<bool> unlinkFromMenuItem(int itemId, int groupId) async {
    try {
      await _api.delete(ApiEndpoints.menuItemAddonLink(itemId, groupId));
      debugPrint('✅ [Addons] unlinked group $groupId from item $itemId');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  // ── Get addon groups linked to a specific menu item ────────────────
  Future<List<int>> getLinkedGroupIds(int itemId) async {
    try {
      final response = await _api.get(ApiEndpoints.menuItemAddons(itemId));
      final data = response.data;

      List<dynamic> rawList;
      if (data is Map<String, dynamic>) {
        rawList = data['addon_groups'] as List<dynamic>? ??
            data['results'] as List<dynamic>? ??
            <dynamic>[];
      } else if (data is List) {
        rawList = data;
      } else {
        rawList = [];
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((g) => (g['id'] as num?)?.toInt() ?? 0)
          .where((id) => id > 0)
          .toList();
    } catch (e) {
      debugPrint('❌ [Addons] getLinkedGroupIds failed: $e');
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(DioException e) {
    if (e.response == null) return 'Cannot reach server.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['error'] is String) return data['error'] as String;
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    return 'Error (HTTP ${e.response!.statusCode})';
  }
}
