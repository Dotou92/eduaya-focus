package com.cabinetlalumiere.eduayofocus

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

/**
 * Service d'accessibilité qui surveille l'application au premier plan.
 * Bloque uniquement pendant une SESSION ACTIVE (démarrée manuellement
 * par l'élève depuis l'app), et uniquement les applications qu'il a
 * lui-même sélectionnées pour cette session.
 */
class BlockerAccessibilityService : AccessibilityService() {

    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val sessionActive = prefs.getBoolean("flutter.session_active", false)
        if (!sessionActive) return

        val blockedApps = getBlockedApps(prefs)
        if (packageName in blockedApps) {
            blockApp(packageName)
        }
    }

    private fun getBlockedApps(prefs: SharedPreferences): Set<String> {
        val stored = prefs.getString("flutter.blocked_apps", null)
        return if (stored.isNullOrEmpty()) {
            emptySet()
        } else {
            stored.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
        }
    }

    private fun blockApp(packageName: String) {
        val now = System.currentTimeMillis()
        if (packageName == lastBlockedPackage && now - lastBlockTime < 2000) return

        lastBlockedPackage = packageName
        lastBlockTime = now

        performGlobalAction(GLOBAL_ACTION_HOME)

        Toast.makeText(
            applicationContext,
            "EduAya Focus : application bloquée pendant votre session 📚",
            Toast.LENGTH_SHORT
        ).show()
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
    }
}
