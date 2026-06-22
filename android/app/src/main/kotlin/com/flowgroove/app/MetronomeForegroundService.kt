package com.flowgroove.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class MetronomeForegroundService : Service() {

    private val binder = MetronomeBinder()
    private var engine: AndroidMetronomeEngine? = null
    private var currentBpm: Int = 0

    /** Set by the bound Activity to forward ticks to the Flutter channel. */
    var tickListener: ((Int) -> Unit)? = null
    var stoppedListener: (() -> Unit)? = null

    inner class MetronomeBinder : Binder() {
        fun getService(): MetronomeForegroundService = this@MetronomeForegroundService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        engine = AndroidMetronomeEngine(
            context = applicationContext,
            onTick = { index -> tickListener?.invoke(index) },
            onStopped = { stoppedListener?.invoke() }
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopPlayback()
                return START_NOT_STICKY
            }
            else -> startForegroundNotification()
        }
        return START_STICKY
    }

    fun startPlayback(args: Map<*, *>) {
        currentBpm = bpmFromArgs(args)
        startForegroundNotification()
        engine?.start(args)
    }

    fun updatePlayback(args: Map<*, *>) {
        currentBpm = bpmFromArgs(args)
        engine?.update(args)
        // Refresh the notification text with the new BPM.
        getSystemService(NotificationManager::class.java)
            ?.notify(NOTIFICATION_ID, buildNotification())
    }

    fun stopPlayback() {
        engine?.stop(notifyFlutter = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        engine?.dispose()
        engine = null
        tickListener = null
        stoppedListener = null
        super.onDestroy()
    }

    private fun startForegroundNotification() {
        createChannel()
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val contentPi = PendingIntent.getActivity(
            this, 0, openIntent ?: Intent(),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stopPi = PendingIntent.getService(
            this, 1,
            Intent(this, MetronomeForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val text = if (currentBpm > 0) "$currentBpm BPM" else "Playing"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Metronome")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(contentPi)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPi)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Metronome playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps the metronome playing in the background"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun bpmFromArgs(args: Map<*, *>): Int {
        // intervalMicros is per subdivision tick; bpm display is best-effort.
        val intervalMicros = (args["intervalMicros"] as? Number)?.toLong() ?: return 0
        if (intervalMicros <= 0) return 0
        return Math.round(60_000_000.0 / intervalMicros).toInt()
    }

    companion object {
        private const val TAG = "MetronomeFgService"
        private const val CHANNEL_ID = "metronome_playback"
        private const val NOTIFICATION_ID = 7711
        const val ACTION_START = "com.flowgroove.app.METRONOME_START"
        const val ACTION_STOP = "com.flowgroove.app.METRONOME_STOP"
    }
}
