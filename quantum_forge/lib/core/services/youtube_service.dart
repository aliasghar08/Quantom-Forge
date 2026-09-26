import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  /// Fetches up to 5 related YouTube videos based on the query.
  static Future<List<Map<String, String>>> fetchRelatedVideos(String query) async {
    final yt = YoutubeExplode();
    try {
      final searchResults = await yt.search.search(query);
      final topResults = searchResults.take(5).toList();

      return topResults.map((video) => {
        'videoId': video.id.value,
        'title': video.title,
        'thumbnail': video.thumbnails.highResUrl,
      }).toList();
    } finally {
      yt.close();
    }
  }
}
