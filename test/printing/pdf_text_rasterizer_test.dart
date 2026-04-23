import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/printing/pdf_text_rasterizer.dart';

void main() {
  group('PdfTextRasterizer', () {
    test('detects Hebrew nikud and teamim', () {
      expect(PdfTextRasterizer.containsHebrewMarks('בראשית'), isFalse);
      expect(PdfTextRasterizer.containsHebrewMarks('בְּרֵאשִׁית'), isTrue);
      expect(PdfTextRasterizer.containsHebrewMarks('ב֑ראשית'), isTrue);
    });
  });
}
