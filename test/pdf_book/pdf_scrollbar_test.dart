import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/pdf_scrollbar.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  group('Pdf scrollbars', () {
    testWidgets('horizontal scrollbar does not crash before viewer attachment',
        (tester) async {
      final controller = PdfViewerController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfHorizontalScrollbar(controller: controller),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PdfHorizontalScrollbar), findsOneWidget);
    });

    testWidgets(
        'vertical custom scrollbar does not crash before viewer attachment',
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
      expect(find.byType(PdfScrollbar), findsOneWidget);
    });
  });
}
