package com.cabinetlalumiere.eduayofocus

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cabinetlalumiere.eduayofocus/accessibility"
    private val SESSION_CHANNEL = "com.cabinetlalumiere.eduayofocus/session"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    "getInstalledApps" -> {
                        result.success(getInstalledApps())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSession" -> {
                        val minutes = call.argument<Int>("minutes") ?: 30
                        val intent = Intent(this, SessionForegroundService::class.java)
                        intent.putExtra("minutes", minutes)
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stopSession" -> {
                        val intent = Intent(this, SessionForegroundService::class.java)
                        stopService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Retourne la liste des applications installées ayant une icône
     * de lancement (donc visibles par l'utilisateur), sous forme de
     * liste de Map(name, packageName).
     */
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
