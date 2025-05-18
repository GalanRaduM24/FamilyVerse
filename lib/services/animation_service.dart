import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/story.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

class AnimationService {
  static const String _baseUrl = 'https://api.stability.ai/v2beta/stable-video';
  final String _apiKey = dotenv.env['STABILITY_API_KEY'] ?? '';
  static const int _maxRetries = 1;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _pollingInterval = Duration(seconds: 5);
  static const Duration _timeout = Duration(minutes: 5);

  // Target dimensions for the API
  static const int _targetWidth = 1024;
  static const int _targetHeight = 576;

  Future<String> generateAnimation(Story story) async {
    if (_apiKey.isEmpty) {
      throw Exception('Stability AI API key not found. Please add STABILITY_API_KEY to your .env file.');
    }

    if (story.pages.isEmpty) {
      throw Exception('No images available in the story');
    }

    // Get the first image URL from the story
    final imageUrl = story.pages[0].imageUrl;
    if (imageUrl.isEmpty) {
      throw Exception('Image URL is empty');
    }

    // Handle base64 image URLs
    List<int> imageBytes;
    String contentType;
    
    try {
      if (imageUrl.startsWith('data:')) {
        // Handle base64 data URL
        final parts = imageUrl.split(',');
        if (parts.length != 2) {
          throw Exception('Invalid base64 image URL format');
        }
        
        final mimeType = parts[0].split(':')[1].split(';')[0];
        if (!mimeType.startsWith('image/')) {
          throw Exception('Invalid image MIME type: $mimeType');
        }
        
        contentType = mimeType;
        try {
          imageBytes = base64Decode(parts[1]);
        } catch (e) {
          throw Exception('Invalid base64 image data');
        }
      } else {
        // Handle regular URL
        final imageResponse = await http.get(Uri.parse(imageUrl));
        if (imageResponse.statusCode != 200) {
          throw Exception('Failed to download image: ${imageResponse.statusCode}');
        }
        imageBytes = imageResponse.bodyBytes;
        contentType = imageResponse.headers['content-type'] ?? 'image/jpeg';
        
        if (!contentType.startsWith('image/')) {
          throw Exception('Invalid content type: $contentType');
        }
      }

      // Validate image size
      if (imageBytes.length > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('Image size exceeds 10MB limit');
      }

      // Resize image to match API requirements
      imageBytes = await _resizeImage(imageBytes, contentType);
    } catch (e) {
      throw Exception('Error processing image: $e');
    }

    // Send the request with retries
    http.Response? response;
    Exception? lastError;
    
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // Create a new request for each attempt
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/generate'),
        );

        // Add headers
        request.headers.addAll({
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        });

