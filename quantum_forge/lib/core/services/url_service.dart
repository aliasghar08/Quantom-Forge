import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

// Conditionally import package:web for web URL launching to bypass url_launcher's
// MissingPluginException on some Wasm builds.
import 'package:web/web.dart' as web;

class UrlService {
  /// Opens a URL synchronously if on the web (to prevent popup blockers),
  /// or asynchronously on native using url_launcher.
  static void launch(String url) {
    try {
      if (kIsWeb) {
        // Direct DOM interop for Web, synchronous to avoid popup blockers
        web.window.open(url, '_blank');
      } else {
        // Native fallback
        final uri = Uri.parse(url);
        ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL ($url): $e');
    }
  }
}
