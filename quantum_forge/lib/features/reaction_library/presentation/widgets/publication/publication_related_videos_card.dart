import 'package:flutter/material.dart';
import 'package:quantum_forge/features/reaction_runner/presentation/widgets/dashboard_cards/glass_card.dart';
import 'package:quantum_forge/core/services/youtube_service.dart';
import 'package:quantum_forge/core/services/url_service.dart';

class PublicationRelatedVideosCard extends StatelessWidget {
  final String query;

  const PublicationRelatedVideosCard({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Related Videos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, String>>>(
              future: YouTubeService.fetchRelatedVideos(query),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Text('Failed to load related videos. Please ensure a valid YOUTUBE_API_KEY is provided.', style: TextStyle(color: Colors.white54, fontSize: 13));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No related videos found.', style: TextStyle(color: Colors.white54, fontSize: 13));
                }

                final videos = snapshot.data!;
                return SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            try {
                              UrlService.launch('https://www.youtube.com/watch?v=${video['videoId']}');
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      video['thumbnail']!,
                                      height: 120,
                                      width: 160,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 120,
                                        width: 160,
                                        color: Colors.black26,
                                        child: const Icon(Icons.broken_image, color: Colors.white54),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                video['title'] ?? 'Unknown Title',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
