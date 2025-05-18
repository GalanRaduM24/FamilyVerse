package com.example.familyverse

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.familyverse/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    FamilyVerseWidget.forceUpdate(context)
                    result.success(null)
                }
                "updateFeaturedMemory" -> {
                    val title = call.argument<String>("title")
                    val imageUrl = call.argument<String>("imageUrl")
                    val author = call.argument<String>("author")
                    val likes = call.argument<Int>("likes") ?: 0

                    val sharedPrefs = context.getSharedPreferences("familyverse_prefs", Context.MODE_PRIVATE)
                    sharedPrefs.edit().apply {
                        title?.let { putString("featured_memory_title", it) }
                        imageUrl?.let { putString("featured_memory_image", it) }
                        author?.let { putString("featured_memory_author", it) }
                        putLong("featured_memory_date", System.currentTimeMillis())
                        putInt("featured_memory_likes", likes)
                    }.apply()

                    // Update the widget
                    FamilyVerseWidget.forceUpdate(context)
                    result.success(null)
                }
                "pictureTaken" -> {
                    // Save the current time as the last picture date
                    val sharedPrefs = context.getSharedPreferences("familyverse_prefs", Context.MODE_PRIVATE)
                    sharedPrefs.edit().putLong("last_picture_date", System.currentTimeMillis()).apply()
                    // Update the widget
                    FamilyVerseWidget.forceUpdate(context)
                    result.success(null)
                }
                "updateNearbyStories" -> {
                    val count = call.argument<Int>("count") ?: 0
                    val sharedPrefs = context.getSharedPreferences("familyverse_prefs", Context.MODE_PRIVATE)
                    sharedPrefs.edit().putInt("nearby_stories", count).apply()
                    // Update the widget
                    FamilyVerseWidget.forceUpdate(context)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
