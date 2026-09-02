import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/plugin_file_input_guard_script.dart';

void main() {
  group('buildPluginFileInputGuardScript', () {
    test('מוזרק לפני קוד הדף וגם ל-iframes', () {
      final script = buildPluginFileInputGuardScript();
      expect(
        script.injectionTime,
        UserScriptInjectionTime.AT_DOCUMENT_START,
      );
      expect(script.forMainFrameOnly, isFalse);
    });

    test('חוסם פתיחת סייר קבצים מאלמנט input type=file (click, capture)', () {
      final source = buildPluginFileInputGuardScript().source;
      expect(source, contains("addEventListener('click'"));
      expect(source, contains("preventDefault"));
      expect(source, contains("stopPropagation"));
      expect(source, contains("otzaria_file_input_clicked"));
      expect(source, contains("}, true);"));
    });

    test('מזהה input file גם אם הלחיצה באלמנט פנימי', () {
      final source = buildPluginFileInputGuardScript().source;
      expect(source, contains("closest('input[type=\"file\"]')"));
    });
  });
}
