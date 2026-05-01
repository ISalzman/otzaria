import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';

void main() {
  group('shouldShowOpenPdfCommentaryPaneEntry', () {
    test('מחזירה true רק כשיש מפרשים רלוונטיים והחלונית סגורה', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasRelevantCommentators: true,
          isPaneOpen: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשאין מפרשים רלוונטיים', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasRelevantCommentators: false,
          isPaneOpen: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשהחלונית כבר פתוחה', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasRelevantCommentators: true,
          isPaneOpen: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldShowOpenPdfLinksPaneEntry', () {
    test('מחזירה true רק כשיש קישורים רלוונטיים והחלונית סגורה', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: true,
          isPaneOpen: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשאין קישורים רלוונטיים', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: false,
          isPaneOpen: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשהחלונית כבר פתוחה', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: true,
          isPaneOpen: true,
        ),
        isFalse,
      );
    });
  });
}
