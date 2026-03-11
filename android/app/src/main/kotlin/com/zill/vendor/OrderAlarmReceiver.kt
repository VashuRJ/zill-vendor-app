package com.zill.vendor

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Native FCM message handler that intercepts "new_order" data messages
 * and starts the [OrderAlarmService] BEFORE Flutter's background isolate boots.
 *
 * Extends [FlutterFirebaseMessagingService] (not raw FirebaseMessagingService)
 * so that onNewToken still forwards to Flutter's token live data,
 * and we don't conflict with the plugin's manifest service.
 *
 * Flutter's actual message handling goes through FlutterFirebaseMessagingReceiver
 * (a BroadcastReceiver), so we don't break any existing message flow.
 */
class ZillFirebaseMessagingService : FlutterFirebaseMessagingService() {

    companion object {
        const val TAG = "ZillFCMService"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""

        Log.i(TAG, "FCM received: type=$type, data=$data")

        if (type == "new_order" || type == "vendor_new_order") {
            Log.i(TAG, "New order detected — starting alarm service")
            startAlarmForOrder(data)
        }

        // Delegate to Flutter plugin (currently a no-op, but future-proof)
        super.onMessageReceived(message)
    }

    private fun startAlarmForOrder(data: Map<String, String>) {
        val intent = Intent(this, OrderAlarmService::class.java).apply {
            putExtra(OrderAlarmService.EXTRA_ORDER_ID, data["order_id"] ?: "0")
            putExtra(OrderAlarmService.EXTRA_ORDER_NUMBER, data["order_number"] ?: "New Order")
            putExtra(OrderAlarmService.EXTRA_ORDER_AMOUNT, data["total_amount"] ?: data["order_amount"] ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_ITEMS, data["items_summary"] ?: data["order_items"] ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_CUSTOMER, data["customer_name"] ?: data["order_customer"] ?: "")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start alarm service", e)
        }
    }

    override fun onNewToken(token: String) {
        Log.i(TAG, "FCM token refreshed: ${token.take(20)}...")
        // Delegate to Flutter plugin so token refresh listeners work
        super.onNewToken(token)
    }
}
