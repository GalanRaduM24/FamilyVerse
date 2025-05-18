package com.example.familyverse

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.graphics.BitmapFactory
import android.util.Base64
import java.util.*

class FamilyVerseWidget : AppWidgetProvider() {
    companion object {
        fun forceUpdate(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, FamilyVerseWidget::class.java)
            )
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, android.R.id.list)
            appWidgetManager.updateAppWidget(appWidgetIds, null)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Get data from shared preferences
        val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Debug logging
        System.out.println("Widget Debug - Reading from FlutterSharedPreferences")
        System.out.println("Widget Debug - All keys: ${sharedPrefs.all.keys.joinToString()}")
        
        // Get latest comic data (handle double flutter. prefix)
        val comicTitle = sharedPrefs.getString("flutter.flutter.featured_memory_title", null)
        val comicImage = sharedPrefs.getString("flutter.flutter.featured_memory_image", null)
        
        // Get today's picture status
        val lastPictureDate = sharedPrefs.getLong("flutter.flutter.last_picture_date", 0)
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startOfDay = calendar.timeInMillis
        val hasPictureToday = lastPictureDate >= startOfDay

        // Debug logging
        System.out.println("Widget Debug - Comic Title: $comicTitle")
        System.out.println("Widget Debug - Comic Image: $comicImage")
        System.out.println("Widget Debug - Last Picture Date: $lastPictureDate")
        System.out.println("Widget Debug - Has Picture Today: $hasPictureToday")

        // Update each widget
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.familyverse_widget)
            
            // Set up the click intent to open the app
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            
            // Update comic cover and title
            if (comicTitle != null && comicImage != null) {
                try {
                    // Load and display the comic cover
                    val imageBytes = Base64.decode(comicImage.split(",")[1], Base64.DEFAULT)
                    val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                    views.setImageViewBitmap(R.id.comic_cover, bitmap)
                    views.setTextViewText(R.id.comic_title, comicTitle)
                    System.out.println("Widget Debug - Successfully updated comic cover")
                } catch (e: Exception) {
                    System.out.println("Widget Debug - Error loading comic cover: ${e.message}")
                    e.printStackTrace()
                    // Show placeholder if there's an error
                    views.setImageViewResource(R.id.comic_cover, R.drawable.placeholder_memory)
                    views.setTextViewText(R.id.comic_title, "No comics yet")
                }
            } else {
                // Show placeholder if no comic data
                views.setImageViewResource(R.id.comic_cover, R.drawable.placeholder_memory)
                views.setTextViewText(R.id.comic_title, "No comics yet")
            }
            
            // Update today's picture status
            views.setTextViewText(
                R.id.today_status,
                if (hasPictureToday) "Picture taken today! 📸" else "Take a picture today! 📸"
            )
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }
} 