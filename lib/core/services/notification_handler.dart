import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

// ────────────────────────────────────────────────────────────────────
//  Vendor Push Notification Types
// ────────────────────────────────────────────────────────────────────

/// All known push notification type strings from the backend.
enum VendorNotificationType {
  // Order lifecycle
  newOrder,
  orderCancelled,
  orderStatusUpdated,

  // Scheduled orders (new)
  scheduledOrderReceived,
  scheduledOrderCancelled,

  // Fallback
  unknown;

  static VendorNotificationType fromString(String type) {
    return switch (type) {
      'new_order' || 'vendor_new_order' => newOrder,
      'order_cancelled' => orderCancelled,
      'order_status_updated' => orderStatusUpdated,
      'vendor_scheduled_order_received' => scheduledOrderReceived,
      'vendor_scheduled_order_cancelled' => scheduledOrderCancelled,
      _ => unknown,
    };
  }
}

// ────────────────────────────────────────────────────────────────────
//  Notification Payload
// ────────────────────────────────────────────────────────────────────
class VendorNotificationPayload {
  final VendorNotificationType type;
  final String title;
  final String body;
  final int? orderId;
  final String? orderNumber;
  final DateTime? scheduledFor; // only for scheduled order types

  const VendorNotificationPayload({
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.orderNumber,
    this.scheduledFor,
  });

  factory VendorNotificationPayload.fromMap(Map<String, dynamic> data) {
    final typeStr = data['type'] as String? ?? '';
    final type = VendorNotificationType.fromString(typeStr);

    DateTime? scheduled;
    try {
      final raw = data['scheduled_for'] as String?;
      if (raw != null && raw.isNotEmpty) scheduled = DateTime.parse(raw);
    } catch (_) {}

    return VendorNotificationPayload(
      type: type,
      title: data['title'] as String? ?? _defaultTitle(type),
      body: data['body'] as String? ?? '',
      orderId: (data['order_id'] as num?)?.toInt(),
      orderNumber: data['order_number'] as String?,
      scheduledFor: scheduled,
    );
  }

  static String _defaultTitle(VendorNotificationType type) => switch (type) {
    VendorNotificationType.newOrder => 'New Order Received',
    VendorNotificationType.orderCancelled => 'Order Cancelled',
    VendorNotificationType.orderStatusUpdated => 'Order Updated',
    VendorNotificationType.scheduledOrderReceived => 'Scheduled Order',
    VendorNotificationType.scheduledOrderCancelled =>
      'Scheduled Order Cancelled',
    VendorNotificationType.unknown => 'Notification',
  };
}

// ────────────────────────────────────────────────────────────────────
//  Handler
// ────────────────────────────────────────────────────────────────────

/// Call [handleNotification] whenever a push notification payload arrives
/// (foreground, background, or launched-from-terminated).
///
/// Pass an [onRefreshOrders] callback so the handler can trigger a
/// live data reload without knowing about the ViewModel directly.
class VendorNotificationHandler {
  const VendorNotificationHandler._();

  static void handleNotification(
    Map<String, dynamic> data, {
    required VoidCallback onRefreshOrders,
    BuildContext? context,
  }) {
    final payload = VendorNotificationPayload.fromMap(data);

    AppLogger.i(
      '[Notification] type=${payload.type.name} '
      'orderId=${payload.orderId} title=${payload.title}',
    );

    switch (payload.type) {
      // Standard order events → refresh order list
      case VendorNotificationType.newOrder:
      case VendorNotificationType.orderCancelled:
      case VendorNotificationType.orderStatusUpdated:
        onRefreshOrders();

      // ── Scheduled order received ──────────────────────────────────
      case VendorNotificationType.scheduledOrderReceived:
        onRefreshOrders();
        if (context != null && context.mounted) {
          _showScheduledOrderBanner(
            context: context,
            payload: payload,
            isNew: true,
          );
        }

      // ── Scheduled order cancelled by customer ─────────────────────
      case VendorNotificationType.scheduledOrderCancelled:
        onRefreshOrders();
        if (context != null && context.mounted) {
          _showScheduledOrderBanner(
            context: context,
            payload: payload,
            isNew: false,
          );
        }

      case VendorNotificationType.unknown:
        // Log and ignore unknown types — no crash
        AppLogger.w('[Notification] Unhandled type: ${data['type']}');
    }
  }

  // ── Scheduled order in-app banner ───────────────────────────────
  static void _showScheduledOrderBanner({
    required BuildContext context,
    required VendorNotificationPayload payload,
    required bool isNew,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final scheduledLabel = payload.scheduledFor != null
        ? ' (${TimeOfDay.fromDateTime(payload.scheduledFor!).format(context)})'
        : '';

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isNew
            ? const Color(0xFF0A58CA)
            : const Color(0xFF721C24),
        content: Row(
          children: [
            Icon(
              isNew
                  ? Icons.event_available_outlined
                  : Icons.event_busy_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew
                        ? 'Scheduled Order$scheduledLabel'
                        : 'Scheduled Order Cancelled',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  if (payload.orderNumber != null)
                    Text(
                      payload.orderNumber!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
