package com.cabinetlalumiere.eduayofocus

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import java.util.Calendar

/**
 * Service d'accessibilité qui surveille l'application au premier plan.
 * Si l'application appartient à la liste des apps bloquées ET que
 * l'heure actuelle est dans le créneau d'étude configuré, l'utilisateur
 * est automatiquement renvoyé à l'écran d'accueil.
 *
 * Configuration lue depuis les SharedPreferences partagées avec Flutter
 * (fichier "FlutterSharedPreferences", clés préfixées "flutter.").
 */
class BlockerAccessibilityService : AccessibilityService() {

    // Liste par défaut (Phase 1 - preuve de concept). Sera remplacée
    // en Phase 2 par une liste configurable depuis l'app Flutter.
    private val defaultBlockedPackages = setOf(
        "com.facebook.katana",       // Facebook
        "com.instagram.android",     // Instagram
        "com.zhiliaoapp.musically",  // TikTok
        "com.twitter.android",       // Twitter / X
        "com.snapchat.android",      // Snapchat
        "com.google.android.youtube" // YouTube (optionnel)
    )

    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val blockingEnabled = prefs.getBoolean("flutter.blocking_enabled", false)
        if (!blockingEnabled) return

        if (!isWithinStudySchedule(prefs)) return

        val blockedApps = getBlockedApps(prefs)
        if (packageName in blockedApps) {
            blockApp(packageName)
        }
    }

    /**
     * Vérifie si l'heure actuelle se situe dans le créneau d'étude.
     * Valeurs par défaut : 08h00 - 17h00 si non configurées.
     */
    private fun isWithinStudySchedule(prefs: SharedPreferences): Boolean {
        val startHour = prefs.getInt("flutter.study_start_hour", 8)
        val startMinute = prefs.getInt("flutter.study_start_minute", 0)
        val endHour = prefs.getInt("flutter.study_end_hour", 17)
        val endMinute = prefs.getInt("flutter.study_end_minute", 0)

        val now = Calendar.getInstance()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val startMinutes = startHour * 60 + startMinute
        val endMinutes = endHour * 60 + endMinute

        return if (startMinutes <= endMinutes) {
            nowMinutes in startMinutes..endMinutes
        } else {
            // Créneau qui traverse minuit (ex: 20h - 02h)
            nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
    }

    /**
     * Lit la liste des apps à bloquer depuis les préférences.
     * Format attendu : chaîne séparée par des virgules.
     * Retombe sur la liste par défaut si rien n'est configuré.
     */
    private fun getBlockedApps(prefs: SharedPreferences): Set<String> {
        val stored = prefs.getString("flutter.blocked_apps", null)
        return if (stored.isNullOrEmpty()) {
            defaultBlockedPackages
        } else {
            stored.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
        }
    }

    /**
     * Renvoie l'utilisateur à l'écran d'accueil et affiche un message.
     * Anti-spam : évite de redéclencher en boucle sur le même package
     * dans un intervalle de moins de 2 secondes.
     */
    private fun blockApp(packageName: String) {
        val now = System.currentTimeMillis()
        if (packageName == lastBlockedPackage && now - lastBlockTime < 2000) return

        lastBlockedPackage = packageName
        lastBlockTime = now

        performGlobalAction(GLOBAL_ACTION_HOME)

        Toast.makeText(
            applicationContext,
            "EduAyo Focus : application bloquée pendant les heures d'étude 📚",
            Toast.LENGTH_SHORT
        ).show()
    }

    override fun onInterrupt() {
        // Requis par AccessibilityService, rien à faire ici.
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Toast.makeText(
            applicationContext,
            "EduAyo Focus est actif",
            Toast.LENGTH_SHORT
        ).show()
    }
}
