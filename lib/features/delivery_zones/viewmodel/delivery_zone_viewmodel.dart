import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ── DeliveryZone Model ──────────────────────────────────────────────
class DeliveryZone {
  final int id;
  final String zoneName;
  final double minDistanceKm;
  final double maxDistanceKm;
  final double deliveryFee;
  final double minimumOrder;
  final int estimatedDeliveryTime; // minutes
  final bool isActive;

  const DeliveryZone({
    required this.id,
    required this.zoneName,
    required this.minDistanceKm,
    required this.maxDistanceKm,
    required this.deliveryFee,
    required this.minimumOrder,
    required this.estimatedDeliveryTime,
    required this.isActive,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: (json['id'] as num?)?.toInt() ?? 0,
      zoneName: json['zone_name'] as String? ?? '',
      minDistanceKm:
          double.tryParse((json['min_distance_km'] ?? '0').toString()) ?? 0.0,
      maxDistanceKm:
          double.tryParse((json['max_distance_km'] ?? '0').toString()) ?? 0.0,
      deliveryFee:
          double.tryParse((json['delivery_fee'] ?? '0').toString()) ?? 0.0,
      minimumOrder:
          double.tryParse((json['minimum_order'] ?? '0').toString()) ?? 0.0,
      estimatedDeliveryTime:
          (json['estimated_delivery_time'] as num?)?.toInt() ?? 30,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'zone_name': zoneName,
    'min_distance_km': minDistanceKm,
    'max_distance_km': maxDistanceKm,
    'delivery_fee': deliveryFee,
    'minimum_order': minimumOrder,
    'estimated_delivery_time': estimatedDeliveryTime,
    'is_active': isActive,
  };
}

// ── Restaurant-level delivery config ────────────────────────────────
class RestaurantDeliveryConfig {
  final double deliveryRadiusKm;
  final double baseDeliveryFee;
  final double minimumOrder;
  final double? freeDeliveryAbove;

  const RestaurantDeliveryConfig({
    this.deliveryRadiusKm = 5.0,
    this.baseDeliveryFee = 0.0,
    this.minimumOrder = 0.0,
    this.freeDeliveryAbove,
  });

  factory RestaurantDeliveryConfig.fromJson(Map<String, dynamic> json) {
    return RestaurantDeliveryConfig(
      deliveryRadiusKm:
          double.tryParse((json['delivery_radius_km'] ?? '5').toString()) ??
          5.0,
      baseDeliveryFee:
          double.tryParse((json['base_delivery_fee'] ?? '0').toString()) ?? 0.0,
      minimumOrder:
          double.tryParse((json['minimum_order'] ?? '0').toString()) ?? 0.0,
      freeDeliveryAbove: json['free_delivery_above'] != null
          ? double.tryParse(json['free_delivery_above'].toString())
          : null,
    );
  }
}

// ── ViewModel ───────────────────────────────────────────────────────
enum DeliveryZoneStatus { initial, loading, loaded, error }

class DeliveryZoneViewModel extends ChangeNotifier {
  final ApiService _api;

  DeliveryZoneViewModel({required ApiService apiService}) : _api = apiService;

  DeliveryZoneStatus _status = DeliveryZoneStatus.initial;
  String? _error;
  List<DeliveryZone> _zones = [];
  RestaurantDeliveryConfig _config = const RestaurantDeliveryConfig();
  bool _saving = false;
  final Set<int> _deleting = {};

  // ── Getters ────────────────────────────────────────────────────────
  DeliveryZoneStatus get status => _status;
  String? get error => _error;
  List<DeliveryZone> get zones => _zones;
  RestaurantDeliveryConfig get config => _config;
  bool get isSaving => _saving;
  bool isDeleting(int id) => _deleting.contains(id);
  int get activeCount => _zones.where((z) => z.isActive).length;

  // ── Fetch all zones ────────────────────────────────────────────────
  Future<void> fetchZones() async {
    _status = DeliveryZoneStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiEndpoints.deliveryZones);
      final data = response.data;

