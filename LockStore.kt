package com.focusguard.focusguard

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import kotlin.math.max

/**
 * Monotonic, tamper-resistant lock state store.
 * Uses SystemClock.elapsedRealtime() so changing Android's Date & Time
 * forward or backward NEVER bypasses an active penalty lock.
 */
object LockStore {
    private const val PREFS = "fg_lock_v2"
    private const val KEY_PKGS = "pkgs"
    private const val KEY_ACTIVE = "active"
    private const val KEY_REM_MS = "rem_ms"
    private const val KEY_LAST_ELAPSED = "last_elapsed"
    private const val KEY_LAST_WALL = "last_wall"
    private const val KEY_STRICT = "strict_tamper"
    private const val KEY_BLOCK_ALL_SETTINGS = "block_all_settings"

    private fun prefs(ctx: Context) =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun startLock(ctx: Context, pkgs: Set<String>, durationMs: Long) {
        val cleanPkgs = pkgs.filter { it.isNotBlank() && it != ctx.packageName }.toSet()
        val nowEl = SystemClock.elapsedRealtime()
        val nowWall = System.currentTimeMillis()
        val active = durationMs > 0L && cleanPkgs.isNotEmpty()
        prefs(ctx).edit()
            .putStringSet(KEY_PKGS, cleanPkgs)
            .putBoolean(KEY_ACTIVE, active)
            .putLong(KEY_REM_MS, if (active) durationMs else 0L)
            .putLong(KEY_LAST_ELAPSED, nowEl)
            .putLong(KEY_LAST_WALL, nowWall)
            .apply()
    }

    @Synchronized
    fun syncAndGetRemainingMs(ctx: Context): Long {
        val p = prefs(ctx)
        if (!p.getBoolean(KEY_ACTIVE, false)) return 0L

        var rem = p.getLong(KEY_REM_MS, 0L)
        val lastEl = p.getLong(KEY_LAST_ELAPSED, 0L)
        val lastWall = p.getLong(KEY_LAST_WALL, 0L)
        val nowEl = SystemClock.elapsedRealtime()
        val nowWall = System.currentTimeMillis()

        if (nowEl >= lastEl && lastEl > 0L) {
            // Normal monotonic progression: immune to system clock edits.
            val delta = nowEl - lastEl
            rem = max(0L, rem - delta)
        } else if (nowEl < lastEl) {
            // Phone rebooted (elapsedRealtime reset to 0).
            // Only deduct wall-clock time if automatic network time is ON and delta is plausible (<12h).
            val autoTime = try {
                Settings.Global.getInt(ctx.contentResolver, Settings.Global.AUTO_TIME, 0) == 1
            } catch (_: Exception) {
                false
            }
            val wallDelta = nowWall - lastWall
            if (autoTime && wallDelta in 1L..(12L * 3600L * 1000L)) {
                rem = max(0L, rem - wallDelta)
            }
        }

        val stillActive = rem > 0L
        p.edit()
            .putBoolean(KEY_ACTIVE, stillActive)
            .putLong(KEY_REM_MS, rem)
            .putLong(KEY_LAST_ELAPSED, nowEl)
            .putLong(KEY_LAST_WALL, nowWall)
            .apply()

        return rem
    }

    @Synchronized
    fun onTimeTampered(ctx: Context) {
        val p = prefs(ctx)
        if (!p.getBoolean(KEY_ACTIVE, false)) return
        // Advance monotonic sync first, then anchor new wall time without reducing rem_ms.
        syncAndGetRemainingMs(ctx)
        p.edit().putLong(KEY_LAST_WALL, System.currentTimeMillis()).apply()
    }

    fun isBlockedPackage(ctx: Context, pkg: String): Boolean {
        if (pkg == ctx.packageName) return false
        if (syncAndGetRemainingMs(ctx) <= 0L) return false
        val blocked = prefs(ctx).getStringSet(KEY_PKGS, emptySet()) ?: emptySet()
        return blocked.contains(pkg)
    }

    fun setAntiTamper(ctx: Context, strict: Boolean, blockAllSettings: Boolean) {
        prefs(ctx).edit()
            .putBoolean(KEY_STRICT, strict)
            .putBoolean(KEY_BLOCK_ALL_SETTINGS, blockAllSettings)
            .apply()
    }

    fun isStrictTamper(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_STRICT, true)
    fun isBlockAllSettings(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_BLOCK_ALL_SETTINGS, false)
}
