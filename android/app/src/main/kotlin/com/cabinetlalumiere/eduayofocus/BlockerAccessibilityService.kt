package com.cabinetlalumiere.eduayofocus

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast

/**
 * VERSION DE DIAGNOSTIC TEMPORAIRE
 * Affiche un message à chaque changement d'application, sans condition
 * d'horaire ni de liste, pour vérifier que le service reçoit bien les
 * événements système.
 */
class BlockerAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return

        Toast.makeText(
            applicationContext,
            "DIAGNOSTIC: app ouverte = $packageName",
            Toast.LENGTH_SHORT
        ).show()
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        Toast.makeText(
            applicationContext,
            "EduAya Focus est actif (diagnostic)",
            Toast.LENGTH_SHORT
        ).show()
    }
}
