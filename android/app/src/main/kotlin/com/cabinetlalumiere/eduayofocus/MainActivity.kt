package com.cabinetlalumiere.eduayofocus

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cabinetlalumiere.eduayofocus/accessibility"
    private val SESSION_CHANNEL = "com.cabinetlalumiere.eduayofocus/session"
    private val PREFS_NAME = "FlutterSharedPreferences"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())
                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    "getInstalledApps" -> result.success(getInstalledApps())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSession" -> {
                        val endHour = call.argument<Int>("endHour") ?: 17
                        val endMinute = call.argument<Int>("endMinute") ?: 0
                        val intent = Intent(this, SessionForegroundService::class.java)
                        intent.putExtra("endHour", endHour)
                        intent.putExtra("endMinute", endMinute)
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stopSession", "forceEndSession" -> {
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit()
                            .putBoolean("native_session_active", false)
                            .apply()
                        val intent = Intent(this, SessionForegroundService::class.java)
                        stopService(intent)
                        result.success(null)
                    }
                    "getSessionStatus" -> {
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        val status = mapOf(
                            "active" to prefs.getBoolean("native_session_active", false),
                            "startTime" to prefs.getLong("native_session_start_time", 0L),
                            "endTime" to prefs.getLong("native_session_end_time", 0L),
                            "lastHeartbeat" to prefs.getLong("native_last_heartbeat", 0L)
                        )
                        result.success(status)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)

        val apps = mutableListOf<Map<String, String>>()
        val seenPackages = mutableSetOf<String>()

        for (info in resolveInfos) {
            val packageName = info.activityInfo.packageName
            if (packageName == applicationContext.packageName) continue
            if (seenPackages.contains(packageName)) continue
            seenPackages.add(packageName)
            val appName = info.loadLabel(pm).toString()
            apps.add(mapOf("name" to appName, "packageName" to packageName))
        }
        return apps.sortedBy { it["name"] }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = "$packageName/${BlockerAccessibilityService::class.java.canonicalName}"
        val enabledServicesSetting = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(expectedComponentName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
