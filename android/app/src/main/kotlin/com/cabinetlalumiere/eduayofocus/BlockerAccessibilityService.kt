package com.cabinetlalumiere.eduayofocus

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import java.util.Calendar

class BlockerAccessibilityService : AccessibilityService() {

    private val defaultBlockedPackages = setOf(
        "com.facebook.katana",        // Facebook
        "com.facebook.lite",          // Facebook Lite
        "com.facebook.orca",          // Messenger
        "com.facebook.mlite",         // Messenger Lite
        "com.instagram.android",      // Instagram
        "com.instagram.lite",         // Instagram Lite
        "com.zhiliaoapp.musically",   // TikTok
        "com.zhiliaoapp.musically.go",// TikTok Lite
        "com.ss.android.ugc.trill",   // TikTok (variante internationale)
        "com.twitter.android",        // Twitter / X
        "com.snapchat.android",       // Snapchat
        "com.google.android.youtube", // YouTube
        "com.google.android.apps.youtube.music" // YouTube Music (optionnel)
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
            nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
    }

    private fun getBlockedApps(prefs: SharedPreferences): Set<String> {
        val stored = prefs.getString("flutter.blocked_apps", null)
        return if (stored.isNullOrEmpty()) {
            defaultBlockedPackages
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
            "EduAya Focus : application bloquée pendant les heures d'étude 📚",
            Toast.LENGTH_SHORT
        ).show()
    }

    override fun onInterrupt() {}

    override fun onServiceConnected() {
        super.onServiceConnected()
        Toast.makeText(
            applicationContext,
            "EduAya Focus est actif",
            Toast.LENGTH_SHORT
        ).show()
    }
}
