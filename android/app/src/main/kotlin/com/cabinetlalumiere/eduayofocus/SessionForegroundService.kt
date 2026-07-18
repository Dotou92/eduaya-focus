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
import java.text.SimpleDateFormat
import java.util.*

/**
 * Service de premier plan : garde une notification persistante visible
 * avec les VRAIES heures de début/fin (pas un simple compte à rebours),
 * et enregistre un "heartbeat" régulier permettant de détecter une
 * interruption (app gelée/tuée) une fois la session reprise.
 */
class SessionForegroundService : Service() {

    private var countDownTimer: CountDownTimer? = null
    private val CHANNEL_ID = "eduaya_focus_session_channel"
    private val NOTIFICATION_ID = 1001
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val timeFormat = SimpleDateFormat("HH:mm", Locale.FRANCE)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val endHour = intent?.getIntExtra("endHour", 17) ?: 17
        val endMinute = intent?.getIntExtra("endMinute", 0) ?: 0

        val now = Calendar.getInstance()
        val startMillis = now.timeInMillis

        val endCal = Calendar.getInstance()
        endCal.set(Calendar.HOUR_OF_DAY, endHour)
        endCal.set(Calendar.MINUTE, endMinute)
        endCal.set(Calendar.SECOND, 0)
        endCal.set(Calendar.MILLISECOND, 0)
        if (endCal.timeInMillis <= startMillis) {
            endCal.add(Calendar.DAY_OF_MONTH, 1)
        }
        val endMillis = endCal.timeInMillis
        val totalMillis = endMillis - startMillis

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("native_session_active", true)
            .putLong("native_session_start_time", startMillis)
            .putLong("native_session_end_time", endMillis)
            .putLong("native_last_heartbeat", startMillis)
            .apply()

        createNotificationChannel()
        startForeground(
            NOTIFICATION_ID,
            buildNotification(startMillis, endMillis, totalMillis)
        )

        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer(totalMillis, 15000) {
            override fun onTick(millisUntilFinished: Long) {
                val heartbeatPrefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                heartbeatPrefs.edit()
                    .putLong("native_last_heartbeat", System.currentTimeMillis())
                    .apply()

                val manager = getSystemService(NotificationManager::class.java)
                manager.notify(
                    NOTIFICATION_ID,
                    buildNotification(startMillis, endMillis, millisUntilFinished)
                )
            }

            override fun onFinish() {
                val finishPrefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                finishPrefs.edit()
                    .putBoolean("native_session_active", false)
                    .putLong("native_last_heartbeat", System.currentTimeMillis())
                    .apply()
                stopSelf()
            }
        }.start()

        return START_STICKY
    }

    private fun buildNotification(
        startMillis: Long,
        endMillis: Long,
        millisRemaining: Long
    ): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val startText = timeFormat.format(Date(startMillis))
        val endText = timeFormat.format(Date(endMillis))
        val minutesLeft = (millisRemaining / 60000).toInt()

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("EduAya Focus : session $startText - $endText")
            .setContentText("Temps restant : environ $minutesLeft min")
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
            channel.description = "Affiche les heures de la session en cours"
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        countDownTimer?.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
