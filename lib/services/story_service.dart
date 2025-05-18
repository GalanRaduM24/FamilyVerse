import 'package:flutter/foundation.dart';
import '../models/story.dart';

class StoryService extends ChangeNotifier {
  final List<Story> _publishedStories = [];
  final List<Story> _albumStories = [];

  List<Story> get publishedStories => List.unmodifiable(_publishedStories);
  List<Story> get albumStories => List.unmodifiable(_albumStories);

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
      notifyListeners();
      return Future.value();
    } catch (e) {
      print('Error deleting story: $e');
      return Future.error(e);
    }
  }
} 