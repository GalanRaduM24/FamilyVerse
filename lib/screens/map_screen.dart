import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/story_service.dart';
import '../models/story.dart';
import '../widgets/shared_map.dart';
import 'dart:convert';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Locations'),
      ),
      body: Consumer<StoryService>(
        builder: (context, storyService, child) {
          final stories = storyService.publishedStories;
          return SharedMap(
            stories: stories,
            onStoryTap: (story) {
              _showStoryDetails(story);
            },
          );
        },
      ),
    );
  }

  void _showStoryDetails(Story story) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              story.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (story.prompt != null) ...[
              Text(story.prompt!),
              const SizedBox(height: 8),
            ],
            if (story.pages.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: story.pages.first.imageUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(story.pages.first.imageUrl.split(',')[1]),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        story.pages.first.imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Created: ${_formatDate(story.createdAt)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 