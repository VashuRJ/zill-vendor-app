package com.zill.vendor

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that plays a loud alarm on the ALARM audio stream
 * and shows a full-screen intent notification — like Zomato/Swiggy new order alerts.
 *
 * Started via MethodChannel from Flutter (or from FCM background handler).
 * Stopped when vendor taps Accept/Reject, or after [TIMEOUT_MS].
 */
class OrderAlarmService : Service() {

    companion object {
        const val TAG = "OrderAlarmService"
        const val CHANNEL_ID = "order_alarm_channel"
        const val NOTIFICATION_ID = 9999
        const val TIMEOUT_MS = 90_000L // Auto-stop after 90 seconds (safety net)

        const val EXTRA_ORDER_ID = "order_id"
        const val EXTRA_ORDER_NUMBER = "order_number"
        const val EXTRA_ORDER_AMOUNT = "order_amount"
        const val EXTRA_ORDER_ITEMS = "order_items"
        const val EXTRA_ORDER_CUSTOMER = "order_customer"

        const val ACTION_STOP = "com.zill.vendor.STOP_ALARM"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    // Safety timeout — stops alarm if vendor doesn't respond
    private val timeoutRunnable = Runnable {
        Log.w(TAG, "Alarm timed out after ${TIMEOUT_MS}ms — auto-stopping")
        stopSelf()
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.i(TAG, "Received STOP action")
            stopSelf()
            return START_NOT_STICKY
        }

        val orderId = intent?.getStringExtra(EXTRA_ORDER_ID) ?: "0"
        val orderNumber = intent?.getStringExtra(EXTRA_ORDER_NUMBER) ?: "New Order"
        val orderAmount = intent?.getStringExtra(EXTRA_ORDER_AMOUNT) ?: ""
        val orderItems = intent?.getStringExtra(EXTRA_ORDER_ITEMS) ?: ""
        val customerName = intent?.getStringExtra(EXTRA_ORDER_CUSTOMER) ?: ""

        Log.i(TAG, "Starting alarm for order #$orderNumber (id=$orderId)")

        // 1. Acquire partial wake lock to keep CPU alive
        acquireWakeLock()

        // 2. Build the full-screen intent notification
        val notification = buildNotification(orderId, orderNumber, orderAmount, orderItems, customerName)

        // 3. Start as foreground service
        startForeground(NOTIFICATION_ID, notification)

        // 4. Start loud alarm audio
        startAlarmAudio()

        // 5. Schedule safety timeout
        handler.removeCallbacks(timeoutRunnable)
        handler.postDelayed(timeoutRunnable, TIMEOUT_MS)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "Service destroying — cleaning up")
        handler.removeCallbacks(timeoutRunnable)
        stopAlarmAudio()
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Notification Channel ──────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Incoming Order Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Loud alarm for new incoming orders"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                // Use custom sound on the channel
                setSound(
                    getAlarmSoundUri(),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    // ── Full-Screen Intent Notification ───────────────────────────────

    private fun buildNotification(
        orderId: String,
        orderNumber: String,
        orderAmount: String,
        orderItems: String,
        customerName: String
    ): Notification {
        // Intent to open Flutter app with order data
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ORDER_ID, orderId)
            putExtra(EXTRA_ORDER_NUMBER, orderNumber)
            putExtra(EXTRA_ORDER_AMOUNT, orderAmount)
            putExtra(EXTRA_ORDER_ITEMS, orderItems)
            putExtra(EXTRA_ORDER_CUSTOMER, customerName)
            putExtra("from_alarm", true)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop alarm action button on the notification itself
        val stopIntent = Intent(this, OrderAlarmService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentText = buildString {
            if (customerName.isNotEmpty()) append("$customerName • ")
            if (orderItems.isNotEmpty()) append(orderItems)
            if (orderAmount.isNotEmpty()) {
                if (isNotEmpty()) append(" • ")
                append("₹$orderAmount")
            }
        }.ifEmpty { "Tap to view order details" }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🔔 New Order! #$orderNumber")
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss", stopPendingIntent)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .build()
    }

    // ── Alarm Audio ───────────────────────────────────────────────────

    private fun startAlarmAudio() {
        stopAlarmAudio() // Kill any leftover player (ghost prevention)

        try {
            // Force ALARM stream to max volume
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(applicationContext, getAlarmSoundUri())
                isLooping = true
                prepare()
                start()
            }
            Log.i(TAG, "Alarm audio started (looping, ALARM stream, max volume)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start alarm audio", e)
        }
    }

    private fun stopAlarmAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.reset()
                it.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm audio", e)
        }
        mediaPlayer = null
    }

    private fun getAlarmSoundUri(): Uri {
        return Uri.parse("android.resource://$packageName/${R.raw.order_alarm}")
    }

    // ── Wake Lock ─────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "com.zill.vendor:OrderAlarmWakeLock"
        ).apply {
            acquire(TIMEOUT_MS + 5000) // Auto-release slightly after timeout
        }
        Log.i(TAG, "Wake lock acquired")
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock", e)
        }
        wakeLock = null
    }
}
