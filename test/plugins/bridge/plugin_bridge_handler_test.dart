import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_handler.dart';

void main() {
  group('PluginBridgeHandler.isRateLimitExempt', () {
    test('library.getBookContent מוחרג ממגביל הקצב', () {
      // טעינת ספר מלא מחולקת ל-chunks ומחייבת עשרות קריאות רצופות; ספירתן
      // במגביל הקצב חתכה את הטעינה באמצע (חצי ספר).
      expect(PluginBridgeHandler.isRateLimitExempt('library.getBookContent'),
          isTrue);
    });

    test('קריאות אחרות אינן מוחרגות וממשיכות להיות מוגבלות', () {
      expect(
          PluginBridgeHandler.isRateLimitExempt('library.getBookToc'), isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt('library.getTree'), isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt('storage.set'), isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt('reader.setHighlight'),
          isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt(''), isFalse);
    });
  });

  group('RateLimiter', () {
    test('מתחיל עם 50 טוקנים וחוסם לאחר שהם נגמרים בפרץ אחד', () {
      final limiter = RateLimiter();
      var allowed = 0;
      // פרץ מיידי של 60 קריאות: 50 הראשונות אמורות לעבור, השאר להיחסם
      // (הטוקנים מתחדשים רק ~1 כל 10ms, וכאן אין שהייה ביניהן).
      for (var i = 0; i < 60; i++) {
        if (limiter.consume()) allowed++;
      }
      expect(allowed, lessThanOrEqualTo(51));
      expect(allowed, greaterThanOrEqualTo(50));
    });
  });
}
