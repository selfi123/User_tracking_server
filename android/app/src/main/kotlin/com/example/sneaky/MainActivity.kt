package com.example.sneaky

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create a notification channel for the foreground service on Android O and above.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "location_service"
            val channelName = "Location Tracking"
            val channelDescription = "Background service for location tracking"
            val importance = NotificationManager.IMPORTANCE_LOW

            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
}
