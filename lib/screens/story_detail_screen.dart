import 'package:flutter/material.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'animation_screen.dart';
import 'package:geolocator/geolocator.dart';

class StoryDetailScreen extends StatelessWidget {
  final Story story;

  const StoryDetailScreen({
    super.key,
    required this.story,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with story title and style
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                story.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image from first page
                  story.pages.first.imageUrl.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(story.pages.first.imageUrl.split(',')[1]),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $error');
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.error_outline, size: 50),
                              ),
                            );
                          },
                        )
                      : Image.network(
                          story.pages.first.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $error');
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.error_outline, size: 50),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (story.isPublished) ...[
                IconButton(
                  icon: const Icon(Icons.animation),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimationScreen(story: story),
                      ),
                    );
                  },
                  tooltip: 'Transform to Animation',
                ),
              ],
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Implement share functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {
                  // TODO: Implement bookmark functionality
                },
              ),
            ],
          ),
          // Story metadata
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Style and date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          story.style.toString().split('.').last,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Created ${_formatDate(story.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (story.prompt != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Story Prompt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        story.prompt!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Comic pages
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final page = story.pages[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page number
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          bottom: 8,
                        ),
                        child: Text(
                          'Page ${page.pageNumber}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Page image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: page.imageUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(page.imageUrl.split(',')[1]),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading image: $error');
                                  return Container(
                                    height: 300,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.error_outline, size: 50),
                                    ),
                                  );
                                },
                              )
                            : Image.network(
                                page.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 300,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading image: $error');
                                  return Container(
                                    height: 300,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.error_outline, size: 50),
                                    ),
                                  );
                                },
                              ),
                      ),
                      // Generated text
                      if (page.generatedText != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            page.generatedText!,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      // Timestamp
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _formatTime(page.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: story.pages.length,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement edit functionality
        },
        icon: const Icon(Icons.edit),
        label: const Text('Edit Story'),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              Consumer<StoryService>(
                builder: (context, storyService, child) {
                  return ElevatedButton.icon(
                    onPressed: story.isPublished ? null : () async {
                      try {
                        // Get current location
                        LocationPermission permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                          if (permission == LocationPermission.denied) {
                            throw Exception('Location permission denied');
                          }
                        }

                        final position = await Geolocator.getCurrentPosition();
                        
                        // Publish story with location
                        await storyService.publishStory(
                          story,
                          latitude: position.latitude,
                          longitude: position.longitude,
                        );
                        
                        if (!context.mounted) return;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Story published successfully with location!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        
                        // Navigate back to home page
                        Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error publishing story: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: Icon(story.isPublished ? Icons.check_circle : Icons.publish),
                    label: Text(story.isPublished ? 'Published' : 'Publish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: story.isPublished 
                          ? Colors.grey 
                          : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
} 