import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

enum ProfileStatus { initial, loading, loaded, error }

/// Describes the kind of error so the UI can show appropriate icons / text.
enum AppErrorType { noInternet, timeout, serverError, unauthorized, unknown }

class ProfileData {
  final String storeName;
  final String ownerName;
  final String email;
  final String phone;
  final String address;
  final String description;
  final String fssaiNumber;
  final String gstNumber;
  final String panNumber;
  final double rating;
  final int totalRatings;
  final int totalOrders;
  final int menuItemsCount;
  final bool isVerified;
  final bool isActive;
  final bool hasBankAccount;
  final String? logoUrl;
  final String? imageUrl;
  // Extra details from backend
  final String cuisineTypes;
  final int averagePrepTime; // minutes
  final String openingTime;
  final String closingTime;
  // Restaurant type & features
  final String restaurantType;
  final double costForTwo;
  final bool isPureVeg;
  final bool servesAlcohol;
  final bool hasDineIn;
  final bool hasTakeaway;
  final bool hasDelivery;
  final int seatingCapacity;
  final String website;
  final bool autoAcceptOrders;
  // Location coordinates
  final double? latitude;
  final double? longitude;

  const ProfileData({
    this.storeName = '',
    this.ownerName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.description = '',
    this.fssaiNumber = '',
    this.gstNumber = '',
    this.panNumber = '',
    this.rating = 0.0,
    this.totalRatings = 0,
    this.totalOrders = 0,
    this.menuItemsCount = 0,
    this.isVerified = false,
    this.isActive = false,
    this.hasBankAccount = false,
    this.logoUrl,
    this.imageUrl,
    this.cuisineTypes = '',
    this.averagePrepTime = 0,
    this.openingTime = '',
    this.closingTime = '',
    this.restaurantType = '',
    this.costForTwo = 0,
    this.isPureVeg = false,
    this.servesAlcohol = false,
    this.hasDineIn = false,
    this.hasTakeaway = true,
    this.hasDelivery = true,
    this.seatingCapacity = 0,
    this.website = '',
    this.autoAcceptOrders = false,
    this.latitude,
    this.longitude,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      storeName: json['name'] as String? ?? '',
      ownerName: (json['owner_name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? json['owner_email'] as String? ?? '')
          .trim(),
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      description: json['description'] as String? ?? '',
      fssaiNumber: json['fssai_license_number'] as String? ?? '',
      gstNumber: json['gst_number'] as String? ?? '',
      panNumber: json['pan_number'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      menuItemsCount: (json['menu_items_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
      hasBankAccount: json['has_bank_account'] as bool? ?? false,
      // Backend serializer returns logo_url / image_url (not logo / image)
      logoUrl: json['logo_url'] as String?,
      imageUrl: json['image_url'] as String?,
      cuisineTypes: _parseCuisineTypes(json['cuisine_types']),
      averagePrepTime: (json['average_prep_time'] as num?)?.toInt() ?? 0,
      openingTime: json['opening_time'] as String? ?? '',
      closingTime: json['closing_time'] as String? ?? '',
      restaurantType: json['restaurant_type'] as String? ?? '',
      costForTwo: (json['cost_for_two'] as num?)?.toDouble() ?? 0,
      isPureVeg: json['is_pure_veg'] as bool? ?? false,
      servesAlcohol: json['serves_alcohol'] as bool? ?? false,
      hasDineIn: json['has_dine_in'] as bool? ?? false,
      hasTakeaway: json['has_takeaway'] as bool? ?? true,
      hasDelivery: json['has_delivery'] as bool? ?? true,
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? 0,
      website: json['website'] as String? ?? '',
      autoAcceptOrders: json['auto_accept_orders'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  static String _parseCuisineTypes(dynamic raw) {
    if (raw is String) return raw;
    if (raw is List) return raw.map((e) => e.toString()).join(', ');
    return '';
  }
}

// ── Store Settings model ──────────────────────────────────────────────────────
class StoreSettingsData {
  final double deliveryFee;
  final double minimumOrderAmount;
  final double? freeDeliveryAbove;
  final double deliveryRadiusKm;

  const StoreSettingsData({
    this.deliveryFee = 0,
    this.minimumOrderAmount = 0,
    this.freeDeliveryAbove,
    this.deliveryRadiusKm = 5,
  });

  factory StoreSettingsData.fromJson(Map<String, dynamic> json) {
    return StoreSettingsData(
      deliveryFee:
          (json['base_delivery_fee'] as num? ??
                  json['delivery_fee'] as num? ??
                  0)
              .toDouble(),
      minimumOrderAmount:
          (json['minimum_order'] as num? ??
                  json['minimum_order_amount'] as num? ??
                  0)
              .toDouble(),
      freeDeliveryAbove: (json['free_delivery_above'] as num?)?.toDouble(),
      deliveryRadiusKm: (json['delivery_radius_km'] as num? ?? 5).toDouble(),
    );
  }
}

enum SettingsStatus { initial, loading, loaded, saving, error }

class ProfileViewModel extends ChangeNotifier {
  final ApiService _apiService;

  ProfileStatus _status = ProfileStatus.initial;
  ProfileData _data = const ProfileData();
  String? _errorMessage;
  AppErrorType _errorType = AppErrorType.unknown;
  bool _hasLoadedOnce = false;

  // ── Local profile image (picked but not yet uploaded) ───────────
  File? _localProfileImage;
  final ImagePicker _imagePicker = ImagePicker();

  // ── Upload version — increments after each successful upload ─────
  // Used as a URL cache-buster so Flutter's NetworkImage refetches
  int _uploadVersion = 0;
  int get uploadVersion => _uploadVersion;

  SettingsStatus _settingsStatus = SettingsStatus.initial;
  StoreSettingsData _settings = const StoreSettingsData();
  String? _settingsError;
  String? _settingsSuccessMsg;

  ProfileViewModel({required ApiService apiService}) : _apiService = apiService;

  // ── Profile getters ──────────────────────────────────────────────
  ProfileStatus get status => _status;
  ProfileData get data => _data;
  String? get errorMessage => _errorMessage;
  AppErrorType get errorType => _errorType;
  bool get isLoading => _status == ProfileStatus.loading;
  bool get hasData => _hasLoadedOnce;

  // ── Profile image getter ────────────────────────────────────────
  File? get localProfileImage => _localProfileImage;

  // ── Settings getters ─────────────────────────────────────────────
  SettingsStatus get settingsStatus => _settingsStatus;
  StoreSettingsData get settings => _settings;
  String? get settingsError => _settingsError;
  String? get settingsSuccessMsg => _settingsSuccessMsg;
  bool get isSettingsLoading => _settingsStatus == SettingsStatus.loading;
  bool get isSettingsSaving => _settingsStatus == SettingsStatus.saving;

  // ── Fetch profile  GET /api/vendors/profile/ ─────────────────────
  Future<void> fetchProfile() async {
    _status = ProfileStatus.loading;
    _errorMessage = null;
    _errorType = AppErrorType.unknown;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.profile);
      _data = ProfileData.fromJson(response.data as Map<String, dynamic>);
      _localProfileImage = null; // Clear local preview — fresh server data is here
      _status = ProfileStatus.loaded;
      _hasLoadedOnce = true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _errorType = _classifyError(e);
      _status = ProfileStatus.error;
      debugPrint('❌ ProfileViewModel error: ${e.response?.data}');
    } catch (e) {
      _errorMessage = 'Failed to load profile.';
      _errorType = AppErrorType.unknown;
      _status = ProfileStatus.error;
    }

    notifyListeners();
  }

  // ── Fetch store settings  GET /api/vendors/delivery-zones/ ────────
  Future<void> fetchStoreSettings() async {
    _settingsStatus = SettingsStatus.loading;
    _settingsError = null;
    _settingsSuccessMsg = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.deliveryZones);
      _settings = StoreSettingsData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _settingsStatus = SettingsStatus.loaded;
    } on DioException catch (e) {
      _settingsError = _parseError(e);
      _settingsStatus = SettingsStatus.error;
    } catch (_) {
      _settingsError = 'Failed to load store settings.';
      _settingsStatus = SettingsStatus.error;
    }

    notifyListeners();
  }

  // ── Save store settings  PUT /api/vendors/profile/ ───────────────
  Future<bool> updateStoreSettings({
    required double deliveryFee,
    required double minimumOrderAmount,
    double? freeDeliveryAbove,
    required double deliveryRadiusKm,
  }) async {
    _settingsStatus = SettingsStatus.saving;
    _settingsError = null;
    _settingsSuccessMsg = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'delivery_fee': deliveryFee,
        'minimum_order_amount': minimumOrderAmount,
        'delivery_radius_km': deliveryRadiusKm,
        'free_delivery_above':
            freeDeliveryAbove != null && freeDeliveryAbove > 0
            ? freeDeliveryAbove
            : null,
      };

      await _apiService.put(ApiEndpoints.profile, data: payload);
      // Re-fetch to get server-confirmed values
      await fetchStoreSettings();
      _settingsSuccessMsg = 'Store settings saved!';
      _settingsStatus = SettingsStatus.loaded;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _settingsError = _parseError(e);
      _settingsStatus = SettingsStatus.error;
      notifyListeners();
      return false;
    } catch (_) {
      _settingsError = 'Failed to save settings.';
      _settingsStatus = SettingsStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Update profile  PUT /api/vendors/profile/ ───────────────────
  Future<bool> updateProfile({
    required String name,
    String? ownerName,
    required String phone,
    required String email,
    required String address,
    String? description,
    String? cuisineTypes,
    int? averagePrepTime,
    String? openingTime,
    String? closingTime,
    String? restaurantType,
    double? costForTwo,
    bool? isPureVeg,
    bool? servesAlcohol,
    bool? hasDineIn,
    bool? hasTakeaway,
    bool? hasDelivery,
    int? seatingCapacity,
    String? website,
    bool? autoAcceptOrders,
    double? latitude,
    double? longitude,
  }) async {
    _status = ProfileStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
      };
      if (ownerName != null && ownerName.isNotEmpty) {
        payload['owner_name'] = ownerName;
      }
      if (description != null && description.isNotEmpty) {
        payload['description'] = description;
      }
      if (cuisineTypes != null && cuisineTypes.isNotEmpty) {
        payload['cuisine_types'] = cuisineTypes;
      }
      if (averagePrepTime != null && averagePrepTime > 0) {
        payload['average_prep_time'] = averagePrepTime;
      }
      if (openingTime != null && openingTime.isNotEmpty) {
        payload['opening_time'] = openingTime;
      }
      if (closingTime != null && closingTime.isNotEmpty) {
        payload['closing_time'] = closingTime;
      }
      if (restaurantType != null && restaurantType.isNotEmpty) {
        payload['restaurant_type'] = restaurantType;
      }
      if (costForTwo != null && costForTwo > 0) {
        payload['cost_for_two'] = costForTwo;
      }
      if (isPureVeg != null) payload['is_pure_veg'] = isPureVeg;
      if (servesAlcohol != null) payload['serves_alcohol'] = servesAlcohol;
      if (hasDineIn != null) payload['has_dine_in'] = hasDineIn;
      if (hasTakeaway != null) payload['has_takeaway'] = hasTakeaway;
      if (hasDelivery != null) payload['has_delivery'] = hasDelivery;
      if (seatingCapacity != null) {
        payload['seating_capacity'] = seatingCapacity;
      }
      if (website != null) payload['website'] = website;
      if (autoAcceptOrders != null) {
        payload['auto_accept_orders'] = autoAcceptOrders;
      }
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      await _apiService.put(ApiEndpoints.profile, data: payload);
      // Re-fetch to get server-confirmed values
      await fetchProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _status = ProfileStatus.error;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to update profile.';
      _status = ProfileStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Change password  POST /api/users/change-password/ ────────────
  Future<({bool success, String? error})> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _apiService.post(
        ApiEndpoints.changePassword,
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
      return (success: true, error: null);
    } on DioException catch (e) {
      return (success: false, error: _parseError(e));
    } catch (_) {
      return (success: false, error: 'Failed to change password.');
    }
  }

  // ── Pick profile image from gallery ─────────────────────────────
  Future<void> pickProfileImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      _localProfileImage = File(picked.path);
      notifyListeners();
    }
  }

  // ── Upload profile image to server ────────────────────────────
  bool _isUploadingImage = false;
  bool get isUploadingImage => _isUploadingImage;

  Future<bool> uploadProfileImage() async {
    if (_localProfileImage == null) return false;
    _isUploadingImage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(
          _localProfileImage!.path,
          filename: 'profile_logo.jpg',
        ),
      });
      await _apiService.putMultipart(ApiEndpoints.profile, formData: formData);
      // Keep _localProfileImage — user sees their picked photo immediately.
      // It gets cleared on the next fetchProfile() call (pull-to-refresh, tab switch).
      _uploadVersion++;
      _isUploadingImage = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _isUploadingImage = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to upload image.';
      _isUploadingImage = false;
      notifyListeners();
      return false;
    }
  }

  void clearSettingsMessages() {
    _settingsError = null;
    _settingsSuccessMsg = null;
    notifyListeners();
  }

  String _parseError(DioException e) {
    if (e.response == null) {
      return e.type == DioExceptionType.connectionError
          ? 'Cannot reach server.'
          : 'Network error. Check your connection.';
    }
    final data = e.response!.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] != null) return data['detail'].toString();
    }
    return 'Error ${e.response!.statusCode}. Could not load profile.';
  }

  /// Map a DioException to a UI-friendly error category.
  AppErrorType _classifyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown when e.error is SocketException:
        return AppErrorType.noInternet;
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppErrorType.timeout;
      default:
        break;
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return AppErrorType.unauthorized;
    }
    if (statusCode != null && statusCode >= 500) {
      return AppErrorType.serverError;
    }
    return AppErrorType.unknown;
  }
}
