package com.mille.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Canal Android 8+ aligné sur [AndroidManifest] default_notification_channel_id
 * et sur le backend FCM (channelId: mille_services_default).
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "mille_services_default",
                "Mille Services",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alertes et messages de l'application"
                enableVibration(true)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
