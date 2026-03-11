import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────

class Promotion {
  final int id;
  final String code;
  final String description;
  final String discountType; // 'percentage' | 'flat'
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final DateTime validFrom;
  final DateTime validUntil;
  final int usageCount;
  final int? usageLimit;
  final String status; // 'active' | 'inactive' | 'expired'
  final bool isActive;

  const Promotion({
    required this.id,
    required this.code,
    required this.description,
    this.discountType = 'percentage',
    required this.discountValue,
    this.maxDiscount,
    required this.minOrderAmount,
    required this.validFrom,
    required this.validUntil,
    this.usageCount = 0,
    this.usageLimit,
    this.status = 'active',
    this.isActive = true,
  });

  bool get isExpired => status == 'expired' || validUntil.isBefore(DateTime.now());

  int get daysLeft {
    final diff = validUntil.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get usagePercent =>
      (usageLimit != null && usageLimit! > 0)
          ? (usageCount / usageLimit!).clamp(0.0, 1.0)
          : 0;

  /// The display-friendly discount string (e.g. "50%" or "₹120")
  double get discountPercentage =>
      discountType == 'percentage' ? discountValue : 0;

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: (json['code'] as String?) ?? '',
      description: (json['description'] ?? json['name'] ?? '') as String,
      discountType: (json['discount_type'] as String?) ?? 'percentage',
      discountValue: _toDouble(json['discount_value']),
      maxDiscount: json['max_discount'] != null
          ? _toDouble(json['max_discount'])
          : null,
      minOrderAmount: _toDouble(json['min_order_amount']),
      validFrom: _parseDate(json['valid_from']),
      validUntil: _parseDate(json['valid_until']),
      usageCount: (json['usage_count'] as int?) ?? 0,
      usageLimit: json['usage_limit'] as int?,
      status: (json['status'] as String?) ?? 'active',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Status
// ─────────────────────────────────────────────────────────────────────────────

enum PromotionsStatus { idle, fetching, error }

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel
// ─────────────────────────────────────────────────────────────────────────────

class PromotionsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  PromotionsViewModel({required ApiService apiService})
      : _apiService = apiService;

  // ── State ────────────────────────────────────────────────────────────────
  PromotionsStatus _status = PromotionsStatus.idle;
  List<Promotion> _promotions = [];
  String? _errorMessage;
  bool _isBusy = false; // single-action lock (toggle/delete/create)

  // ── Getters ──────────────────────────────────────────────────────────────
  PromotionsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasData => _promotions.isNotEmpty;
  bool get isBusy => _isBusy;

  List<Promotion> get active =>
      _promotions.where((p) => p.status == 'active' && !p.isExpired).toList();

  List<Promotion> get expired =>
      _promotions.where((p) => p.status != 'active' || p.isExpired).toList();

  int get activeCount => active.length;
  int get totalUses =>
      _promotions.fold<int>(0, (sum, p) => sum + p.usageCount);

  // ── Fetch ────────────────────────────────────────────────────────────────
  Future<void> fetchPromotions() async {
    _status = PromotionsStatus.fetching;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await _apiService.get(ApiEndpoints.coupons);
      final data = resp.data;
      final List<dynamic> rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        rawList = (data['results'] as List<dynamic>?) ?? [];
      } else {
        rawList = [];
      }
      _promotions =
          rawList.map((e) => Promotion.fromJson(e as Map<String, dynamic>)).toList();
      _status = PromotionsStatus.idle;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _status = PromotionsStatus.error;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      _status = PromotionsStatus.error;
      debugPrint('[PromotionsVM] fetchPromotions: $e');
    }
    notifyListeners();
  }

  // ── Toggle ───────────────────────────────────────────────────────────────
  Future<bool> togglePromo(int id) async {
    final idx = _promotions.indexWhere((p) => p.id == id);
    if (idx == -1) return false;
    final promo = _promotions[idx];
    final newActive = promo.status != 'active';

    _isBusy = true;
    notifyListeners();

    try {
      await _apiService.put(
        ApiEndpoints.couponDetail(id),
        data: {'is_active': newActive},
      );
      await fetchPromotions(); // re-fetch to get server-computed status
      _isBusy = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to toggle promotion.';
      _isBusy = false;
      notifyListeners();
      debugPrint('[PromotionsVM] togglePromo: $e');
      return false;
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────
  Future<bool> deletePromo(int id) async {
    _isBusy = true;
    notifyListeners();

    try {
      await _apiService.delete(ApiEndpoints.couponDetail(id));
      _promotions.removeWhere((p) => p.id == id);
      _isBusy = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete promotion.';
      _isBusy = false;
      notifyListeners();
      debugPrint('[PromotionsVM] deletePromo: $e');
      return false;
    }
  }

  // ── Create ───────────────────────────────────────────────────────────────
  Future<bool> addPromo({
    required String code,
    required String description,
    String discountType = 'percentage',
    required double discountValue,
    double? maxDiscount,
    required double minOrderAmount,
    required DateTime validFrom,
    required DateTime validUntil,
    int? usageLimit,
  }) async {
    _isBusy = true;
    notifyListeners();

    final data = <String, dynamic>{
      'code': code.toUpperCase(),
      'description': description,
      'discount_type': discountType,
      'discount_value': discountValue,
      'max_discount': maxDiscount,
      'min_order_amount': minOrderAmount,
      'valid_from': validFrom.toIso8601String().split('T').first,
      'valid_until': validUntil.toIso8601String().split('T').first,
      'usage_limit': usageLimit,
    };

    try {
      await _apiService.post(ApiEndpoints.coupons, data: data);
      await fetchPromotions(); // re-fetch full list
      _isBusy = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to create promotion.';
      _isBusy = false;
      notifyListeners();
      debugPrint('[PromotionsVM] addPromo: $e');
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _parseDioError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      // Try to get Django's first field error
      for (final key in data.keys) {
        final val = data[key];
        if (val is List && val.isNotEmpty) return val.first.toString();
        if (val is String) return val;
      }
      if (data.containsKey('error')) return data['error'].toString();
      if (data.containsKey('detail')) return data['detail'].toString();
    }
    if (e.response?.statusCode == 401) return 'Session expired. Please login again.';
    if (e.response?.statusCode == 403) return 'Access denied.';
    if (e.response?.statusCode == 404) return 'Not found.';
    if ((e.response?.statusCode ?? 0) >= 500) return 'Server error. Try again later.';
    return e.message ?? 'Network error. Please check your connection.';
  }
}
