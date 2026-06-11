import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/text_renderer_service.dart';

void main() {
  group('TextRendererService - סימוני הערות שוליים', () {
    const settings = RenderSettings();

    test(
        'סימון מספרי נפלט כספרות-עיליות ולא כ-sup (מניעת WidgetSpan שמתהפך ב-RTL)',
        () {
      const line = 'יתגבר כארי<sup class="footnote-marker">1</sup> לעמוד עד'
          '<sup class="footnote-marker">2</sup> שיהא';

      final out = TextRendererService.processText(line, settings);

      // אסור שיישאר <sup>: HtmlWidget מממש אותו כ-WidgetSpan, ומנוע Flutter
      // משבץ placeholders בפסקת RTL בסדר ויזואלי הפוך — המספרים מתחלפים.
      expect(out, isNot(contains('<sup')));
      expect(out, contains('¹'));
      expect(out, contains('²'));
    });

    test('סדר המספרים הלוגי נשמר בפלט', () {
      const line = 'אחד<sup class="footnote-marker">1</sup> שתיים'
          '<sup class="footnote-marker">2</sup> שלוש'
          '<sup class="footnote-marker">3</sup>';

      final out = TextRendererService.processText(line, settings);

      final digits =
          RegExp('[¹²³]').allMatches(out).map((m) => m.group(0)).toList();
      expect(digits, ['¹', '²', '³']);
    });

    test('סימון דו-ספרתי מומר במלואו', () {
      const line = 'מילה<sup class="footnote-marker">14</sup> עוד';

      final out = TextRendererService.processText(line, settings);

      expect(out, contains('¹⁴'));
    });

    test('תוכן הסימון עטוף בסימני בידוד דו-כיווניים (LRI/PDI)', () {
      const line = 'מילה<sup class="footnote-marker">7</sup> עוד';

      final out = TextRendererService.processText(line, settings);

      expect(out, contains('\u2066⁷\u2069'));
    });

    test('סימון אות עברית נפלט כ-span מעוצב (אין ספרות-עיליות לעברית)', () {
      const line = 'מילה<sup class="footnote-marker">א</sup> עוד';

      final out = TextRendererService.processText(line, settings);

      expect(out, isNot(contains('<sup')));
      expect(out, contains('<span class="footnote-marker-number">'));
    });

    test('sup מספרי חשוף (בלי class) מומר אף הוא לספרות-עיליות', () {
      // חלק מספרי ההערות-inline מקודדים מרקרים כ-<sup>1</sup> ללא class,
      // והם חשופים לאותו באג היפוך — מקבלים את אותו טיפול.
      const line = 'שורה<sup>1</sup> המשך<sup>2</sup> סוף';

      final out = TextRendererService.processText(line, settings);

      expect(out, isNot(contains('<sup')));
      expect(out, contains('¹'));
      expect(out, contains('²'));
    });

    test('sup עברי חשוף (בלי class) נשאר sup — superscript תוכני אמיתי', () {
      const line = 'טקסט עם <sup>מעריך</sup> רגיל';

      final out = TextRendererService.processText(line, settings);

      expect(out, contains('<sup>'));
      expect(out, isNot(contains('footnote-marker-number')));
    });

    test('sup מורכב (שאינו סימון הערה) נשאר sup', () {
      const line = 'טקסט<sup><a href="x">קישור מורכב!</a></sup> המשך';

      final out = TextRendererService.processText(line, settings);

      expect(out, contains('<sup>'));
    });

    test('sup ריק מוסר לחלוטין', () {
      const line = 'טקסט<sup class="footnote-marker"></sup> המשך';

      final out = TextRendererService.processText(line, settings);

      expect(out, isNot(contains('<sup')));
      expect(out, isNot(contains('footnote-marker-number')));
    });
  });
}
