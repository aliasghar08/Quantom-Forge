import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A robust, cached service for interacting with the Crossref REST API.
/// This prevents hitting the API multiple times for the same DOI during a session.
class CrossrefService {
  // In-memory cache for fast subsequent loads
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Fetches publication metadata for a given [doi].
  /// Provides the raw Crossref 'message' dictionary on success.
  static Future<Map<String, dynamic>?> fetchMetadata(String doi, {String? gnnBackendUrl}) async {
    if (doi.isEmpty) return null;

    // Clean DOI (remove URL prefix if present)
    String cleanDoi = doi.trim();
    if (cleanDoi.startsWith('https://doi.org/')) {
      cleanDoi = cleanDoi.replaceFirst('https://doi.org/', '');
    } else if (cleanDoi.startsWith('http://doi.org/')) {
      cleanDoi = cleanDoi.replaceFirst('http://doi.org/', '');
    }

    if (_cache.containsKey(cleanDoi)) {
      debugPrint('CrossrefService: Cache hit for $cleanDoi');
      return _cache[cleanDoi];
    }

    try {
      debugPrint('CrossrefService: Fetching $cleanDoi');
      
      // If a custom GNN backend is provided, we can route through it to avoid CORS issues
      // on Web, or we can hit Crossref directly.
      final String uriString = (gnnBackendUrl != null && gnnBackendUrl.isNotEmpty)
          ? '$gnnBackendUrl/crossref/${Uri.encodeComponent(cleanDoi)}'
          : 'https://api.crossref.org/works/${Uri.encodeComponent(cleanDoi)}';

      final uri = Uri.parse(uriString);
      
      // We append a mailto user-agent to get routed to the polite pool per Crossref guidelines
      final response = await http.get(uri, headers: {
        'User-Agent': 'QuantumForge/1.0 (mailto:admin@quantumforge.app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['message'] != null) {
          final data = json['message'] as Map<String, dynamic>;
          _cache[cleanDoi] = data;
          return data;
        }
      } else {
        debugPrint('CrossrefService HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('CrossrefService Error: $e');
    }
    
    return null;
  }
}
