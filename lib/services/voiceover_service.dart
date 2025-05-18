import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/story.dart';

class VoiceoverService {
  static const String _baseUrl = 'https://api.openai.com/v1/audio/speech';
  final String _apiKey = dotenv.env['OPEN_API_KEY'] ?? '';

  Future<String> generateVoiceover(Story story) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please add OPEN_API_KEY to your .env file.');
    }

    // Create a simple narration from the story
    final narration = _createNarration(story);

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'tts-1',
          'input': narration,
          'voice': 'alloy', // You can choose: alloy, echo, fable, onyx, nova, shimmer
          'response_format': 'mp3',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate voiceover: ${response.statusCode} - ${response.body}');
      }

      // Save the audio to a temporary file
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/voiceover_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await audioFile.writeAsBytes(response.bodyBytes);

      return audioFile.path;
    } catch (e) {
      throw Exception('Error generating voiceover: $e');
    }
  }

  String _createNarration(Story story) {
    final buffer = StringBuffer();
    
    // Add title
    buffer.writeln('${story.title}.');
    
    // Add story content
    if (story.prompt != null) {
      buffer.writeln(story.prompt);
    }
    
    // Add page descriptions
    for (var page in story.pages) {
      if (page.generatedText != null) {
        buffer.writeln(page.generatedText);
      }
    }
    
    return buffer.toString();
  }
} 