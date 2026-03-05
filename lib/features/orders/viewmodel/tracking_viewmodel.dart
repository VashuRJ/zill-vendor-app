import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data Models — parsed from GET /api/vendors/orders/{id}/live-tracking/
// ─────────────────────────────────────────────────────────────────────────────

/// Delivery partner info (null when no partner assigned yet).
class TrackingPartner {
  final int id;
  final String name;
  final String phone;
  final String vehicleType;
  final String vehicleNumber;
  final double rating;
  final int totalDeliveries;
  final String? profilePhoto;
  final TrackingLocation? currentLocation;

  const TrackingPartner({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.rating,
    required this.totalDeliveries,
    this.profilePhoto,
    this.currentLocation,
  });

  factory TrackingPartner.fromJson(Map<String, dynamic> json) {
    final locJson = json['current_location'] as Map<String, dynamic>?;
    return TrackingPartner(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Delivery Partner',
      phone: json['phone'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? '',
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      rating: double.tryParse((json['rating'] ?? '0').toString()) ?? 0.0,
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 0,
      profilePhoto: json['profile_photo'] as String?,
      currentLocation:
          locJson != null ? TrackingLocation.fromJson(locJson) : null,
    );
  }

  /// User-friendly vehicle label.
  String get vehicleDisplay {
    switch (vehicleType.toLowerCase()) {
      case 'motorcycle':
      case 'scooter':
        return 'Bike';
      case 'bicycle':
        return 'Bicycle';
      case 'car':
        return 'Car';
      default:
        if (vehicleType.isEmpty) return '';
        return vehicleType[0].toUpperCase() + vehicleType.substring(1);
    }
  }
}

/// A lat/lng point with an optional update timestamp.
class TrackingLocation {
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;
  final String? name;
  final String? address;

  const TrackingLocation({
    this.latitude,
    this.longitude,
    this.updatedAt,
    this.name,
    this.address,
  });

  bool get isValid => latitude != null && longitude != null;

  factory TrackingLocation.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    try {
      final raw = json['updated_at'] as String?;
      if (raw != null && raw.isNotEmpty) parsed = DateTime.parse(raw);
    } catch (_) {}

    return TrackingLocation(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: parsed,
      name: json['name'] as String?,
      address: json['address'] as String?,
    );
  }
}

/// ETA information for pickup and delivery.
class TrackingETA {
  final int? pickupMinutes;
  final int? deliveryMinutes;
  final String pickupDisplay;
  final String deliveryDisplay;

  const TrackingETA({
    this.pickupMinutes,
    this.deliveryMinutes,
    this.pickupDisplay = 'Calculating...',
    this.deliveryDisplay = 'Calculating...',
  });

  factory TrackingETA.fromJson(Map<String, dynamic> json) {
    return TrackingETA(
      pickupMinutes: (json['pickup_eta_minutes'] as num?)?.toInt(),
      deliveryMinutes: (json['delivery_eta_minutes'] as num?)?.toInt(),
      pickupDisplay: json['pickup_display'] as String? ?? 'Calculating...',
      deliveryDisplay: json['delivery_display'] as String? ?? 'Calculating...',
    );
  }
}

/// Vendor-facing tracking status.
class TrackingStatus {
  final String status;
  final String statusDisplay;
  final bool isLiveTracking;
  final bool isWithPartner;

  const TrackingStatus({
    required this.status,
    required this.statusDisplay,
    this.isLiveTracking = false,
    this.isWithPartner = false,
  });

  factory TrackingStatus.fromJson(Map<String, dynamic> json) {
    return TrackingStatus(
      status: json['status'] as String? ?? 'awaiting_assignment',
      statusDisplay:
          json['status_display'] as String? ?? 'Awaiting Delivery Partner',
      isLiveTracking: json['is_live_tracking'] as bool? ?? false,
      isWithPartner: json['is_with_partner'] as bool? ?? false,
    );
  }

  // ── Convenience checks ──────────────────────────────────────────────
  bool get isAwaitingAssignment => status == 'awaiting_assignment';
  bool get isHeadingToRestaurant => status == 'heading_to_restaurant';
  bool get isAtRestaurant => status == 'at_restaurant';
  bool get isOutForDelivery => status == 'out_for_delivery';
  bool get isNearCustomer => status == 'near_customer';
  bool get isDelivered => status == 'delivered';
}

