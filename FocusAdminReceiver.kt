package com.focusguard.focusguard

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class FocusAdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Disabling FocusGuard Uninstall Guard will allow deleting the app."
    }

    companion object {
        fun componentName(ctx: Context): ComponentName =
            ComponentName(ctx.applicationContext, FocusAdminReceiver::class.java)

        fun isAdminActive(ctx: Context): Boolean {
            return try {
                val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                dpm.isAdminActive(componentName(ctx))
            } catch (_: Exception) {
                false
            }
        }
    }
}
