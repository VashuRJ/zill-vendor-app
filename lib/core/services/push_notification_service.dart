import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/api_endpoints.dart';
import '../utils/app_logger.dart';
import 'api_service.dart';
import 'order_alarm_service.dart';
import 'storage_service.dart';
import 'notification_handler.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure the local-notification channel exists so the system can play
  // the default sound even when the app process is dead.
  await _ensureNotificationChannel();
  AppLogger.i('[FCM] Background message: ${message.messageId}');
}

/// High-importance channel used for all vendor alerts.
const AndroidNotificationChannel _highChannel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // name
  description:
      'This channel is used for order alerts and important vendor notifications.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Singleton plugin instance shared between service and background handler.
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Creates the Android notification channel (idempotent — safe to call repeatedly).
Future<void> _ensureNotificationChannel() async {
  final androidPlugin = _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(_highChannel);
}

class PushNotificationService {
  final ApiService _apiService;
  final StorageService _storageService;
  final FirebaseMessaging _messaging;

  /// Track stream subscriptions to cancel on unregister/re-init.
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  /// Optional callback to refresh orders when a push arrives in foreground.
  VoidCallback? onRefreshOrders;

  /// Optional callback to navigate to a specific order (notification tap).
  void Function(int orderId)? onNavigateToOrder;

  PushNotificationService({
    required ApiService apiService,
    required StorageService storageService,
  }) : _apiService = apiService,
       _storageService = storageService,
       _messaging = FirebaseMessaging.instance;