/// A single event in the order timeline.
class TrackingTimelineEvent {
  final String event;
  final String eventDisplay;
  final String icon;
  final DateTime? timestamp;
  final bool completed;
  final String? details;

  const TrackingTimelineEvent({
    required this.event,
    required this.eventDisplay,
    this.icon = '',
    this.timestamp,
    this.completed = false,
    this.details,
  });

  factory TrackingTimelineEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    try {
      final raw = json['timestamp'] as String?;
      if (raw != null && raw.isNotEmpty) parsed = DateTime.parse(raw);
    } catch (_) {}

    return TrackingTimelineEvent(
      event: json['event'] as String? ?? '',
      eventDisplay: json['event_display'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      timestamp: parsed,
      completed: json['completed'] as bool? ?? false,
      details: json['details'] as String?,
    );
  }
}

/// Basic order info returned inside the tracking response.
class TrackingOrderInfo {
  final int id;
  final String orderNumber;
  final String status;
  final String statusDisplay;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double grandTotal;
  final String paymentMethod;
  final DateTime? createdAt;

  const TrackingOrderInfo({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusDisplay,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.grandTotal,
    required this.paymentMethod,
    this.createdAt,
  });

  factory TrackingOrderInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    try {
      final raw = json['created_at'] as String?;
      if (raw != null && raw.isNotEmpty) parsed = DateTime.parse(raw);
    } catch (_) {}

    return TrackingOrderInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      status: (json['status'] as String? ?? 'unknown').toLowerCase().trim(),
      statusDisplay: json['status_display'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      grandTotal:
          double.tryParse((json['grand_total'] ?? '0').toString()) ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? '',
      createdAt: parsed,
    );
  }
}

/// All locations involved in the delivery.
class TrackingLocations {
  final TrackingLocation? restaurant;
  final TrackingLocation? customer;
  final TrackingLocation? deliveryPartner;

  const TrackingLocations({this.restaurant, this.customer, this.deliveryPartner});

