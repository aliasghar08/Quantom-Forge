import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

// Conditionally import package:web for web URL launching to bypass url_launcher's
// MissingPluginException on some Wasm builds.
import 'package:web/web.dart' as web;

class UrlService {
  /// Opens a URL using the best method for the current platform.
  /// 
  /// On Web, this uses raw DOM APIs (`window.open`) to avoid Wasm plugin
  /// channel issues. On native platforms, it falls back to `url_launcher`.
  static Future<bool> launch(String url) async {
    try {
      if (kIsWeb) {
        // Direct DOM interop for Web
        web.window.open(url, '_blank');
        return true;
      } else {
        // Native fallback
        final uri = Uri.parse(url);
        return await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL ($url): $e');
      return false;
    }
  }
}
