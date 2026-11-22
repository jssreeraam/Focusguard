package com.focusguard.focusguard

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val title = intent?.getStringExtra("title") ?: "FocusGuard Daily Revision"
        val body = intent?.getStringExtra("body") ?: "Open your Revise tab and clear today's spaced repetition topics."
        val id = intent?.getIntExtra("id", 5501) ?: 5501
        showNow(context, title, body, id)

        // Re-schedule next day's reminder automatically if enabled
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (p.getBoolean("enabled", false)) {
            scheduleDaily(
                context,
                p.getInt("hour", 8),
                p.getInt("minute", 30),
                p.getString("body", body) ?: body
            )
        }
    }

    companion object {
        private const val PREFS = "fg_reminders"
        private const val CHANNEL_ID = "focusguard_study_alerts"

        fun showNow(ctx: Context, title: String, body: String, notifId: Int = 5502) {
            try {
                val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CHANNEL_ID) == null) {
                    val ch = NotificationChannel(
                        CHANNEL_ID,
                        "FocusGuard Study & Revision Alerts",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "Daily spaced repetition reminders and session completion alerts."
                    }
                    nm.createNotificationChannel(ch)
                }
                val launch = Intent(ctx, MainActivity::class.java)
                val pi = PendingIntent.getActivity(
                    ctx, notifId, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Notification.Builder(ctx, CHANNEL_ID)
                } else {
                    @Suppress("DEPRECATION")
                    Notification.Builder(ctx)
                }
                val n = builder
                    .setContentTitle(title)
                    .setContentText(body)
                    .setStyle(Notification.BigTextStyle().bigText(body))
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setAutoCancel(true)
                    .setContentIntent(pi)
                    .build()
                nm.notify(notifId, n)
            } catch (_: Exception) {}
        }

        fun scheduleDaily(ctx: Context, hour: Int, minute: Int, body: String) {
            try {
                ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putBoolean("enabled", true)
                    .putInt("hour", hour)
                    .putInt("minute", minute)
                    .putString("body", body)
                    .apply()

                val cal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    if (timeInMillis <= System.currentTimeMillis() + 5000L) {
                        add(Calendar.DAY_OF_YEAR, 1)
                    }
                }
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val i = Intent(ctx, ReminderReceiver::class.java).apply {
                    putExtra("title", "FocusGuard · Daily Revision Due")
                    putExtra("body", body)
                    putExtra("id", 5501)
                }
                val pi = PendingIntent.getBroadcast(
                    ctx, 5501, i,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
            } catch (_: Exception) {}
        }

        fun cancelDaily(ctx: Context) {
            try {
                ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putBoolean("enabled", false)
                    .apply()
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val i = Intent(ctx, ReminderReceiver::class.java)
                val pi = PendingIntent.getBroadcast(
                    ctx, 5501, i,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.cancel(pi)
            } catch (_: Exception) {}
        }

        fun rescheduleIfEnabled(ctx: Context) {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (p.getBoolean("enabled", false)) {
                scheduleDaily(
                    ctx,
                    p.getInt("hour", 8),
                    p.getInt("minute", 30),
                    p.getString("body", "Time to tick off today's spaced repetition topics!") ?: "Time to revise!"
                )
            }
        }
    }
}
