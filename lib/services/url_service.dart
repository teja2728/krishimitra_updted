import 'dart:developer' as dev;
import 'package:url_launcher/url_launcher.dart';

class UrlService {
  /// Normalize a raw URL string:
  /// - trims whitespace
  /// - prepends https:// if no scheme is present
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;

    // If no scheme at all, prepend https://
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.scheme.isEmpty) {
      url = 'https://$url';
    } else if (uri.scheme == 'http') {
      // Upgrade http to https for government links
      url = url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Validate whether [url] looks like a launchable URL.
  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Open a URL in an external browser.
  /// Normalizes the URL first, validates it, then launches.
  /// Throws a user-friendly [Exception] on failure.
  static Future<void> openUrl(String rawUrl) async {
    final url = normalizeUrl(rawUrl);

    if (!isValidUrl(url)) {
      dev.log('[UrlService] Invalid URL after normalization: "$url" (raw: "$rawUrl")');
      throw Exception('Invalid URL: $rawUrl');
    }

    final uri = Uri.parse(url);
    dev.log('[UrlService] Attempting to launch: $uri');

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        dev.log('[UrlService] canLaunchUrl returned false for: $uri');
        // Try launching anyway — some devices return false but can still open
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        dev.log('[UrlService] launchUrl returned false for: $uri');
        throw Exception('Could not open $url');
      }

      dev.log('[UrlService] Successfully launched: $uri');
    } catch (e) {
      dev.log('[UrlService] Error launching URL: $e');
      if (e is Exception && e.toString().contains('Could not open')) {
        rethrow;
      }
      throw Exception('Failed to open link. Please try again.');
    }
  }
}
