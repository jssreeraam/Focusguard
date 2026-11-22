package com.focusguard.focusguard

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focusguard/blocker")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "apps" -> {
                            val pm = packageManager
                            val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                            val list = pm.queryIntentActivities(i, 0)
                                .filter { it.activityInfo.packageName != packageName }
                                .map {
                                    mapOf(
                                        "label" to it.loadLabel(pm).toString(),
                                        "pkg" to it.activityInfo.packageName
                                    )
                                }
                                .distinctBy { it["pkg"] }
                                .sortedBy { (it["label"] as String).lowercase() }
                            result.success(list)
                        }
                        "setLock" -> {
                            val pkgs = (call.argument<List<String>>("pkgs") ?: emptyList()).toSet()
                            val durationMs = call.argument<Number>("durationMs")?.toLong()
                                ?: run {
                                    val until = (call.argument<Number>("until") ?: 0L).toLong()
                                    (until - System.currentTimeMillis()).coerceAtLeast(0L)
                                }
                            LockStore.startLock(this, pkgs, durationMs)
                            if (durationMs > 0L && pkgs.isNotEmpty()) {
                                LockGuardService.start(this)
                            }
                            result.success(true)
                        }
                        "lockRemainingMs" -> {
                            result.success(LockStore.syncAndGetRemainingMs(this))
                        }
                        "setAntiTamper" -> {
                            val strict = call.argument<Boolean>("strict") ?: true
                            val blockAll = call.argument<Boolean>("blockAllSettings") ?: false
                            LockStore.setAntiTamper(this, strict, blockAll)
                            result.success(true)
                        }
                        "getAntiTamper" -> {
                            result.success(
                                mapOf(
                                    "strict" to LockStore.isStrictTamper(this),
                                    "blockAllSettings" to LockStore.isBlockAllSettings(this)
                                )
                            )
                        }
                        "enabled" -> result.success(BlockerService.isEnabled(this))
                        "openSettings" -> {
                            startActivity(
                                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        }
                        "isAdminEnabled" -> result.success(FocusAdminReceiver.isAdminActive(this))
                        "requestAdmin" -> {
                            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                                putExtra(
                                    DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                                    FocusAdminReceiver.componentName(this@MainActivity)
                                )
                                putExtra(
                                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                    "Prevents uninstalling FocusGuard during active study locks."
                                )
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                        "isBatteryIgnored" -> {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                        "requestBatteryIgnore" -> {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                            } catch (_: Exception) {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            }
                            result.success(true)
                        }
                        "requestNotificationPermission" -> {
                            if (Build.VERSION.SDK_INT >= 33) {
                                val granted = ContextCompat.checkSelfPermission(
                                    this, Manifest.permission.POST_NOTIFICATIONS
                                ) == PackageManager.PERMISSION_GRANTED
                                if (!granted) {
                                    ActivityCompat.requestPermissions(
                                        this,
                                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                        901
                                    )
                                }
                            }
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("FG_ERR", e.message, null)
                }
            }
    }
}
