package com.example.familyverse

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.*

class FamilyVerseWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Initialize Flutter engine for the widget
        val flutterEngine = FlutterEngine(context)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
    }

    override fun onDisabled(context: Context) {
        // Clean up Flutter engine
    }

    companion object {
        // Add this method to test the widget
        fun forceUpdate(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, FamilyVerseWidget::class.java)
            )
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
            Toast.makeText(context, "Widget updated!", Toast.LENGTH_SHORT).show()
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Construct the RemoteViews object
            val views = RemoteViews(context.packageName, R.layout.familyverse_widget)

            // Set up the click intent for the widget
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Get featured memory from shared preferences
            val sharedPrefs = context.getSharedPreferences("familyverse_prefs", Context.MODE_PRIVATE)
            val memoryTitle = sharedPrefs.getString("featured_memory_title", "No memories yet")
            val memoryImage = sharedPrefs.getString("featured_memory_image", null)
            val memoryAuthor = sharedPrefs.getString("featured_memory_author", "Family")
            val memoryDate = sharedPrefs.getLong("featured_memory_date", System.currentTimeMillis())
            val memoryLikes = sharedPrefs.getInt("featured_memory_likes", 0)

            // Update memory title
            views.setTextViewText(R.id.memory_title, memoryTitle)

            // Update memory image if available
            if (memoryImage != null) {
                // TODO: Load image from URL using Glide or similar
                // For now, we'll use a placeholder
                views.setImageViewResource(R.id.memory_image, R.drawable.placeholder_memory)
            } else {
                views.setImageViewResource(R.id.memory_image, R.drawable.placeholder_memory)
            }

            // Format and update memory date
            val dateFormat = java.text.SimpleDateFormat("MMM d", Locale.getDefault())
            val timeAgo = _getTimeAgo(memoryDate)
            views.setTextViewText(R.id.memory_date, "Shared by $memoryAuthor • $timeAgo")

            // Update memory likes
            views.setTextViewText(R.id.memory_likes, "$memoryLikes family members loved this")

            // Check if picture was taken today
            val lastPictureDate = sharedPrefs.getLong("last_picture_date", 0)
            val calendar = Calendar.getInstance()
            val today = calendar.timeInMillis
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val startOfDay = calendar.timeInMillis
            
            val hasPictureToday = lastPictureDate >= startOfDay
            
            if (hasPictureToday) {
                views.setViewVisibility(R.id.bereal_status, View.VISIBLE)
                views.setTextViewText(R.id.bereal_text, "Picture taken today! 📸")
            } else {
                views.setViewVisibility(R.id.bereal_status, View.VISIBLE)
                views.setTextViewText(R.id.bereal_text, "Take a picture today! 📸")
            }

            // Instruct the widget manager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun _getTimeAgo(timestamp: Long): String {
            val now = System.currentTimeMillis()
            val diff = now - timestamp

            return when {
                diff < 60 * 1000 -> "just now"
                diff < 60 * 60 * 1000 -> "${diff / (60 * 1000)}m ago"
                diff < 24 * 60 * 60 * 1000 -> "${diff / (60 * 60 * 1000)}h ago"
                diff < 7 * 24 * 60 * 60 * 1000 -> "${diff / (24 * 60 * 60 * 1000)}d ago"
                else -> java.text.SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(timestamp))
            }
        }
    }
} 