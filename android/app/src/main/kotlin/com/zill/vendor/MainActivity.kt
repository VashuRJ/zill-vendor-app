package com.zill.vendor

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main Activity — bridges native Android alarm service with Flutter via MethodChannel.
 *
 * MethodChannel "com.zill.vendor/order_alarm":
 *   - startAlarm(orderData)  → starts OrderAlarmService
 *   - stopAlarm()            → stops OrderAlarmService
 *   - getAlarmOrderData()    → returns order data if launched from alarm notification
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.zill.vendor/order_alarm"
    }

    private var alarmOrderData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // If launched from alarm notification, show over lock screen
        if (intent?.getBooleanExtra("from_alarm", false) == true) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // Capture order data from intent
        extractOrderData(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extractOrderData(intent)

        // Notify Flutter that new alarm data arrived (for when app is already running)
        flutterEngine?.dartExecutor?.let { executor ->
            MethodChannel(executor.binaryMessenger, CHANNEL)
                .invokeMethod("onAlarmOrderReceived", alarmOrderData)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarm" -> {
                        val orderData = call.arguments as? Map<*, *>
                        startAlarmService(orderData)
                        result.success(true)
                    }
                    "stopAlarm" -> {
                        stopAlarmService()
                        result.success(true)
                    }
                    "getAlarmOrderData" -> {
                        result.success(alarmOrderData)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun extractOrderData(intent: Intent?) {
        if (intent?.getBooleanExtra("from_alarm", false) == true) {
            alarmOrderData = mapOf(
                "order_id" to (intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_ID) ?: "0"),
                "order_number" to (intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_NUMBER) ?: ""),
                "order_amount" to (intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_AMOUNT) ?: ""),
                "order_items" to (intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_ITEMS) ?: ""),
                "order_customer" to (intent.getStringExtra(OrderAlarmService.EXTRA_ORDER_CUSTOMER) ?: ""),
            )
        }
    }

    private fun startAlarmService(orderData: Map<*, *>?) {
        val intent = Intent(this, OrderAlarmService::class.java).apply {
            putExtra(OrderAlarmService.EXTRA_ORDER_ID, orderData?.get("order_id")?.toString() ?: "0")
            putExtra(OrderAlarmService.EXTRA_ORDER_NUMBER, orderData?.get("order_number")?.toString() ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_AMOUNT, orderData?.get("order_amount")?.toString() ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_ITEMS, orderData?.get("order_items")?.toString() ?: "")
            putExtra(OrderAlarmService.EXTRA_ORDER_CUSTOMER, orderData?.get("order_customer")?.toString() ?: "")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAlarmService() {
        val intent = Intent(this, OrderAlarmService::class.java).apply {
            action = OrderAlarmService.ACTION_STOP
        }
        startService(intent)
        alarmOrderData = null
    }
}
