import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';
import 'package:otzaria/printing/printing_helpers.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';

void main() {
  group('resolveInitialPdfPrintPage', () {
    test('מחזירה את אותו עמוד בתצוגה רגילה', () {
      expect(
        resolveInitialPdfPrintPage(
          currentPage: 5,
          layoutMode: PdfLayoutMode.regularView,
        ),
        5,
      );
    });

    test('מנרמלת עמוד אי זוגי לתחילת spread במצב ספר', () {
      expect(
        resolveInitialPdfPrintPage(
          currentPage: 5,
          layoutMode: PdfLayoutMode.bookView,
        ),
        4,
      );
    });

    test('משאירה את עמוד 1 ללא שינוי במצב ספר', () {
      expect(
        resolveInitialPdfPrintPage(
          currentPage: 1,
          layoutMode: PdfLayoutMode.bookView,
        ),
        1,
      );
    });
  });

  group('shouldShowOpenPdfCommentaryPaneEntry', () {
    test('מחזירה true כשיש מפרשים נבחרים וטאב המפרשים אינו פעיל', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: true,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשאין מפרשים נבחרים', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשטאב המפרשים כבר פעיל', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: true,
          isCommentatorsTabActive: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldShowSelectPdfCommentatorsEntry', () {
    test('מחזירה true כשטאב המפרשים אינו פעיל', () {
      expect(
        shouldShowSelectPdfCommentatorsEntry(
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשטאב המפרשים פעיל', () {
      expect(
        shouldShowSelectPdfCommentatorsEntry(
          isCommentatorsTabActive: true,
        ),
        isFalse,
      );
    });

    test('מציגה גם בלי מפרשים נבחרים — בניגוד ל-shouldShowOpenPdfCommentaryPaneEntry',
        () {
      // הפריט הזה לא תלוי ב-hasSelectedCommentators, כדי לאפשר בחירה ראשונית
      // גם כשהבחירה ריקה (תיקון עקביות מול מסך הטקסט).
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
      expect(
        shouldShowSelectPdfCommentatorsEntry(
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });
  });

  group('shouldShowOpenPdfLinksPaneEntry', () {
    test('מחזירה true כשיש קישורים רלוונטיים וטאב הקישורים אינו פעיל', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: true,
          isLinksTabActive: false,
        ),
        isTrue,
      );
    });

    test('מחזירה false כשאין קישורים רלוונטיים', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: false,
          isLinksTabActive: false,
        ),
        isFalse,
      );
    });

    test('מחזירה false כשטאב הקישורים כבר פעיל', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: true,
          isLinksTabActive: true,
        ),
        isFalse,
      );
    });
  });

  group('תרחישים חוצי-טאב בחלונית הצד', () {
    test('"פתח מפרשים" מוצגת כשהחלונית פתוחה על טאב הקישורים', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: true,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
    });

    test('"פתח קישורים" מוצגת כשהחלונית פתוחה על טאב המפרשים', () {
      expect(
        shouldShowOpenPdfLinksPaneEntry(
          hasRelevantLinks: true,
          isLinksTabActive: false,
        ),
        isTrue,
      );
    });

    test('"פתח מפרשים" אינה תלויה ברלוונטיות לעמוד, רק בנבחרים בספר', () {
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: true,
          isCommentatorsTabActive: false,
        ),
        isTrue,
      );
      expect(
        shouldShowOpenPdfCommentaryPaneEntry(
          hasSelectedCommentators: false,
          isCommentatorsTabActive: false,
        ),
        isFalse,
      );
    });
  });
}
