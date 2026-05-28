import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/selection/selected_text_restore.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';

void main() {
  group('restoreSelectedTextLineBreaks', () {
    test('משחזר מעברי שורה כש-SelectionArea מחזיר טקסט רציף', () {
      final restored = restoreSelectedTextLineBreaks(
        selectedText: 'שורה אשורה ב',
        visibleLines: const ['שורה א', 'שורה ב'],
      );

      expect(restored, 'שורה א\nשורה ב');
    });

    test('משחזר בחירה חלקית על פני כמה שורות', () {
      final restored = restoreSelectedTextLineBreaks(
        selectedText: 'גדהוזח',
        visibleLines: const ['אבגד', 'הוז', 'חט'],
      );

      expect(restored, 'גד\nהוז\nח');
    });

    test('מחזיר fallback כשהבחירה לא ניתנת למיפוי', () {
      final restored = restoreSelectedTextLineBreaks(
        selectedText: 'טקסט לא קיים',
        visibleLines: const ['שורה א', 'שורה ב'],
      );

      expect(restored, 'טקסט לא קיים');
    });
  });

  group('renderSelectionLine', () {
    test('מייצר טקסט תצוגה מעובד לצורך שחזור הבחירה', () {
      final firstLine = renderSelectionLine(
        rawText: 'בְּרֵאשִׁ֖ית!',
        settings: const RenderSettings(
          removeNikud: true,
          removePunctuation: true,
        ),
      );
      final secondLine = renderSelectionLine(
        rawText: 'שָׁלוֹם.',
        settings: const RenderSettings(
          removeNikud: true,
          removePunctuation: true,
        ),
      );

      final restored = restoreSelectedTextLineBreaks(
        selectedText: 'בראשיתשלום.',
        visibleLines: [firstLine, secondLine],
      );

      expect(firstLine, 'בראשית');
      expect(secondLine, 'שלום.');
      expect(restored, 'בראשית\nשלום.');
    });

    test('מכווץ רווחים כפולים שמותיר הסתרת פיסוק כדי שהתצוגה תתאים', () {
      // הסתרת פיסוק מסירה את ה"-" ומותירה רווח כפול במקומו;
      // התצוגה ב-HTML מכווצת אותו, ולכן גם renderSelectionLine חייב לכווץ.
      expect(removePunctuation('לאמר - דבר').contains('  '), isTrue);

      final line = renderSelectionLine(
        rawText: 'לאמר - דבר',
        settings: const RenderSettings(removePunctuation: true),
      );

      expect(line, 'לאמר דבר');
      expect(line.contains('  '), isFalse);
    });

    test('משחזר מעבר שורה בין פסקאות גם כשהוסר פיסוק מוקף ברווחים', () {
      const settings = RenderSettings(removePunctuation: true);
      final firstLine = renderSelectionLine(
        rawText: 'וידבר ה אל משה לאמר - דבר',
        settings: settings,
      );
      final secondLine = renderSelectionLine(
        rawText: 'אל בני ישראל ואמרת אליהם.',
        settings: settings,
      );

      // הבחירה השטוחה שפלאטר מחזיר תואמת את התצוגה (רווחים מכווצים).
      final flatSelection = '$firstLine$secondLine';

      final restored = restoreSelectedTextLineBreaks(
        selectedText: flatSelection,
        visibleLines: [firstLine, secondLine],
      );

      expect(restored, '$firstLine\n$secondLine');
      expect(restored.contains('\n'), isTrue);
    });
  });
}
