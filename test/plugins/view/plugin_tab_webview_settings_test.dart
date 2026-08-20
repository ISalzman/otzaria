import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/plugin_tab_page.dart';

void main() {
  group('buildPluginTabWebViewSettings', () {
    test('זום חסום — צביטת מגע ו-Ctrl+גלגלת (issue #883)', () {
      final settings = buildPluginTabWebViewSettings(isDevelopment: false);
      expect(settings.supportZoom, isFalse);
      expect(settings.pinchZoomEnabled, isFalse);
    });

    test('הגדרות אבטחה ותצוגה נשמרות', () {
      final settings = buildPluginTabWebViewSettings(isDevelopment: false);
      expect(settings.allowFileAccessFromFileURLs, isFalse);
      expect(settings.allowUniversalAccessFromFileURLs, isFalse);
      expect(settings.useShouldOverrideUrlLoading, isTrue);
      expect(settings.useShouldInterceptRequest, isTrue);
      expect(settings.statusBarEnabled, isFalse);
      expect(settings.cacheEnabled, isTrue);
    });

    test('מצב פיתוח — ללא קאש ועם inspect', () {
      final settings = buildPluginTabWebViewSettings(isDevelopment: true);
      expect(settings.cacheEnabled, isFalse);
      expect(settings.isInspectable, isTrue);
      expect(settings.supportZoom, isFalse);
      expect(settings.pinchZoomEnabled, isFalse);
    });
  });
}