  // ── Initialize ─────────────────────────────────────────────────────
  /// Call this once after Firebase.initializeApp() and after the user is
  /// authenticated. Safe to call multiple times (idempotent).
  Future<void> initialize() async {
    AppLogger.i('[FCM] ══ Initializing Push Notification Service ══');

    // 1. Create the high-importance notification channel (Android)
    await _ensureNotificationChannel();
    AppLogger.i('[FCM] ✅ Step 1: Notification channel created');

    // 2. Initialize flutter_local_notifications
    await _initLocalNotifications();
    AppLogger.i('[FCM] ✅ Step 2: Local notifications initialized');

    // 3. Request permission (iOS + Android 13+)
    final permGranted = await requestNotificationPermission();
    AppLogger.i(
      '[FCM] ${permGranted ? "✅" : "❌"} Step 3: Permission ${permGranted ? "GRANTED" : "DENIED"}',
    );

    if (!permGranted) {
      AppLogger.e(
        '[FCM] ⚠️ Notification permission DENIED — '
        'user must enable it in Settings > Apps > Zill Restaurant Partner > Notifications',
      );
    }

    // 4. Get FCM token and register with backend
    await _getAndRegisterToken();
    AppLogger.i('[FCM] ✅ Step 4: Token registration attempted');

    // 5. Cancel previous subscriptions to avoid duplicates on re-login
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _messageOpenedSub?.cancel();

    // 6. Listen for token refreshes (e.g. app restore, new device)
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      AppLogger.i('[FCM] Token refreshed — re-registering');
      _registerTokenWithBackend(newToken);
    });

    // 7. Foreground message listener — shows heads-up notification
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // 8. When user taps a notification (app was in background)
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
    );

    // 8. Check if app was launched from a terminated-state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // 9. Show foreground notifications as heads-up on iOS too
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    AppLogger.i('[FCM] ══ Push notification service FULLY initialized ══');
  }

  // ── Local Notifications Setup ──────────────────────────────────────
  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Called when user taps a local notification (foreground-created).
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.i('[LOCAL] Notification tapped, payload: ${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      final orderId = int.tryParse(payload);
      if (orderId != null && onNavigateToOrder != null) {
        onNavigateToOrder!(orderId);
        return;
      }
    }
    // Fallback: refresh orders list
    onRefreshOrders?.call();
  }

  // ── Permission ─────────────────────────────────────────────────────
  /// Requests notification permission using both Firebase (iOS) and
  /// permission_handler (Android 13+). Can be called from a settings
  /// screen or anywhere else.
  Future<bool> requestNotificationPermission() async {
    // Firebase-level request (covers iOS and older Android)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    AppLogger.i(
      '[FCM] Firebase permission status: ${settings.authorizationStatus}',
    );

    // Android 13+ (API 33) requires explicit POST_NOTIFICATIONS permission
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        AppLogger.i('[FCM] Android notification permission: $result');
        return result.isGranted;
      }
      return true;
    }

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // ── Token Management ───────────────────────────────────────────────
  Future<void> _getAndRegisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        // Print FULL token in debug for testing — helps verify in Firebase Console
        AppLogger.i('[FCM] ═══════════════════════════════════════════');
        AppLogger.i('[FCM] DEVICE TOKEN: $token');
        AppLogger.i('[FCM] ═══════════════════════════════════════════');
        await _registerTokenWithBackend(token);
      } else {
        AppLogger.e(
          '[FCM] ❌ Could not obtain device token — '
          'check google-services.json and Firebase project setup',
        );
      }
    } catch (e, stack) {
      AppLogger.e('[FCM] ❌ Error getting token: $e');
      AppLogger.e('[FCM] Stack: $stack');
    }
  }

  /// POST /api/notifications/devices/register/
  /// Payload: { "token": "...", "device_type": "android"|"ios", "active": true }
  Future<void> _registerTokenWithBackend(String token) async {
    // Only register if user is authenticated
    final hasTokens = await _storageService.hasTokens();
    if (!hasTokens) {
      AppLogger.i('[FCM] Skipping registration — user not authenticated');
      return;
    }

    final deviceType = Platform.isIOS ? 'ios' : 'android';

    try {
      await _apiService.post(
        ApiEndpoints.registerDevice,
        data: {
          'token': token,
          'device_type': deviceType,
          'platform': deviceType,
          'active': true,
        },
      );
      AppLogger.i('[FCM] Device token registered with backend ($deviceType)');
    } catch (e) {
      // Non-fatal — token registration can be retried on next app launch
      AppLogger.e('[FCM] Failed to register token with backend', e);
    }
  }

  // ── Foreground Messages ────────────────────────────────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.i('[FCM] Foreground message: ${message.messageId}');
    AppLogger.i('[FCM]   title: ${message.notification?.title}');
    AppLogger.i('[FCM]   body: ${message.notification?.body}');
    AppLogger.i('[FCM]   data: ${message.data}');

    final type = message.data['type'] ?? '';

    // New order → trigger loud alarm via native service (foreground too,
    // because the native FCM handler may have already started it, but
    // we also want to navigate to the incoming order screen).
    if (type == 'new_order' || type == 'vendor_new_order') {
      AppLogger.i(
        '[FCM] New order in foreground — triggering alarm + navigation',
      );
      final data = message.data;
      final alarmData = AlarmOrderData(
        orderId: int.tryParse(data['order_id'] ?? '0') ?? 0,
        orderNumber: data['order_number'] ?? 'New Order',
        orderAmount: data['total_amount'] ?? data['order_amount'] ?? '',
        orderItems: data['items_summary'] ?? data['order_items'] ?? '',
        customerName: data['customer_name'] ?? data['order_customer'] ?? '',
      );
      // Native ZillFirebaseMessagingService already started the alarm,
      // so we only need to notify Flutter listeners for navigation.
      // Notify Flutter listeners (IncomingOrderScreen will show)
      OrderAlarmService.onAlarmOrderReceived?.call(alarmData);
      // Still refresh orders list
      onRefreshOrders?.call();
      return; // Skip normal notification — alarm handles it
    }

    // Non-order messages: show a heads-up local notification
    _showLocalNotification(message);

    // Delegate to VendorNotificationHandler for order-related actions
    if (message.data.isNotEmpty && onRefreshOrders != null) {
      VendorNotificationHandler.handleNotification(
        message.data.cast<String, dynamic>(),
        onRefreshOrders: onRefreshOrders!,
      );
    }
  }

  /// Display a heads-up notification via flutter_local_notifications.
  /// Uses the high-importance channel so it pops up on screen with sound.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    // Build the title/body — prefer notification fields, fall back to data
    final title =
        notification?.title ??
        message.data['title'] as String? ??
        'New Notification';
    final body = notification?.body ?? message.data['body'] as String? ?? '';

    // Extract orderId for the tap payload
    final orderId = message.data['order_id']?.toString() ?? '';

    await _localNotifications.show(
      // Use hashCode of messageId as notification id (avoids duplicates)
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _highChannel.id,
          _highChannel.name,
          channelDescription: _highChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          // Show as a heads-up notification
          ticker: title,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: orderId,
    );

    AppLogger.i('[LOCAL] Heads-up notification shown: $title');
  }

  // ── Background → Tap ──────────────────────────────────────────────
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.i(
      '[FCM] Notification tap (from background): ${message.messageId}',
    );
    AppLogger.i('[FCM]   data: ${message.data}');

    if (message.data.isEmpty) return;

    // Try to navigate to the specific order if orderId is present
    final orderId = int.tryParse(message.data['order_id']?.toString() ?? '');
    if (orderId != null && onNavigateToOrder != null) {
      onNavigateToOrder!(orderId);
      return;
    }

    // Fallback: just refresh orders
    if (onRefreshOrders != null) {
      VendorNotificationHandler.handleNotification(
        message.data.cast<String, dynamic>(),
        onRefreshOrders: onRefreshOrders!,
      );
    }
  }

  // ── Cleanup (on logout) ───────────────────────────────────────────
  /// Call this when the vendor logs out to stop receiving pushes.
  /// Unregisters the FCM token from backend first, then deletes locally.
  Future<void> unregister() async {
    // Cancel stream subscriptions first — prevents re-registration from
    // onTokenRefresh firing after we delete the token.
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _messageOpenedSub?.cancel();
    _messageOpenedSub = null;

    try {
      // Get the current token before deactivating it
      final token = await _messaging.getToken();
      if (token != null) {
        // Tell backend to deactivate this device token
        await _apiService.post(
          ApiEndpoints.registerDevice,
          data: {
            'token': token,
            'device_type': Platform.isIOS ? 'ios' : 'android',
            'platform': Platform.isIOS ? 'ios' : 'android',
            'active': false,
          },
        );
        AppLogger.i('[FCM] Device token deactivated on backend');
      }
    } catch (e) {
      AppLogger.e('[FCM] Error deactivating token on backend', e);
    }
    // NOTE: Do NOT call _messaging.deleteToken() here.
    // Deleting the FCM token causes Firebase to generate a completely new token
    // on next login. The old token becomes permanently invalid, but the new token
    // may not be ready immediately — causing notifications to silently fail.
    // Instead, we only deactivate on the backend. On next login, the SAME token
    // is re-registered and re-activated instantly.
    AppLogger.i(
      '[FCM] Logout cleanup complete (token kept locally, deactivated on server)',
    );
  }
}
