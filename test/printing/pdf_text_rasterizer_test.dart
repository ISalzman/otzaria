import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/printing/pdf_text_rasterizer.dart';

void main() {
  group('PdfTextRasterizer.containsHebrewMarks', () {
    // ─── ניקוד ────────────────────────────────────────────────────────────────
    group('ניקוד (U+05B0-U+05C7)', () {
      test('בראשית ללא ניקוד → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('בראשית'), isFalse);
      });

      test('בְּרֵאשִׁית עם ניקוד → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('בְּרֵאשִׁית'), isTrue);
      });

      test('שווא (U+05B0) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('בְ'), isTrue);
      });

      test('קמץ (U+05B8) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('בָ'), isTrue);
      });

      test('חולם מלא (U+05BA) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('בֺ'), isTrue);
      });

      test('שורוק/מפיק (U+05BC) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('בּ'), isTrue);
      });

      test('U+05C7 (גבול עליון של הטווח) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('ׇ'), isTrue);
      });
    });

    // ─── טעמים ───────────────────────────────────────────────────────────────
    group('טעמי מקרא (U+0591-U+05AF)', () {
      test('אתנחתא (U+0591) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('ב֑'), isTrue);
      });

      test('סוף פסוק (U+05C3) → true', () {
        // U+05C3 = HEBREW PUNCTUATION SOF PASUQ — inside range
        expect(PdfTextRasterizer.containsHebrewMarks('׃'), isTrue);
      });

      test('U+0591 (גבול תחתון של הטווח) → true', () {
        expect(PdfTextRasterizer.containsHebrewMarks('֑'), isTrue);
      });
    });

    // ─── מחרוזות ללא סימנים ───────────────────────────────────────────────────
    group('מחרוזות ללא סימנים עבריים', () {
      test('מחרוזת ריקה → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks(''), isFalse);
      });

      test('אנגלית בלבד → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('Hello World'), isFalse);
      });

      test('ספרות → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('1234567890'), isFalse);
      });

      test('פיסוק → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('.,!?;:'), isFalse);
      });

      test('עברית ללא ניקוד → false', () {
        expect(
          PdfTextRasterizer.containsHebrewMarks('שלום עולם'),
          isFalse,
        );
      });

      test('ערבית → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('مرحبا'), isFalse);
      });

      test('תו לפני הטווח (U+0590) → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('֐'), isFalse);
      });

      test('תו אחרי הטווח (U+05C8) → false', () {
        expect(PdfTextRasterizer.containsHebrewMarks('׈'), isFalse);
      });
    });

    // ─── מחרוזות מעורבות ──────────────────────────────────────────────────────
    group('מחרוזות מעורבות', () {
      test('אנגלית + ניקוד עברי → true', () {
        expect(
          PdfTextRasterizer.containsHebrewMarks('Hello בְּ World'),
          isTrue,
        );
      });

      test('עברית בלי ניקוד + אנגלית → false', () {
        expect(
          PdfTextRasterizer.containsHebrewMarks('שלום Hello'),
          isFalse,
        );
      });

      test('פסוק שלם עם טעמים → true', () {
        expect(
          PdfTextRasterizer.containsHebrewMarks('ב֑ראשית'),
          isTrue,
        );
      });

      test('ניקוד בסוף מחרוזת ארוכה → true', () {
        final longText = 'א' * 500 + 'בְ';
        expect(PdfTextRasterizer.containsHebrewMarks(longText), isTrue);
      });

      test('ניקוד בתחילת מחרוזת ארוכה → true', () {
        final longText = 'בְ${'א' * 500}';
        expect(PdfTextRasterizer.containsHebrewMarks(longText), isTrue);
      });

      test('מחרוזת ארוכה ללא ניקוד → false', () {
        final longText = 'בראשית ברא אלוהים ' * 100;
        expect(PdfTextRasterizer.containsHebrewMarks(longText), isFalse);
      });
    });
  });
}
