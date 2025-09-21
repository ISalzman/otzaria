/// Service for sanitizing links in markdown content
class LinkSanitizer {
  /// Allowed URL protocols
  static final List<String> allowedProtocols = ['https', 'mailto', 'tel'];
  
  /// Maximum size for data:image URLs in bytes
  static const int maxDataImageSize = 100 * 1024; // 100KB

  /// Sanitizes a URL to ensure it's safe
  static String sanitizeUrl(String url) {
    if (url.isEmpty) return '';
    
    final trimmedUrl = url.trim();
    
    // Block javascript: URLs
    if (trimmedUrl.toLowerCase().startsWith('javascript:')) {
      return '';
    }
    
    // Handle data: URLs
    if (trimmedUrl.toLowerCase().startsWith('data:')) {
      return _sanitizeDataUrl(trimmedUrl);
    }
    
    // Check allowed protocols
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null) return '';
    
    if (uri.hasScheme && !allowedProtocols.contains(uri.scheme.toLowerCase())) {
      return '';
    }
    
    return trimmedUrl;
  }

  /// Sanitizes data: URLs, allowing only images up to size limit
  static String _sanitizeDataUrl(String dataUrl) {
    if (!dataUrl.toLowerCase().startsWith('data:image/')) {
      return ''; // Block non-image data URLs
    }
    
    // Estimate size (base64 encoded data is ~4/3 the size of original)
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return '';
    
    final base64Data = dataUrl.substring(commaIndex + 1);
    final estimatedSize = (base64Data.length * 3) ~/ 4;
    
    if (estimatedSize > maxDataImageSize) {
      return ''; // Block oversized images
    }
    
    return dataUrl;
  }

  /// Adds security attributes to external links
  static String addSecurityAttributes(String html) {
    // Simple approach: add rel attributes to external links
    return html.replaceAllMapped(
      RegExp(r'<a\s+([^>]*?)>', caseSensitive: false),
      (match) {
        final attributes = match.group(1) ?? '';
        if (attributes.contains('href') && attributes.contains('http')) {
          if (!attributes.contains('rel=')) {
            return '<a $attributes rel="noopener noreferrer">';
          }
        }
        return match.group(0) ?? '';
      },
    );
  }

  /// Validates and sanitizes all URLs in HTML content
  static String sanitizeHtmlUrls(String html) {
    // Simple approach: remove potentially dangerous URLs
    html = html.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'data:(?!image)', caseSensitive: false), '');
    
    return html;
  }
}