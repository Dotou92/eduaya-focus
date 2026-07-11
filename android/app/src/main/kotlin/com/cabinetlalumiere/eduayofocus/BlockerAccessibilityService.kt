package com.cabinetlalumiere.eduayofocus

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

class BlockerAccessibilityService : AccessibilityService() {

    private var lastToastPackage: String? = null
    private var lastToastTime: Long = 0

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
            // Le blocage s'exécute SYSTÉMATIQUEMENT, sans exception,
            // à chaque tentative d'ouverture détectée.
            performGlobalAction(GLOBAL_ACTION_HOME)
            showToastIfNeeded(packageName)
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

    /**
     * Le message visuel est limité à un affichage toutes les 2 secondes
     * par app pour éviter le spam, mais ceci n'affecte JAMAIS le blocage
     * lui-même, qui s'exécute toujours.
     */
    private fun showToastIfNeeded(packageName: String) {
        val now = System.currentTimeMillis()
        if (packageName == lastToastPackage && now - lastToastTime < 2000) return

        lastToastPackage = packageName
        lastToastTime = now

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
