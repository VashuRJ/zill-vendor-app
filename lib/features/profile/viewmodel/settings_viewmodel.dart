import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

class VendorSettingsData {
  final bool notifyNewOrders;
  final bool notifyOrderCancellations;
  final bool notifyNewReviews;
  final bool notifyPaymentReceived;
  final bool playSoundAlerts;
  final bool notifyMarketing;
  final bool twoFactorEnabled;
  final bool loginAlerts;
  final String language;

  const VendorSettingsData({
    this.notifyNewOrders = true,
    this.notifyOrderCancellations = true,
    this.notifyNewReviews = true,
    this.notifyPaymentReceived = true,
    this.playSoundAlerts = true,
    this.notifyMarketing = false,
    this.twoFactorEnabled = false,
    this.loginAlerts = false,
    this.language = 'en',
  });

  factory VendorSettingsData.fromJson(Map<String, dynamic> json) {
    return VendorSettingsData(
      notifyNewOrders: json['notify_new_orders'] as bool? ?? true,
      notifyOrderCancellations:
          json['notify_order_cancellations'] as bool? ?? true,
      notifyNewReviews: json['notify_new_reviews'] as bool? ?? true,
      notifyPaymentReceived: json['notify_payment_received'] as bool? ?? true,
      playSoundAlerts: json['play_sound_alerts'] as bool? ?? true,
      notifyMarketing: json['notify_marketing'] as bool? ?? false,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      loginAlerts: json['login_alerts'] as bool? ?? false,
      language: json['language'] as String? ?? 'en',
    );
  }

  VendorSettingsData copyWithToggle(String key, dynamic value) {
    return VendorSettingsData(
      notifyNewOrders: key == 'notify_new_orders'
          ? value as bool
          : notifyNewOrders,
      notifyOrderCancellations: key == 'notify_order_cancellations'
          ? value as bool
          : notifyOrderCancellations,
      notifyNewReviews: key == 'notify_new_reviews'
          ? value as bool
          : notifyNewReviews,
      notifyPaymentReceived: key == 'notify_payment_received'
          ? value as bool
          : notifyPaymentReceived,
      playSoundAlerts: key == 'play_sound_alerts'
          ? value as bool
          : playSoundAlerts,
      notifyMarketing: key == 'notify_marketing'
          ? value as bool
          : notifyMarketing,
      twoFactorEnabled: key == 'two_factor_enabled'
          ? value as bool
          : twoFactorEnabled,
      loginAlerts: key == 'login_alerts' ? value as bool : loginAlerts,
      language: key == 'language' ? value as String : language,
    );
  }
}

enum SettingsLoadStatus { initial, loading, loaded, error }

class SettingsViewModel extends ChangeNotifier {
  final ApiService _apiService;

  SettingsLoadStatus _status = SettingsLoadStatus.initial;
  VendorSettingsData _data = const VendorSettingsData();
  String? _errorMessage;

  SettingsViewModel({required ApiService apiService})
    : _apiService = apiService;

  SettingsLoadStatus get status => _status;
  VendorSettingsData get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == SettingsLoadStatus.loading;
  bool get hasData => _status == SettingsLoadStatus.loaded;
  bool get hasError => _status == SettingsLoadStatus.error;

  Future<void> fetchSettings() async {
    _status = SettingsLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.settings);
      final jsonData = response.data as Map<String, dynamic>;
      // The web API wraps in { settings: { ... } }
      final settingsJson =
          jsonData['settings'] as Map<String, dynamic>? ?? jsonData;
      _data = VendorSettingsData.fromJson(settingsJson);
      _status = SettingsLoadStatus.loaded;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _status = SettingsLoadStatus.error;
    } catch (e) {
      _errorMessage = 'Failed to load settings.';
      _status = SettingsLoadStatus.error;
    }

    notifyListeners();
  }

  /// Optimistically update a single setting toggle/value
  Future<void> updateSetting(String key, dynamic value) async {
    final previousData = _data;

    // Optimistic UI update
    _data = _data.copyWithToggle(key, value);
    notifyListeners();

    try {
      await _apiService.put(ApiEndpoints.settings, data: {key: value});
    } on DioException catch (e) {
      // Revert on failure
      _data = previousData;
      _errorMessage = _parseError(e);
      notifyListeners();
      debugPrint('❌ SettingsViewModel.updateSetting error: $e');
    } catch (_) {
      _data = previousData;
      notifyListeners();
    }
  }

  /// Deactivate restaurant
  Future<bool> deactivateRestaurant() async {
    try {
      await _apiService.post(
        ApiEndpoints.restaurantToggle,
        data: {
          'is_temporarily_closed': true,
          'reason': 'Deactivated from settings',
        },
      );
      return true;
    } catch (e) {
      debugPrint('❌ deactivateRestaurant error: $e');
      return false;
    }
  }

  String _parseError(DioException e) {
    if (e.response == null) {
      return e.type == DioExceptionType.connectionError
          ? 'Cannot reach server.'
          : 'Network error.';
    }
    final data = e.response!.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] != null) return data['detail'].toString();
    }
    return 'Error ${e.response!.statusCode}.';
  }
}
