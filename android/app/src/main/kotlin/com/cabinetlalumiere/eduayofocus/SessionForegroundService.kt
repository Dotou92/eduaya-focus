package com.cabinetlalumiere.eduayofocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder

/**
 * Service de premier plan qui garde EduAya Focus "vivant" pendant une
 * session de concentration active, via une notification persistante.
 * C'est cette notification qui empêche Android (notamment Honor/Magic UI)
 * de tuer le service d'accessibilité pendant la session.
 */
class SessionForegroundService : Service() {

    private var countDownTimer: CountDownTimer? = null
    private val CHANNEL_ID = "eduaya_focus_session_channel"
    private val NOTIFICATION_ID = 1001

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val minutes = intent?.getIntExtra("minutes", 30) ?: 30
        val totalMillis = minutes * 60 * 1000L

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(formatTime(totalMillis)))

        // Marque la session comme active dans les préférences partagées
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("flutter.session_active", true)
            .putLong("flutter.session_end_time", System.currentTimeMillis() + totalMillis)
            .apply()

        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer(totalMillis, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val notification = buildNotification(formatTime(millisUntilFinished))
                val manager = getSystemService(NotificationManager::class.java)
                manager.notify(NOTIFICATION_ID, notification)
            }

            override fun onFinish() {
                val prefs2 = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs2.edit().putBoolean("flutter.session_active", false).apply()
                stopSelf()
            }
        }.start()

        return START_STICKY
    }

    private fun formatTime(millis: Long): String {
        val totalSeconds = millis / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    private fun buildNotification(timeText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("EduAya Focus - Session en cours")
            .setContentText("Temps restant : $timeText")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Session de concentration",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Affiche le temps restant pendant une session de concentration"
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        countDownTimer?.cancel()
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.session_active", false).apply()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
