import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/pdf_scrollbar.dart';
import 'package:pdfrx/pdfrx.dart';

// ─── fake controllers ─────────────────────────────────────────────────────────
// מדמה את מצב הריבוע שגרם לקריסה: isReady=true אבל visibleRect זורק
class _UnreadyController extends PdfViewerController {
  @override
  bool get isReady => true;

  @override
  Rect get visibleRect => throw StateError('_visibleRect is null');
}

// visibleRect תקין אבל layout זורק — תרחיש race condition שני
class _ControllerWithThrowingLayout extends PdfViewerController {
  @override
  bool get isReady => true;

  @override
  Rect get visibleRect => const Rect.fromLTWH(0, 0, 400, 600);

  @override
  PdfPageLayout get layout => throw StateError('layout not available');
}

void main() {
  group('PdfScrollbar - לפני חיבור ל-viewer', () {
    testWidgets('גלילה אופקית לא קורסת לפני חיבור', (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PdfHorizontalScrollbar(controller: controller)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PdfHorizontalScrollbar), findsOneWidget);
    });

    testWidgets('גלילה אנכית (ברירת מחדל) לא קורסת לפני חיבור', (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.right,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('גלילה אנכית שמאל לא קורסת לפני חיבור', (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.left,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('גלילה אנכית עם scrollBoundsBuilder לא קורסת לפני חיבור',
        (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.right,
              scrollBoundsBuilder: (_) => Rect.zero,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ─── תרחיש race condition שני: visibleRect עובד אבל layout זורק ────────────
  group('PdfHorizontalScrollbar - layout זורק', () {
    testWidgets('לא קורס כאשר layout זורק (visibleRect תקין)', (tester) async {
      final controller = _ControllerWithThrowingLayout();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PdfHorizontalScrollbar(controller: controller)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(PdfHorizontalScrollbar), findsOneWidget);
    });

    testWidgets('קריסות חוזרות של layout לא גורמות לקריסה', (tester) async {
      final controller = _ControllerWithThrowingLayout();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PdfHorizontalScrollbar(controller: controller)),
        ),
      );
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  });

  // ─── תרחיש הקריסה המדויק מה-LOG ──────────────────────────────────────────
  group('PdfScrollbar - תרחיש race condition (isReady=true + visibleRect זורק)',
      () {
    testWidgets(
        'PdfHorizontalScrollbar לא קורס כאשר isReady=true אבל visibleRect זורק',
        (tester) async {
      final controller = _UnreadyController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PdfHorizontalScrollbar(controller: controller)),
        ),
      );
      // פריים שני - מדמה את ה-drawFrame שגרם לקריסה
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(PdfHorizontalScrollbar), findsOneWidget);
    });

    testWidgets(
        'PdfScrollbar (אנכי, ברירת מחדל) לא קורס כאשר isReady=true אבל visibleRect זורק',
        (tester) async {
      final controller = _UnreadyController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.right,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PdfScrollbar (תחתון) לא קורס כאשר isReady=true אבל visibleRect זורק',
        (tester) async {
      final controller = _UnreadyController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.bottom,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PdfScrollbar עם scrollBoundsBuilder לא קורס כאשר isReady=true אבל visibleRect זורק',
        (tester) async {
      final controller = _UnreadyController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.right,
              scrollBoundsBuilder: (_) => const Rect.fromLTWH(0, 0, 100, 1000),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('קריסות חוזרות בפריימים רצופים לא גורמות לקריסה', (tester) async {
      final controller = _UnreadyController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PdfHorizontalScrollbar(controller: controller)),
        ),
      );
      // שישה פריימים - כמו בLOG שהראה קריסות כל ~4 שניות
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 4));
      }
      expect(tester.takeException(), isNull);
    });
  });

  // ─── יציבות rebuild ───────────────────────────────────────────────────────
  group('PdfScrollbar - יציבות rebuild', () {
    testWidgets('rebuild מרובים עם controller לא מחובר', (tester) async {
      final controller = PdfViewerController();

      Widget buildScrollbars() => MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                      child: PdfScrollbar(
                          controller: controller,
                          orientation: ScrollbarOrientation.right)),
                  Expanded(
                      child: PdfScrollbar(
                          controller: controller,
                          orientation: ScrollbarOrientation.right,
                          scrollBoundsBuilder: (_) => Rect.zero)),
                ],
              ),
            ),
          );

      await tester.pumpWidget(buildScrollbars());
      await tester.pumpWidget(buildScrollbars());
      await tester.pumpWidget(buildScrollbars());

      expect(tester.takeException(), isNull);
      expect(find.byType(PdfScrollbar), findsNWidgets(2));
    });

    testWidgets('החלפת controller לא גורמת לקריסה', (tester) async {
      final controller1 = PdfViewerController();
      final controller2 = PdfViewerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfHorizontalScrollbar(controller: controller1),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfHorizontalScrollbar(controller: controller2),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose של widget לא גורם לקריסה', (tester) async {
      final controller = PdfViewerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PdfHorizontalScrollbar(controller: controller)),
        ),
      );
      // הסרת ה-widget מה-tree
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // ─── עיצוב וצבעים ─────────────────────────────────────────────────────────
  group('PdfScrollbar - עיצוב', () {
    testWidgets('PdfScrollbar עם trackColor ו-thumbColor מותאמים', (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfScrollbar(
              controller: controller,
              orientation: ScrollbarOrientation.right,
              trackColor: Colors.grey,
              thumbColor: Colors.blue,
              trackThickness: 16,
              thumbMinSize: 50,
              scrollBoundsBuilder: (_) => Rect.zero,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('PdfHorizontalScrollbar עם trackThickness מותאם', (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfHorizontalScrollbar(
              controller: controller,
              trackThickness: 12,
              thumbColor: Colors.red,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ─── ארבע כיוונים ─────────────────────────────────────────────────────────
  group('PdfScrollbar - כל הכיוונים', () {
    for (final orientation in ScrollbarOrientation.values) {
      testWidgets('כיוון $orientation לא קורס', (tester) async {
        final controller = PdfViewerController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PdfScrollbar(
                controller: controller,
                orientation: orientation,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('כיוון $orientation עם _UnreadyController לא קורס',
          (tester) async {
        final controller = _UnreadyController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PdfScrollbar(
                controller: controller,
                orientation: orientation,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
