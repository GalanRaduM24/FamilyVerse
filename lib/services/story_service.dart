import 'package:flutter/foundation.dart';
import '../models/story.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class StoryService extends ChangeNotifier {
  List<Story> _publishedStories = [];
  List<Story> _albumStories = [];
  static const platform = MethodChannel('com.example.familyverse/widget');

  List<Story> get publishedStories => List.unmodifiable(_publishedStories);
  List<Story> get albumStories => List.unmodifiable(_albumStories);

  StoryService() {
    _loadStories();
    _updateWidgetWithLatestStory();
  }

  Future<void> _migrateOldData(SharedPreferences prefs) async {
    try {
      // Check if migration is needed
      final needsMigration = prefs.containsKey('published_stories') || 
                           prefs.containsKey('album_stories') ||
                           prefs.containsKey('featured_memory_title') ||
                           prefs.containsKey('last_picture_date');

      if (needsMigration) {
        print('Migrating old SharedPreferences data to new format...');

        // Migrate published stories
        final oldPublishedStories = prefs.getStringList('published_stories');
        if (oldPublishedStories != null) {
          await prefs.setStringList('flutter.published_stories', oldPublishedStories);
          await prefs.remove('published_stories');
        }

        // Migrate album stories
        final oldAlbumStories = prefs.getStringList('album_stories');
        if (oldAlbumStories != null) {
          await prefs.setStringList('flutter.album_stories', oldAlbumStories);
          await prefs.remove('album_stories');
        }

        // Migrate featured memory data
        final oldTitle = prefs.getString('featured_memory_title');
        if (oldTitle != null) {
          await prefs.setString('flutter.featured_memory_title', oldTitle);
          await prefs.remove('featured_memory_title');
        }

        final oldImage = prefs.getString('featured_memory_image');
        if (oldImage != null) {
          await prefs.setString('flutter.featured_memory_image', oldImage);
          await prefs.remove('featured_memory_image');
        }

        final oldDate = prefs.getInt('featured_memory_date');
        if (oldDate != null) {
          await prefs.setInt('flutter.featured_memory_date', oldDate);
          await prefs.remove('featured_memory_date');
        }

        final oldLastPictureDate = prefs.getInt('last_picture_date');
        if (oldLastPictureDate != null) {
          await prefs.setInt('flutter.last_picture_date', oldLastPictureDate);
          await prefs.remove('last_picture_date');
        }

        print('Migration completed successfully');
      }
    } catch (e) {
      print('Error during data migration: $e');
    }
  }

  Future<void> _loadStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Migrate old data if needed
      await _migrateOldData(prefs);
      
      // Load published stories
      final publishedStoriesJson = prefs.getStringList('flutter.published_stories') ?? [];
      _publishedStories = publishedStoriesJson
          .map((json) => Story.fromJson(jsonDecode(json)))
          .toList();

      // Load album stories
      final albumStoriesJson = prefs.getStringList('flutter.album_stories') ?? [];
      _albumStories = albumStoriesJson
          .map((json) => Story.fromJson(jsonDecode(json)))
          .toList();

      // Update widget with latest comic
      if (_albumStories.isNotEmpty) {
        final latestComic = _albumStories.first;
        if (latestComic.pages.isNotEmpty) {
          final coverPage = latestComic.pages.first;
          print('Updating widget with latest comic: ${latestComic.title}');
          print('Comic pages: ${latestComic.pages.length}');
          print('Cover page image URL: ${coverPage.imageUrl}');
          
          await prefs.setString('featured_memory_title', latestComic.title);
          await prefs.setString('featured_memory_image', coverPage.imageUrl);

          // Force widget update
          try {
            await platform.invokeMethod('updateWidget');
            print('Widget update triggered successfully with latest comic');
          } catch (e) {
            print('Error updating widget: $e');
          }
        } else {
          print('Latest comic has no pages');
        }
      } else {
        print('No comics found in album');
      }

      notifyListeners();
    } catch (e) {
      print('Error loading stories: $e');
    }
  }

  Future<void> _saveStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save published stories
      final publishedStoriesJson = _publishedStories
          .map((story) => jsonEncode(story.toJson()))
          .toList();
      await prefs.setStringList('flutter.published_stories', publishedStoriesJson);

      // Save album stories
      final albumStoriesJson = _albumStories
          .map((story) => jsonEncode(story.toJson()))
          .toList();
      await prefs.setStringList('flutter.album_stories', albumStoriesJson);
    } catch (e) {
      print('Error saving stories: $e');
    }
  }

  Future<void> publishStory(Story story, {double? latitude, double? longitude}) async {
    try {
      // Create a copy of the story with published status and location
      final publishedStory = Story(
        id: story.id,
        title: story.title,
        createdAt: story.createdAt,
        pages: story.pages,
        style: story.style,
        prompt: story.prompt,
        tags: story.tags,
        isMultiPage: story.isMultiPage,
        isPublished: true,
        publishedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      // Add to published stories (Home page)
      _publishedStories.insert(0, publishedStory);
      
      // Add to album stories
      _albumStories.insert(0, publishedStory);

      // Save stories to persistent storage
      await _saveStories();

      // Update widget with the new story
      final prefs = await SharedPreferences.getInstance();
      if (publishedStory.pages.isNotEmpty) {
        final firstPage = publishedStory.pages.first;
        print('Updating widget with story: ${publishedStory.title}');
        print('Image URL: ${firstPage.imageUrl}');
        
        // Save story data for widget (Flutter adds flutter. prefix automatically)
        await prefs.setString('featured_memory_title', publishedStory.title);
        await prefs.setString('featured_memory_image', firstPage.imageUrl);

        // Force widget update
        try {
          await platform.invokeMethod('updateWidget');
          print('Widget update triggered successfully');
        } catch (e) {
          print('Error updating widget: $e');
        }
      } else {
        print('No pages in story to update widget');
      }

      notifyListeners();
      return Future.value();
    } catch (e) {
      print('Error publishing story: $e');
      return Future.error(e);
    }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      _publishedStories.removeWhere((story) => story.id == storyId);
      _albumStories.removeWhere((story) => story.id == storyId);
      await _saveStories();
      notifyListeners();
      return Future.value();
    } catch (e) {
      print('Error deleting story: $e');
      return Future.error(e);
    }
  }

  Future<void> updateLastPictureDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_picture_date', DateTime.now().millisecondsSinceEpoch);
      
      // Force widget update to show new picture status
      try {
        await platform.invokeMethod('updateWidget');
        print('Widget update triggered after taking picture');
      } catch (e) {
        print('Error updating widget: $e');
      }
      
      notifyListeners();
    } catch (e) {
      print('Error updating last picture date: $e');
    }
  }

  Future<void> _updateWidgetWithLatestStory() async {
    try {
      if (_publishedStories.isNotEmpty) {
        final latestStory = _publishedStories.first;
        if (latestStory.pages.isNotEmpty) {
          final firstPage = latestStory.pages.first;
          print('Updating widget with latest story: ${latestStory.title}');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('featured_memory_title', latestStory.title);
          await prefs.setString('featured_memory_image', firstPage.imageUrl);
          
          // Handle timestamp with null safety
          final timestamp = latestStory.publishedAt?.millisecondsSinceEpoch ?? 
                          latestStory.createdAt.millisecondsSinceEpoch;
          await prefs.setInt('featured_memory_date', timestamp ~/ 1000);

          // Force widget update
          try {
            await platform.invokeMethod('updateWidget');
            print('Widget update triggered successfully with latest story');
          } catch (e) {
            print('Error updating widget: $e');
          }
        }
      }
    } catch (e) {
      print('Error updating widget with latest story: $e');
    }
  }
} 