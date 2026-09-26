import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeService {
  // Use a dart-define environment variable for the API key.
  // Compile with: --dart-define=YOUTUBE_API_KEY=your_actual_key
  static const String _apiKey = String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');

  /// Fetches up to 5 related YouTube videos based on the query.
  static Future<List<Map<String, String>>> fetchRelatedVideos(String query) async {
    if (_apiKey.isEmpty) {
      throw Exception('YouTube API key is missing. Please provide it via --dart-define=YOUTUBE_API_KEY');
    }

    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=5&q=${Uri.encodeComponent(query)}&type=video&key=$_apiKey'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final items = json['items'] as List<dynamic>? ?? [];

      return items.map((item) {
        final snippet = item['snippet'];
        final id = item['id']['videoId'];
        
        // Prefer high resolution thumbnail, fallback to default
        final thumbnails = snippet['thumbnails'];
        final thumbnail = thumbnails['high']?['url'] ?? thumbnails['default']?['url'] ?? '';

        return {
          'videoId': id.toString(),
          'title': snippet['title'].toString(),
          'thumbnail': thumbnail.toString(),
        };
      }).toList();
    } else {
      throw Exception('Failed to load YouTube videos (Status: ${response.statusCode})');
    }
  }
}
