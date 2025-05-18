import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/story.dart';

class ApiConfig {
  static const String baseUrl = 'https://api.openai.com/v1';
  
  // Get API key from environment variable
  static String get apiKey => dotenv.env['OPEN_API_KEY'] ?? '';
  
  // Endpoints
  static const String imageGenerationEndpoint = '$baseUrl/images/generations';
  static const String chatCompletionEndpoint = '$baseUrl/chat/completions';
  
  // Headers
  static Map<String, String> get headers => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  // Helper method to get style-specific prompts
  static String getStylePrompt(ComicStyle style, String? userPrompt) {
    final basePrompt = userPrompt ?? 'A family moment';
    final stylePrompts = {
      ComicStyle.marvel: 'Transform this family photo into a dynamic Marvel-style comic panel. Maintain the exact same people, poses, and composition, but enhance with: dramatic lighting, vibrant colors, comic book halftone dots, dynamic action lines, and stylized speech bubbles. Add depth with dramatic shadows and highlights. This is part of a story sequence, so maintain visual consistency with other panels. The scene should be: ',
      ComicStyle.anime: 'Transform this family photo into a vibrant anime-style illustration. Keep the exact same people, poses, and composition, but enhance with: clean, bold lines, bright colors, manga-style shading, expressive eyes, and stylized speech bubbles. Add depth with cel-shading and dynamic lighting. This is part of a story sequence, so maintain visual consistency with other panels. The scene should be: ',
      ComicStyle.disney: 'Transform this family photo into a magical Disney-style illustration. Maintain the exact same people, poses, and composition, but enhance with: warm, inviting colors, soft lighting, whimsical atmosphere, and elegant speech bubbles. Add depth with subtle shadows and magical sparkles. This is part of a story sequence, so maintain visual consistency with other panels. The scene should be: ',
      ComicStyle.classic: 'Transform this family photo into a classic comic book panel. Keep the exact same people, poses, and composition, but enhance with: bold outlines, classic halftone dots, dramatic shadows, and traditional speech bubbles. Add depth with crosshatching and classic comic book textures. This is part of a story sequence, so maintain visual consistency with other panels. The scene should be: ',
      ComicStyle.watercolor: 'Transform this family photo into an artistic watercolor comic panel. Maintain the exact same people, poses, and composition, but enhance with: soft, flowing colors, artistic brushstrokes, and elegant speech bubbles. Add depth with watercolor textures and artistic shading. This is part of a story sequence, so maintain visual consistency with other panels. The scene should be: ',
      ComicStyle.sketch: 'Transform this family photo into a detailed pencil sketch comic panel. Keep the exact same people, poses, and composition, but enhance with: fine linework, artistic shading, and elegant speech bubbles. Add depth with crosshatching and detailed textures. This is part of a story sequence, so maintain visual consistency with other panels. The scene should be: ',
    };
    
    return '${stylePrompts[style] ?? stylePrompts[ComicStyle.marvel]!}$basePrompt. Maintain the exact same scene and people, just transform the style. Ensure the composition and poses remain identical to the original photo. This panel is part of a story sequence, so maintain visual consistency with other panels.';
  }

  // Helper method to get text generation prompt
  static String getTextPrompt(String? userPrompt, ComicStyle style) {
    final basePrompt = userPrompt ?? 'A family moment';
    final stylePrompts = {
      ComicStyle.marvel: 'Write a short, dramatic comic book dialogue in Marvel style based on this family photo. Include dynamic sound effects (like POW!, BAM!, WHAM!, etc.) and dramatic narration. Focus on the action and emotion in the scene. Keep it family-friendly but exciting. This is part of a story sequence, so make the dialogue connect with the previous and next panels. Scene: ',
      ComicStyle.anime: 'Write a short, emotional anime-style dialogue based on this family photo. Include expressive sound effects (like *gasp*, *sigh*, *giggle*, etc.) and emotional narration. Focus on the feelings and relationships in the scene. Keep it family-friendly and heartfelt. This is part of a story sequence, so make the dialogue connect with the previous and next panels. Scene: ',
      ComicStyle.disney: 'Write a short, magical Disney-style dialogue based on this family photo. Include whimsical narration and magical sound effects. Focus on the wonder and joy in the scene. Keep it family-friendly and enchanting. This is part of a story sequence, so make the dialogue connect with the previous and next panels. Scene: ',
      ComicStyle.classic: 'Write a short, classic comic book dialogue based on this family photo. Include traditional sound effects and narration in the style of classic comics. Focus on the story and character interactions. Keep it family-friendly and engaging. This is part of a story sequence, so make the dialogue connect with the previous and next panels. Scene: ',
      ComicStyle.watercolor: 'Write a short, artistic comic dialogue based on this family photo. Include poetic narration and artistic sound effects. Focus on the beauty and emotion in the scene. Keep it family-friendly and artistic. This is part of a story sequence, so make the dialogue connect with the previous and next panels. Scene: ',
      ComicStyle.sketch: 'Write a short, artistic comic dialogue based on this family photo. Include poetic narration and artistic sound effects. Focus on the details and atmosphere in the scene. Keep it family-friendly and artistic. This is part of a story sequence, so make the dialogue connect with the previous and next panels. Scene: ',
    };
    
    return '${stylePrompts[style] ?? stylePrompts[ComicStyle.marvel]!}$basePrompt. Keep it family-friendly and engaging, and make sure the dialogue matches exactly what\'s happening in the photo. Include both speech bubbles and narration that enhance the scene. This panel is part of a story sequence, so make the dialogue connect with the previous and next panels to create a cohesive narrative.';
  }
} 