  factory TrackingLocations.fromJson(Map<String, dynamic> json) {
    return TrackingLocations(
      restaurant: json['restaurant'] is Map<String, dynamic>
          ? TrackingLocation.fromJson(json['restaurant'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] is Map<String, dynamic>
          ? TrackingLocation.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      deliveryPartner: json['delivery_partner'] is Map<String, dynamic>
          ? TrackingLocation.fromJson(
              json['delivery_partner'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Aggregate model — full response from single order live tracking
// ─────────────────────────────────────────────────────────────────────────────

class LiveTrackingData {
  final TrackingOrderInfo orderInfo;
  final TrackingPartner? deliveryPartner;
  final TrackingStatus trackingStatus;
  final TrackingETA eta;
  final List<TrackingTimelineEvent> timeline;
  final TrackingLocations locations;
  final DateTime lastUpdated;

  const LiveTrackingData({
    required this.orderInfo,
    this.deliveryPartner,
    required this.trackingStatus,
    required this.eta,
    this.timeline = const [],
    this.locations = const TrackingLocations(),
    required this.lastUpdated,
  });

  factory LiveTrackingData.fromJson(Map<String, dynamic> json) {
    DateTime lastUpdated;
    try {
      lastUpdated = DateTime.parse(json['last_updated'] as String? ?? '');
    } catch (_) {
      lastUpdated = DateTime.now();
    }

    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];

    return LiveTrackingData(
      orderInfo: TrackingOrderInfo.fromJson(
        json['order_info'] as Map<String, dynamic>? ?? {},
      ),
      deliveryPartner: json['delivery_partner'] is Map<String, dynamic>
          ? TrackingPartner.fromJson(
              json['delivery_partner'] as Map<String, dynamic>)
          : null,
      trackingStatus: TrackingStatus.fromJson(
        json['tracking_status'] as Map<String, dynamic>? ?? {},
      ),
      eta: TrackingETA.fromJson(
        json['eta'] as Map<String, dynamic>? ?? {},
      ),
      timeline: timelineRaw
          .whereType<Map<String, dynamic>>()
          .map(TrackingTimelineEvent.fromJson)
          .toList(),
      locations: TrackingLocations.fromJson(
        json['locations'] as Map<String, dynamic>? ?? {},
      ),
      lastUpdated: lastUpdated,
    );
  }

  /// True if a delivery partner has been assigned.
  bool get hasPartner => deliveryPartner != null;

  /// True if the partner has a valid current GPS position.
  bool get hasPartnerLocation =>
      deliveryPartner?.currentLocation?.isValid ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ViewModel — auto-polling every 10s
// ─────────────────────────────────────────────────────────────────────────────

enum TrackingViewStatus { initial, loading, loaded, error }

class TrackingViewModel extends ChangeNotifier {
  final ApiService _apiService;

  TrackingViewStatus _status = TrackingViewStatus.initial;
  LiveTrackingData? _data;
  String? _errorMessage;

  Timer? _pollTimer;
  int? _activeOrderId;

  static const _pollInterval = Duration(seconds: 10);

  TrackingViewModel({required ApiService apiService})
      : _apiService = apiService;

  // ── Getters ──────────────────────────────────────────────────────────────
  TrackingViewStatus get status => _status;
  LiveTrackingData? get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == TrackingViewStatus.loading;
  bool get hasData => _data != null;
  bool get isTracking => _pollTimer?.isActive ?? false;

  // Convenience accessors for the UI layer
  TrackingPartner? get partner => _data?.deliveryPartner;
  TrackingStatus? get trackingStatus => _data?.trackingStatus;
  TrackingETA? get eta => _data?.eta;
  TrackingOrderInfo? get orderInfo => _data?.orderInfo;
  List<TrackingTimelineEvent> get timeline => _data?.timeline ?? const [];

  // ── Start tracking (fetch + begin polling) ───────────────────────────────
  Future<void> startTracking(int orderId) async {
    // If already tracking the same order, skip re-init
    if (_activeOrderId == orderId && _pollTimer?.isActive == true) return;

    _activeOrderId = orderId;
    _errorMessage = null;

    // Initial fetch with loading indicator
    _status = TrackingViewStatus.loading;
    notifyListeners();
    await _fetchTracking(orderId);

    // Start polling timer
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_activeOrderId != null) {
        _fetchTracking(_activeOrderId!);
      }
    });
  }

  // ── Stop tracking (cancel timer) ────────────────────────────────────────
  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeOrderId = null;
  }

  // ── Manual refresh (pull-to-refresh or retry button) ────────────────────
  Future<void> refresh() async {
    if (_activeOrderId == null) return;
    await _fetchTracking(_activeOrderId!);
  }

  // ── Core fetch ──────────────────────────────────────────────────────────
  Future<void> _fetchTracking(int orderId) async {
    try {
      final response = await _apiService.get(
        ApiEndpoints.orderLiveTracking(orderId),
      );

      final body = response.data;
      if (body is Map<String, dynamic>) {
        // Check for error responses
        if (body['error'] is String) {
          _errorMessage = body['error'] as String;
          _status = TrackingViewStatus.error;
          notifyListeners();
          return;
        }

        _data = LiveTrackingData.fromJson(body);
        _status = TrackingViewStatus.loaded;
        _errorMessage = null;

        // Auto-stop polling if order is delivered or cancelled
        final orderStatus = _data!.orderInfo.status;
        if (orderStatus == 'delivered' || orderStatus == 'cancelled') {
          stopTracking();
        }
      }
    } on DioException catch (e) {
      // Only set error status on initial load — silent fail on polls
      if (_data == null) {
        _errorMessage = _parseError(e);
        _status = TrackingViewStatus.error;
      } else {
        AppLogger.w('[Tracking] poll error (silent): ${e.message}');
      }
    } catch (e) {
      if (_data == null) {
        _errorMessage = 'Failed to load tracking data.';
        _status = TrackingViewStatus.error;
      } else {
        AppLogger.w('[Tracking] poll error (silent): $e');
      }
    }

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _parseError(DioException e) {
    if (e.response == null) {
      return e.type == DioExceptionType.connectionError
          ? 'Cannot reach server. Is Django running on port 8000?'
          : 'Network error. Please check your connection.';
    }
    final data = e.response!.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['error'] is String) return data['error'] as String;
      if (data['detail'] != null) return data['detail'].toString();
    }
    return 'Error ${e.response!.statusCode}. Could not load tracking.';
  }
}
