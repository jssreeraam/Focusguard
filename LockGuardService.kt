package com.focusguard.focusguard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat

class LockGuardService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val ticker = object : Runnable {
        override fun run() {
            val rem = LockStore.syncAndGetRemainingMs(applicationContext)
            if (rem <= 0L) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return
            }
            updateNotification(rem)
            handler.postDelayed(this, 30_000L)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val rem = LockStore.syncAndGetRemainingMs(applicationContext)
        if (rem <= 0L) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        ensureChannel()
        val notif = buildNotification(rem)
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIF_ID, notif)
            }
        } catch (_: Exception) {}
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, 30_000L)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "FocusGuard Active Lock",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Shows remaining app lock time and prevents background kill."
                    setShowBadge(false)
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    private fun buildNotification(remMs: Long): Notification {
        val launch = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val totalMin = (remMs / 60000L).coerceAtLeast(1L)
        val h = totalMin / 60L
        val m = totalMin % 60L
        val text = if (h > 0L) "${h}h ${m}m remaining · Selected apps locked" else "${m}m remaining · Selected apps locked"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("FocusGuard Lock Active")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }

    private fun updateNotification(remMs: Long) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildNotification(remMs))
        } catch (_: Exception) {}
    }

    companion object {
        private const val CHANNEL_ID = "focusguard_lock_channel"
        private const val NOTIF_ID = 4401

        fun start(ctx: Context) {
            try {
                val i = Intent(ctx.applicationContext, LockGuardService::class.java)
                ContextCompat.startForegroundService(ctx.applicationContext, i)
            } catch (_: Exception) {}
        }

        fun stop(ctx: Context) {
            try {
                ctx.applicationContext.stopService(Intent(ctx.applicationContext, LockGuardService::class.java))
            } catch (_: Exception) {}
        }
    }
}
