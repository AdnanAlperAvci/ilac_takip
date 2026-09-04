package com.adnanalperavci.ilactakip

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class UnlockMonitorService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val unlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_USER_PRESENT -> {
                    MedicineNotifier.notifyOnUnlockAfterLimit(context)
                }
                Intent.ACTION_SCREEN_ON -> {
                    checkUnlockStateAfterScreenOn()
                }
            }
        }
    }
    private var isReceiverRegistered = false

    override fun onCreate() {
        super.onCreate()
        startForeground(MONITOR_NOTIFICATION_ID, createMonitorNotification())
        registerUnlockReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        registerUnlockReceiver()
        return START_STICKY
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        if (isReceiverRegistered) {
            unregisterReceiver(unlockReceiver)
            isReceiverRegistered = false
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun registerUnlockReceiver() {
        if (isReceiverRegistered) {
            return
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(unlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(unlockReceiver, filter)
        }
        isReceiverRegistered = true
    }

    private fun checkUnlockStateAfterScreenOn() {
        mainHandler.postDelayed({
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (!keyguardManager.isKeyguardLocked) {
                MedicineNotifier.notifyOnUnlockAfterLimit(this)
            }
        }, SCREEN_ON_UNLOCK_CHECK_DELAY_MS)
    }

    private fun createMonitorNotification(): Notification {
        createMonitorChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, MedicineNotifier.MONITOR_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("İlaç Takip")
            .setContentText("Kilit açma hatırlatmaları açık.")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSound(null)
            .setVibrate(null)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }

    private fun createMonitorChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            MedicineNotifier.MONITOR_CHANNEL_ID,
            "İlaç takip arka plan servisi",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Kilit açma olayını yakalamak için arka plan takip servisi."
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.setShowBadge(false)

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        private const val MONITOR_NOTIFICATION_ID = 1108
        private const val SCREEN_ON_UNLOCK_CHECK_DELAY_MS = 2500L
    }
}
