import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

/// Data class for order info passed through the alarm system.
class AlarmOrderData {
  final int orderId;
  final String orderNumber;
  final String orderAmount;
  final String orderItems;
  final String customerName;

  const AlarmOrderData({
    required this.orderId,
    required this.orderNumber,
    this.orderAmount = '',
    this.orderItems = '',
    this.customerName = '',
  });

  factory AlarmOrderData.fromMap(Map<dynamic, dynamic> map) {
    return AlarmOrderData(
      orderId: int.tryParse(map['order_id']?.toString() ?? '0') ?? 0,
      orderNumber: map['order_number']?.toString() ?? '',
      orderAmount: map['order_amount']?.toString() ?? '',
      orderItems: map['order_items']?.toString() ?? '',
      customerName: map['order_customer']?.toString() ?? '',
    );
  }

  Map<String, String> toMap() => {
    'order_id': orderId.toString(),
    'order_number': orderNumber,
    'order_amount': orderAmount,
    'order_items': orderItems,
    'order_customer': customerName,
  };
}

/// Flutter bridge to the native Android [OrderAlarmService].
///
/// Controls the loud alarm foreground service via MethodChannel.
/// - [startAlarm] → starts the native service (alarm + full-screen notification)
/// - [stopAlarm]  → stops everything (audio + notification + wake lock)
/// - [getAlarmOrderData] → retrieves order data if app was launched from alarm
///
/// Also listens for [onAlarmOrderReceived] calls from native side
/// (when alarm notification is tapped while app is already running).
class OrderAlarmService {
  static const _channel = MethodChannel('com.zill.vendor/order_alarm');

  /// Callback invoked when an alarm order is received while app is running.
  /// Set this from the widget that needs to react (e.g., home screen).
  static void Function(AlarmOrderData data)? onAlarmOrderReceived;

  /// Initialize the method channel handler for incoming native calls.
  /// Call this once during app startup.
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmOrderReceived') {
        final args = call.arguments;
        if (args is Map) {
          final data = AlarmOrderData.fromMap(args);
          AppLogger.i('[OrderAlarm] Received alarm order: #${data.orderNumber}');
          onAlarmOrderReceived?.call(data);
        }
      }
    });
  }

  /// Start the loud alarm foreground service.
  /// The native side will:
  /// 1. Show a full-screen intent notification
  /// 2. Play alarm audio on ALARM stream in a loop at max volume
  /// 3. Acquire a wake lock
  static Future<void> startAlarm(AlarmOrderData order) async {
    try {
      await _channel.invokeMethod('startAlarm', order.toMap());
      AppLogger.i('[OrderAlarm] Alarm started for order #${order.orderNumber}');
    } on PlatformException catch (e) {
      AppLogger.e('[OrderAlarm] Failed to start alarm', e);
    }
  }

  /// Stop the alarm — kills audio, clears notification, releases wake lock.
  /// Safe to call multiple times (idempotent).
  static Future<void> stopAlarm() async {
    try {
      await _channel.invokeMethod('stopAlarm');
      AppLogger.i('[OrderAlarm] Alarm stopped');
    } on PlatformException catch (e) {
      AppLogger.e('[OrderAlarm] Failed to stop alarm', e);
    }
  }

  /// Check if the app was launched from an alarm notification.
  /// Returns [AlarmOrderData] if yes, null otherwise.
  static Future<AlarmOrderData?> getAlarmOrderData() async {
    try {
      final result = await _channel.invokeMethod('getAlarmOrderData');
      if (result is Map && result.isNotEmpty) {
        return AlarmOrderData.fromMap(result);
      }
    } on PlatformException catch (e) {
      AppLogger.e('[OrderAlarm] Failed to get alarm data', e);
    }
    return null;
  }
}
