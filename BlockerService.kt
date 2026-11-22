package com.focusguard.focusguard

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast

class BlockerService : AccessibilityService() {

    private var lastToastMs = 0L
    private var lastKickMs = 0L

    private val settingsPackages = setOf(
        "com.android.settings",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.miui.securitycenter",
        "com.samsung.android.lool",
        "com.coloros.safecenter",
        "com.oplus.safecenter",
        "com.iqoo.secure",
        "com.huawei.systemmanager"
    )

    private val tamperKeywords = listOf(
        "focusguard",
        "focus guard",
        "accessibility",
        "device admin",
        "device manager",
        "uninstall",
        "force stop",
        "date & time",
        "date and time",
        "set time",
        "set date",
        "automatic date",
        "clear storage",
        "clear data",
        "installed services",
        "downloaded apps"
    )

    override fun onAccessibilityEvent(e: AccessibilityEvent?) {
        if (e == null) return
        val pkg = e.packageName?.toString() ?: return
        if (pkg == packageName || pkg == "com.android.systemui") return

        val remaining = LockStore.syncAndGetRemainingMs(this)
        if (remaining <= 0L) return

        if (LockStore.isBlockedPackage(this, pkg)) {
            kickHome("FocusGuard: Locked (${formatShort(remaining)} left). Earn it back.")
            return
        }

        if (LockStore.isStrictTamper(this) && settingsPackages.contains(pkg)) {
            if (LockStore.isBlockAllSettings(this)) {
                kickHome("FocusGuard Strict Mode: Settings blocked (${formatShort(remaining)} left).")
                return
            }
            val cls = e.className?.toString()?.lowercase() ?: ""
            if (cls.contains("uninstall") || cls.contains("deviceadmin") || cls.contains("datetime") || cls.contains("accessibility")) {
                kickHome("FocusGuard Strict Mode: Tampering blocked while locked.")
                return
            }
            if (windowContainsTamperKeyword()) {
                kickHome("FocusGuard Strict Mode: Tampering blocked while locked.")
            }
        }
    }

    private fun windowContainsTamperKeyword(): Boolean {
        val root = try {
            rootInActiveWindow
        } catch (_: Exception) {
            null
        } ?: return false

        return try {
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            var visited = 0
            while (queue.isNotEmpty() && visited < 65) {
                val node = queue.removeFirst()
                visited++
                val text = node.text?.toString()?.lowercase() ?: ""
                val desc = node.contentDescription?.toString()?.lowercase() ?: ""
                if (text.isNotEmpty() || desc.isNotEmpty()) {
                    for (kw in tamperKeywords) {
                        if (text.contains(kw) || desc.contains(kw)) return true
                    }
                }
                val count = node.childCount
                for (i in 0 until count) {
                    val child = node.getChild(i)
                    if (child != null) queue.add(child)
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun kickHome(msg: String) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastKickMs > 350L) {
            lastKickMs = now
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
        if (now - lastToastMs > 2500L) {
            lastToastMs = now
            Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show()
        }
    }

    private fun formatShort(ms: Long): String {
        val totalMin = (ms / 60000L).coerceAtLeast(1L)
        val h = totalMin / 60L
        val m = totalMin % 60L
        return if (h > 0L) "${h}h ${m}m" else "${m}m"
    }

    override fun onInterrupt() {}

    companion object {
        fun isEnabled(c: Context): Boolean {
            val s = Settings.Secure.getString(
                c.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return s.contains(c.packageName + "/") && s.contains("BlockerService")
        }
    }
}