      if (data is Map<String, dynamic>) {
        // Parse zones list
        final rawZones = data['zones'] as List<dynamic>? ??
            data['results'] as List<dynamic>? ??
            <dynamic>[];
        _zones = rawZones
            .whereType<Map<String, dynamic>>()
            .map(DeliveryZone.fromJson)
            .toList()
          ..sort((a, b) => a.minDistanceKm.compareTo(b.minDistanceKm));

        // Parse restaurant-level config if present
        _config = RestaurantDeliveryConfig.fromJson(data);
      } else if (data is List) {
        _zones = data
            .whereType<Map<String, dynamic>>()
            .map(DeliveryZone.fromJson)
            .toList()
          ..sort((a, b) => a.minDistanceKm.compareTo(b.minDistanceKm));
      }

      _status = DeliveryZoneStatus.loaded;
      debugPrint('✅ [DeliveryZones] ${_zones.length} zones loaded');
    } on DioException catch (e) {
      _error = _parseError(e);
      _status = DeliveryZoneStatus.error;
    } catch (e, st) {
      _error = 'Unexpected error loading zones.';
      _status = DeliveryZoneStatus.error;
      debugPrint('❌ [DeliveryZones] $e\n$st');
    }

    notifyListeners();
  }

  // ── Create zone ────────────────────────────────────────────────────
  Future<bool> createZone(DeliveryZone zone) async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await _api.post(ApiEndpoints.deliveryZones, data: zone.toJson());
      await fetchZones();
      debugPrint('✅ [DeliveryZones] zone created: ${zone.zoneName}');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      debugPrint('❌ [DeliveryZones] create failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Could not create zone.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ── Update zone ────────────────────────────────────────────────────
  Future<bool> updateZone(int zoneId, DeliveryZone zone) async {
    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await _api.put(
        ApiEndpoints.deliveryZoneDetail(zoneId),
        data: zone.toJson(),
      );
      await fetchZones();
      debugPrint('✅ [DeliveryZones] zone $zoneId updated');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      return false;
    } catch (e) {
      _error = 'Could not update zone.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ── Delete zone ────────────────────────────────────────────────────
  Future<bool> deleteZone(int zoneId) async {
    _deleting.add(zoneId);
    notifyListeners();

    try {
      await _api.delete(ApiEndpoints.deliveryZoneDetail(zoneId));
      _zones.removeWhere((z) => z.id == zoneId);
      debugPrint('✅ [DeliveryZones] zone $zoneId deleted');
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Could not delete zone.';
      notifyListeners();
      return false;
    } finally {
      _deleting.remove(zoneId);
      notifyListeners();
    }
  }

  // ── Toggle zone active/inactive ────────────────────────────────────
  Future<bool> toggleZoneActive(int zoneId, {required bool isActive}) async {
    // Optimistic update
    final idx = _zones.indexWhere((z) => z.id == zoneId);
    if (idx == -1) return false;

    final oldZone = _zones[idx];
    _zones[idx] = DeliveryZone(
      id: oldZone.id,
      zoneName: oldZone.zoneName,
      minDistanceKm: oldZone.minDistanceKm,
      maxDistanceKm: oldZone.maxDistanceKm,
      deliveryFee: oldZone.deliveryFee,
      minimumOrder: oldZone.minimumOrder,
      estimatedDeliveryTime: oldZone.estimatedDeliveryTime,
      isActive: isActive,
    );
    notifyListeners();

    try {
      await _api.put(
        ApiEndpoints.deliveryZoneDetail(zoneId),
        data: {...oldZone.toJson(), 'is_active': isActive},
      );
      return true;
    } on DioException catch (e) {
      // Revert
      _zones[idx] = oldZone;
      _error = _parseError(e);
      notifyListeners();
      return false;
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
      // Field-level errors
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
      }
    }
    return 'Error (HTTP ${e.response!.statusCode})';
  }
}
