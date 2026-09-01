import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';

void main() {
  group('פריסת תצוגת ספר', () {
    const pageSize = Size(400, 600);

    test('מלבן העמוד שווה לגודלו בנקודות — זו הדרישה של הרינדור החד', () {
      final layout = buildBookViewPageLayout(
        pageSizes: const [pageSize, pageSize],
        hasCover: false,
        verticalMargin: 8,
      );

      for (final rect in layout.pageLayouts) {
        expect(rect.width, pageSize.width);
        expect(rect.height, pageSize.height);
      }
    });

    test('הכפולה מסודרת ימין-שמאל עם מרווח השדרה ביניהן', () {
      final layout = buildBookViewPageLayout(
        pageSizes: const [pageSize, pageSize],
        hasCover: false,
        verticalMargin: 8,
      );

      expect(layout.pageLayouts, hasLength(2));
      expect(layout.pageLayouts[0].left, pageSize.width + kBookViewSpineGap);
      expect(layout.pageLayouts[1].left, 0);
      expect(layout.pageLayouts[0].top, layout.pageLayouts[1].top);
      expect(
        layout.documentSize.width,
        pageSize.width * 2 + kBookViewSpineGap,
      );
    });

    test('עמוד שער עומד לבדו והכפולה הראשונה מתחילה אחריו', () {
      final layout = buildBookViewPageLayout(
        pageSizes: const [pageSize, pageSize, pageSize],
        hasCover: true,
        verticalMargin: 8,
      );

      expect(layout.pageLayouts, hasLength(3));
      expect(layout.pageLayouts[0].left, 0);
      expect(layout.pageLayouts[0].top, 0);
      expect(layout.pageLayouts[1].top, pageSize.height + 8);
      expect(layout.pageLayouts[2].top, layout.pageLayouts[1].top);
    });

    test('רוחב המסמך כולל כפולה רחבה שאינה הראשונה', () {
      final layout = buildBookViewPageLayout(
        pageSizes: const [
          Size(300, 600),
          Size(300, 600),
          Size(700, 600),
          Size(200, 600),
        ],
        hasCover: false,
        verticalMargin: 8,
      );

      expect(layout.documentSize.width, 700 + kBookViewSpineGap + 700);
    });
  });

  group('מיגרציית הזום השמור פר-ספר', () {
    test('זום ישן בתצוגת ספר מתורגם לקנה המידה החדש', () {
      final settings = PdfBookPerBookSettings.fromJson(const {
        'zoom': 4.0,
        'layoutMode': 'bookView',
      });

      expect(settings.zoom, 2.0);
    });

    test('זום ישן בתצוגה רגילה נשאר כפי שהוא', () {
      final settings = PdfBookPerBookSettings.fromJson(const {
        'zoom': 4.0,
        'layoutMode': 'regularView',
      });

      expect(settings.zoom, 4.0);
    });

    test('זום בלי תצוגה שמורה אינו מומר', () {
      final settings = PdfBookPerBookSettings.fromJson(const {'zoom': 4.0});

      expect(settings.zoom, 4.0);
    });

    test('זום שכבר נכתב בקנה המידה החדש אינו מומר שוב', () {
      final saved = PdfBookPerBookSettings(
        zoom: 2.0,
        layoutMode: PdfLayoutMode.bookView,
      ).toJson();

      expect(PdfBookPerBookSettings.fromJson(saved).zoom, 2.0);
    });
  });
}