        // Add image file
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'image.${contentType.split('/')[1]}',
            contentType: MediaType.parse(contentType),
          ),
        );

        // Add other parameters
        request.fields.addAll({
          'text_prompts': jsonEncode([
            {
              'text': _createAnimationPrompt(story),
              'weight': 1.0
            },
            {
              'text': 'blurry, low quality, distorted, deformed, ugly, bad anatomy',
              'weight': -1.0
            }
          ]),
          'cfg_scale': '7.5',
          'motion_bucket_id': '127',
          'seed': (DateTime.now().millisecondsSinceEpoch % 1000000).toString(),
          'height': '$_targetHeight',
          'width': '$_targetWidth',
          'fps': '24',
          'duration': '4',
          'style_preset': _getStyleForStory(story.style.toString().split('.').last),
        });

        // Print request details for debugging
        print('Sending request with image size: ${imageBytes.length} bytes');
        print('Content-Type: $contentType');
        print('Request fields: ${request.fields}');

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
        
        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.body}');
        
        if (response.statusCode == 200 || response.statusCode == 202) {
          break;
        } else if (response.statusCode == 429) {
          // Rate limit hit, wait longer
          await Future.delayed(_retryDelay * (attempt + 1));
          continue;
        } else {
          throw Exception('API request failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        lastError = Exception('Attempt ${attempt + 1} failed: $e');
        print('Error during attempt ${attempt + 1}: $e');
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay);
        }
      }
    }

    if (response == null) {
      throw lastError ?? Exception('Failed to start generation after $_maxRetries attempts');
    }

    // Parse the response
    final responseData = jsonDecode(response.body);
    print('Parsed response data: $responseData');

    // Handle both 200 and 202 responses
    String? jobId;
    if (response.statusCode == 200) {
      // Direct success response
      if (responseData['output']?['video'] != null) {
        return responseData['output']['video'];
      }
      jobId = responseData['id'];
    } else if (response.statusCode == 202) {
      // Async processing response
      jobId = responseData['id'];
    }

    if (jobId == null) {
      throw Exception('No job ID found in response: ${response.body}');
    }

    print('Starting to poll for job ID: $jobId');

    // Poll for completion
    String? videoUrl;
    final startTime = DateTime.now();
    int consecutive404s = 0;
    const maxConsecutive404s = 3;
    
    while (DateTime.now().difference(startTime) < _timeout) {
      await Future.delayed(_pollingInterval);
      
      try {
        // Fixed URL format for status checking - using the correct endpoint
        final statusResponse = await http.get(
          Uri.parse('$_baseUrl/status/$jobId'),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Accept': 'application/json',
          },
        );

        print('Status check response: ${statusResponse.statusCode} - ${statusResponse.body}');

        if (statusResponse.statusCode == 200) {
          consecutive404s = 0; // Reset counter on successful response
          final statusData = jsonDecode(statusResponse.body);
          print('Status data: $statusData');  // Added more detailed logging
          
          switch (statusData['status']) {
            case 'succeeded':
              videoUrl = statusData['output']['video'];
              if (videoUrl == null || videoUrl.isEmpty) {
                throw Exception('Generated video URL is empty');
              }
              return videoUrl;
            case 'failed':
              throw Exception('Generation failed: ${statusData['message']}');
            case 'processing':
              print('Still processing...');  // Added status logging
              // Continue polling
              break;
            default:
              throw Exception('Unknown status: ${statusData['status']}');
          }
        } else if (statusResponse.statusCode == 404) {
          consecutive404s++;
          print('Received 404 response. Consecutive 404s: $consecutive404s');
          
          if (consecutive404s >= maxConsecutive404s) {
            throw Exception('Job not found after $maxConsecutive404s consecutive attempts. The job may have expired or been deleted.');
          }
          // Continue polling with a shorter delay for 404s
          await Future.delayed(const Duration(seconds: 2));
        } else {
          throw Exception('Failed to check status: ${statusResponse.statusCode}');
        }
      } catch (e) {
        // Log error but continue polling
        print('Error checking status: $e');
        if (e.toString().contains('Job not found')) {
          throw e; // Re-throw if it's a job not found error
        }
      }
    }

    throw Exception('Generation timed out after ${_timeout.inMinutes} minutes');
  }

  Future<List<int>> _resizeImage(List<int> imageBytes, String contentType) async {
    try {
      // Convert List<int> to Uint8List
      final Uint8List uint8List = Uint8List.fromList(imageBytes);
      
      // Decode the image
      final image = img.decodeImage(uint8List);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate new dimensions
      double aspectRatio = image.width / image.height;
      int newWidth, newHeight;

      // Choose dimensions based on aspect ratio
      if (aspectRatio > 1.5) { // Wider than 3:2
        // Use 1024x576
        newWidth = 1024;
        newHeight = 576;
      } else if (aspectRatio < 0.75) { // Taller than 3:4
        // Use 576x1024
        newWidth = 576;
        newHeight = 1024;
      } else {
        // Use 768x768 for more square images
        newWidth = 768;
        newHeight = 768;
      }

      // Resize the image
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode the resized image
      List<int> resizedBytes;
      if (contentType.contains('png')) {
        resizedBytes = img.encodePng(resized);
      } else {
        resizedBytes = img.encodeJpg(resized, quality: 90);
      }

      print('Original image size: ${image.width}x${image.height}');
      print('Original aspect ratio: $aspectRatio');
      print('Resized image size: ${newWidth}x${newHeight}');

      return resizedBytes;
    } catch (e) {
      throw Exception('Failed to resize image: $e');
    }
  }

  String _createAnimationPrompt(Story story) {
    final buffer = StringBuffer();
    
    // Add story context
    buffer.writeln('Create a cinematic animation with the following elements:');
    buffer.writeln('Title: ${story.title}');
    if (story.prompt != null) {
      buffer.writeln('Context: ${story.prompt}');
    }
    
    // Add scene descriptions for each page
    for (var page in story.pages) {
      buffer.writeln('\nScene ${page.pageNumber}:');
      if (page.generatedText != null) {
        buffer.writeln('Description: ${page.generatedText}');
      }
    }
    
    // Add animation instructions
    buffer.writeln('\nAnimation Requirements:');
    buffer.writeln('- Create smooth transitions between scenes');
    buffer.writeln('- Add subtle camera movements to bring static panels to life');
    buffer.writeln('- Include ambient sounds and background music');
    buffer.writeln('- Add voice narration with appropriate intonation');
    buffer.writeln('- Each scene should be 5-7 seconds long');
    buffer.writeln('- Total duration should be 30 seconds');
    
    return buffer.toString();
  }

  String _getStyleForStory(String style) {
    switch (style.toLowerCase()) {
      case 'comic':
        return 'comic-book';
      case 'anime':
        return 'anime';
      case 'realistic':
        return 'photographic';
      case 'watercolor':
        return 'watercolor';
      case 'sketch':
        return 'sketch';
      default:
        return 'cinematic';
    }
  }
} 