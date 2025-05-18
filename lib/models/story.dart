enum ComicStyle {
  marvel,
  anime,
  disney,
  classic,
  watercolor,
  sketch
}

class Story {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ComicPage> pages;
  final ComicStyle style;
  final String? prompt;
  final List<String> tags;
  final bool isMultiPage;
  final bool isPublished;
  final DateTime? publishedAt;
  final double? latitude;
  final double? longitude;

  Story({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pages,
    required this.style,
    this.prompt,
    required this.tags,
    required this.isMultiPage,
    this.isPublished = false,
    this.publishedAt,
    this.latitude,
    this.longitude,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      pages: (json['pages'] as List)
          .map((e) => ComicPage.fromJson(e as Map<String, dynamic>))
          .toList(),
      style: ComicStyle.values.firstWhere(
        (e) => e.toString() == 'ComicStyle.${json['style']}',
      ),
      prompt: json['prompt'] as String?,
      tags: List<String>.from(json['tags'] as List),
      isMultiPage: json['isMultiPage'] as bool,
      isPublished: json['isPublished'] as bool,
      publishedAt: json['publishedAt'] != null ? DateTime.parse(json['publishedAt'] as String) : null,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'pages': pages.map((e) => e.toJson()).toList(),
      'style': style.toString().split('.').last,
      'prompt': prompt,
      'tags': tags,
      'isMultiPage': isMultiPage,
      'isPublished': isPublished,
      'publishedAt': publishedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ComicPage {
  final String id;
  final String imageUrl;
  final String? generatedText;
  final int pageNumber;
  final DateTime timestamp;

  ComicPage({
    required this.id,
    required this.imageUrl,
    this.generatedText,
    required this.pageNumber,
    required this.timestamp,
  });

  factory ComicPage.fromJson(Map<String, dynamic> json) {
    return ComicPage(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      generatedText: json['generatedText'] as String?,
      pageNumber: json['pageNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'generatedText': generatedText,
      'pageNumber': pageNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }
} 