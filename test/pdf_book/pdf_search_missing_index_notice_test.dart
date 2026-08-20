import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/messages/pdf_messages.dart';
import 'package:otzaria/pdf_book/view/pdf_search_screen.dart';

void main() {
  group('PdfBookSearchView.missingFromIndexNotice', () {
    const path = r'C:\books\pdf\ספר.pdf';

    test('מחזיר את ההודעה כשהאינדקס נטען והספר אינו בו', () {
      expect(
        PdfBookSearchView.missingFromIndexNotice(
          pdfFilePath: path,
          indexInitialized: true,
          indexedFilePaths: {r'C:\books\pdf\אחר.pdf'},
        ),
        PdfMessages.bookNotInSearchIndex,
      );
    });

    test('לא מחזיר הודעה כשהספר נמצא באינדקס', () {
      expect(
        PdfBookSearchView.missingFromIndexNotice(
          pdfFilePath: path,
          indexInitialized: true,
          indexedFilePaths: {path},
        ),
        isNull,
      );
    });

    test('לא מסיק "חסר" לפני שקריאת מצב האינדקס הסתיימה', () {
      expect(
        PdfBookSearchView.missingFromIndexNotice(
          pdfFilePath: path,
          indexInitialized: false,
          indexedFilePaths: const {},
        ),
        isNull,
      );
    });

    test('לא מחזיר הודעה כשאין נתיב לקובץ ה-PDF', () {
      for (final missingPath in [null, '']) {
        expect(
          PdfBookSearchView.missingFromIndexNotice(
            pdfFilePath: missingPath,
            indexInitialized: true,
            indexedFilePaths: const {},
          ),
          isNull,
        );
      }
    });
  });
}
