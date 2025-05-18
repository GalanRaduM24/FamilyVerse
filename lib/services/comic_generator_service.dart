import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/story.dart';
import '../config/api_config.dart';

class ComicGeneratorService {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  Future<Story> generateComic({
    required List<File> images,
    required ComicStyle style,
    String? prompt,
  }) async {
    int retryCount = 0;
    while (true) {
      try {
        print('Starting comic generation...');
        print('Number of images: ${images.length}');
        print('Style: $style');
        print('Original prompt: $prompt');

        if (images.isEmpty) {
          throw Exception('No images provided for comic generation');
        }

        // First, analyze all images to understand the story context
        List<String> imageDescriptions = [];
        for (int i = 0; i < images.length; i++) {
          try {
            final List<int> imageBytes = await images[i].readAsBytes();
            final String capturedImageBase64 = base64Encode(imageBytes);
            
            final Map<String, dynamic> analysisPayload = {
              'model': 'gpt-4o',
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are an expert at analyzing images. Provide a brief, focused description (max 50 words) of the key elements: main subject, pose, expression, setting, and mood. Focus only on elements that are essential for storytelling.'
                },
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Describe this image briefly, focusing only on the main subject, their pose, expression, and the essential setting elements. Keep it under 50 words.'
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$capturedImageBase64'
                      }
                    }
                  ]
                }
              ],
              'max_tokens': 100,
            };

            print('Analyzing image ${i + 1}...');
            final analysisResponse = await http.post(
              Uri.parse(ApiConfig.chatCompletionEndpoint),
              headers: ApiConfig.headers,
              body: json.encode(analysisPayload),
            );

            if (analysisResponse.statusCode == 200) {
              var analysisJson = json.decode(analysisResponse.body);
              String description = analysisJson['choices'][0]['message']['content'];
              // Ensure the description is concise
              if (description.length > 200) {
                description = description.substring(0, 200) + '...';
              }
              imageDescriptions.add(description);
              print('Image ${i + 1} analysis: ${imageDescriptions.last}');
            } else {
              print('Image analysis failed, using fallback description');
              imageDescriptions.add('A person in a thoughtful pose');
            }
          } catch (e) {
            print('Error during image analysis: $e');
            imageDescriptions.add('A family moment captured in a photo');
          }
        }

        // Generate a story outline based on all images and user prompt
        String storyOutline = '';
        try {
          final Map<String, dynamic> outlinePayload = {
            'model': 'gpt-4o',
            'messages': [
              {
                'role': 'system',
                'content': 'You are a comic book writer. Create a short story outline that connects these images into a cohesive narrative. The story should be family-friendly and engaging. Keep the outline under 100 words.'
              },
              {
                'role': 'user',
                'content': 'Create a story outline based on these images and the user prompt. The story should flow naturally and be engaging. Keep it under 100 words.\n\nUser Prompt: ${prompt ?? "A family adventure"}\n\nImage Descriptions:\n${imageDescriptions.asMap().entries.map((e) => "Image ${e.key + 1}: ${e.value}").join("\n")}'
              }
            ],
            'max_tokens': 200,
            'temperature': 0.7,
          };

          print('Generating story outline...');
          final outlineResponse = await http.post(
            Uri.parse(ApiConfig.chatCompletionEndpoint),
            headers: ApiConfig.headers,
            body: json.encode(outlinePayload),
          );

          if (outlineResponse.statusCode == 200) {
            var outlineJson = json.decode(outlineResponse.body);
            storyOutline = outlineJson['choices'][0]['message']['content'];
            print('Story outline: $storyOutline');
          }
        } catch (e) {
          print('Error generating story outline: $e');
          storyOutline = 'A family adventure unfolds...';
        }

        // Get style-specific prompts
        final String imagePrompt = ApiConfig.getStylePrompt(style, prompt);
        final String textPrompt = ApiConfig.getTextPrompt(prompt, style);
        print('Using image prompt: $imagePrompt');
        print('Using text prompt: $textPrompt');

        // Generate images and text
        final List<ComicPage> pages = [];
        String storyContext = storyOutline;  // Initialize with story outline
        
        // Generate one image at a time to ensure quality
        for (int i = 0; i < images.length; i++) {
          try {
            print('Generating image ${i + 1} of ${images.length}');
            
            // Convert captured image to base64
            final List<int> imageBytes = await images[i].readAsBytes();
            final String capturedImageBase64 = base64Encode(imageBytes);

            // Prepare JSON payload for DALL-E 3 image generation
            final Map<String, dynamic> payload = {
              'model': 'dall-e-3',
              'prompt': '$imagePrompt\n\nScene: ${imageDescriptions[i]}\n\nTransform this into a $style style comic panel, keeping the same people and poses. ${prompt != null ? "Incorporate this theme: $prompt" : ""}',
              'n': 1,
              'size': '1024x1024',
              'response_format': 'b64_json',
              'quality': 'standard',
              'style': 'vivid',
            };

            print('Sending image request to: ${ApiConfig.imageGenerationEndpoint}');
            print('Request payload: ${json.encode(payload)}');
            
            // Send request with timeout
            final response = await http.post(
              Uri.parse(ApiConfig.imageGenerationEndpoint),
              headers: ApiConfig.headers,
              body: json.encode(payload),
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Image generation request timed out');
              },
            );

            print('Response status code: ${response.statusCode}');
            print('Response headers: ${response.headers}');
            print('Response body: ${response.body}');
            
            if (response.statusCode != 200) {
              throw Exception('Image generation failed: ${response.body}');
            }

            var jsonResponse = json.decode(response.body);
            print('Response data keys: ${jsonResponse.keys.toList()}');
            
            if (jsonResponse['data'] == null || jsonResponse['data'].isEmpty) {
              throw Exception('No image data in response');
            }

            final String imageBase64 = jsonResponse['data'][0]['b64_json'];
            print('Generated image base64 length: ${imageBase64.length}');

            // Generate text for this panel using the image analysis and story context
            print('Generating text for panel ${i + 1}');
            String generatedText = '';
            int textRetryCount = 0;
            while (textRetryCount < 3) {
              try {
                final Map<String, dynamic> textPayload = {
                  'model': 'gpt-4o',
                  'messages': [
                    {
                      'role': 'system',
                      'content': '''You are a comic book writer. Write dialogue and narration for comic panels following these strict rules:
1. Maximum 2 speech bubbles per panel
2. Each speech bubble must be under 40 characters
3. Maximum 1 narration box per panel
4. Narration must be under 80 characters
5. Format text like this:
   [SPEECH] "Character name: Short dialogue here"
   [NARRATION] "Brief narration here"
6. Keep text family-friendly and fun
7. Make it sound like a real comic book
8. Ensure dialogue connects with previous and next panels'''
                    },
                    {
                      'role': 'user',
                      'content': '''Create comic text for this panel following these rules:
- Maximum 2 speech bubbles (40 chars each)
- Maximum 1 narration box (80 chars)
- Format: [SPEECH] "Character: Text" and [NARRATION] "Text"

Scene details: ${imageDescriptions[i]}
Story outline: $storyOutline
Story context so far: $storyContext

This is panel ${i + 1} of ${images.length}. Create dialogue and narration that matches this exact scene and advances the story. Keep text short and impactful.'''
                    }
                  ],
                  'max_tokens': 100,
                  'temperature': 0.7,
                };

                print('Sending text request to: ${ApiConfig.chatCompletionEndpoint}');
                print('Text request payload: ${json.encode(textPayload)}');

                final textResponse = await http.post(
                  Uri.parse(ApiConfig.chatCompletionEndpoint),
                  headers: ApiConfig.headers,
                  body: json.encode(textPayload),
                ).timeout(
                  const Duration(seconds: 30),
                  onTimeout: () {
                    throw TimeoutException('Text generation request timed out');
                  },
                );

                print('Text response status code: ${textResponse.statusCode}');
                print('Text response body: ${textResponse.body}');
                
                if (textResponse.statusCode != 200) {
                  throw Exception('Text generation failed: ${textResponse.body}');
                }

                var textJsonResponse = json.decode(textResponse.body);
                print('Text response data: ${textJsonResponse}');
                
                if (textJsonResponse['choices'] == null || textJsonResponse['choices'].isEmpty) {
                  throw Exception('No text data in response');
                }

                generatedText = textJsonResponse['choices'][0]['message']['content'];
                
                // Validate and clean up the generated text
                generatedText = _cleanupGeneratedText(generatedText);
                print('Generated text: $generatedText');
                
                // Update story context for next panel
                storyContext += '\nPanel ${i + 1}: $generatedText';
                
                break;  // Success, exit retry loop
              } catch (e) {
                print('Error generating text (attempt ${textRetryCount + 1}): $e');
                textRetryCount++;
                if (textRetryCount >= 3) {
                  generatedText = 'A family moment captured in time...';  // Fallback text
                } else {
                  await Future.delayed(const Duration(seconds: 2));  // Wait before retry
                }
              }
            }

            // Create comic page with image and text
            final comicPage = ComicPage(
              id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
              imageUrl: 'data:image/png;base64,$imageBase64',
              generatedText: generatedText,
              pageNumber: i + 1,
              timestamp: DateTime.now(),
            );
            
            print('Created comic page: ${comicPage.id}');
            print('Image URL length: ${comicPage.imageUrl.length}');
            print('Generated text length: ${comicPage.generatedText?.length ?? 0}');
            
            pages.add(comicPage);

            // Add a small delay between requests to avoid rate limiting
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            print('Error generating panel ${i + 1}: $e');
            // Continue with next panel instead of failing completely
            continue;
          }
        }

        if (pages.isEmpty) {
          throw Exception('Failed to generate any comic panels');
        }

        final story = Story(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: prompt ?? 'Family Adventure',
          createdAt: DateTime.now(),
          pages: pages,
          style: style,
          prompt: prompt,
          tags: ['family', 'adventure'],
          isMultiPage: images.length > 1,
        );

        print('Generated story with ${story.pages.length} pages');
        return story;
      } catch (e) {
        print('Error in comic generation: $e');
        retryCount++;
        if (retryCount >= _maxRetries) {
          rethrow;
        }
        print('Retrying in ${_retryDelay.inSeconds} seconds... (Attempt $retryCount of $_maxRetries)');
        await Future.delayed(_retryDelay);
      }
    }
  }

  // Helper method to process images for different comic styles
  Future<List<File>> processImagesForStyle({
    required List<File> images,
    required ComicStyle style,
  }) async {
    // TODO: Implement image processing for different styles
    // For now, return the original images
    return images;
  }

  // Helper method to clean up and validate generated text
  String _cleanupGeneratedText(String text) {
    // Split into lines and process each line
    List<String> lines = text.split('\n');
    List<String> cleanedLines = [];
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Process speech bubbles
      if (line.startsWith('[SPEECH]')) {
        String content = line.substring(8).trim();
        if (content.startsWith('"')) content = content.substring(1);
        if (content.endsWith('"')) content = content.substring(0, content.length - 1);
        
        // Ensure character name is present
        if (!content.contains(':')) {
          content = 'Character: $content';
        }
        
        // Truncate if too long
        if (content.length > 40) {
          content = content.substring(0, 37) + '...';
        }
        
        cleanedLines.add('[SPEECH] "$content"');
      }
      // Process narration
      else if (line.startsWith('[NARRATION]')) {
        String content = line.substring(11).trim();
        if (content.startsWith('"')) content = content.substring(1);
        if (content.endsWith('"')) content = content.substring(0, content.length - 1);
        
        // Truncate if too long
        if (content.length > 80) {
          content = content.substring(0, 77) + '...';
        }
        
        cleanedLines.add('[NARRATION] "$content"');
      }
    }
    
    // Ensure we don't exceed limits
    if (cleanedLines.length > 3) {
      cleanedLines = cleanedLines.sublist(0, 3);
    }
    
    return cleanedLines.join('\n');
  }
} 