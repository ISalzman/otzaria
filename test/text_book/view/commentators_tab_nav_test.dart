import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/view/commentators_tab_screen.dart';

// טסטים לרדוסרים הטהורים שמפעילים את מצב הניווט ב-[CommentatorsTabScreen].
// כל מסלולי עדכון ה-state ב-_CommentatorsTabScreenState עוברים דרך
// _applyNavSelection עם תוצאת אחד הרדוסרים:
//   - reduceChevronTap     → onPressed של ה-IconButton של החץ
//   - reduceChapterBodyTap → no-op check ב-onTap של גוף שורת הפרק
//   - reduceSubItemTap     → _selectVerseInChapter / _selectParaInChapter
//                            ו-_onChapterSelected (עם verseIdx=_kAllChapter)
// כך שהטסטים על הרדוסרים תופסים רגרסיות בהתנהגות שמופעלת מה-UI.
void main() {
  TocEntry chapterA() => TocEntry(text: 'פרק א', index: 0);
  TocEntry chapterB() => TocEntry(text: 'פרק ב', index: 5);

  group('reduceChevronTap — שמירה על בחירת המפרשים', () {
    test('לחיצה על חץ הפרק הנבחר (הרגרסיה המקורית) לא מבטלת את הבחירה', () {
      final chA = chapterA();
      final state = CommentatorsNavSelection(
        selectedChapter: chA,
        navExpandedChapter: chA,
      );

      final next = reduceChevronTap(state, chA);

      // הבחירה והאינדקס נשמרו — זה התיקון של הבאג שבו 'לא נמצאו מפרשים'
      // הופיע אחרי כיווץ הניווט.
      expect(next.selectedChapter, equals(chA));
      expect(next.selectedVerseIdx, equals(state.selectedVerseIdx));
      // אך הניווט כווץ.
      expect(next.navExpandedChapter, isNull);
    });

    test('לחיצה על חץ פרק לא-נבחר מרחיבה אותו בלי לשנות את הבחירה', () {
      final chA = chapterA();
      final chB = chapterB();
      final state = CommentatorsNavSelection(
        selectedChapter: chA,
        selectedVerseIdx: 3,
        navExpandedChapter: chA,
      );

      final next = reduceChevronTap(state, chB);

      // הבחירה ואינדקס הפסוק נשמרו — לחיצה על חץ של פרק אחר היא ניווט בלבד.
      expect(next.selectedChapter, equals(chA));
      expect(next.selectedVerseIdx, equals(3));
      expect(next.navExpandedChapter, equals(chB));
    });

    test('לחיצה חוזרת על חץ פרק מורחב מכווצת אותו ל-null', () {
      final chB = chapterB();
      final state = CommentatorsNavSelection(navExpandedChapter: chB);

      final next = reduceChevronTap(state, chB);

      expect(next.navExpandedChapter, isNull);
    });

    test('לחיצה על חץ בעוד אין הרחבה בכלל מרחיבה את הפרק הנלחץ', () {
      final chA = chapterA();
      const state = CommentatorsNavSelection();

      final next = reduceChevronTap(state, chA);

      expect(next.navExpandedChapter, equals(chA));
      expect(next.selectedChapter, isNull);
    });
  });

  group('reduceChapterBodyTap — לחיצה על גוף שורת פרק', () {
    test('לחיצה על פרק לא-נבחר בוחרת אותו ומרחיבה אותו בניווט', () {
      final chA = chapterA();
      final chB = chapterB();
      final state = CommentatorsNavSelection(
        selectedChapter: chA,
        selectedVerseIdx: 5,
        navExpandedChapter: chA,
      );

      final next = reduceChapterBodyTap(state, chB);

      expect(next.selectedChapter, equals(chB));
      expect(next.selectedVerseIdx, equals(-1));
      expect(next.navExpandedChapter, equals(chB));
    });

    test('לחיצה על פרק שכבר נבחר היא no-op (מחזירה אותו state)', () {
      final chA = chapterA();
      final state = CommentatorsNavSelection(
        selectedChapter: chA,
        selectedVerseIdx: 5,
        navExpandedChapter: chA,
      );

      final next = reduceChapterBodyTap(state, chA);

      // identical: ה-instance הוא בדיוק אותו — חשוב עבור short-circuit
      // שמונע טעינה מיותרת של links ב-_onChapterSelected.
      expect(identical(next, state), isTrue);
    });

    test('לחיצה על פרק לא-נבחר עם חירה ניקויה מעדכנת את הבחירה', () {
      final chA = chapterA();
      const state = CommentatorsNavSelection();

      final next = reduceChapterBodyTap(state, chA);

      expect(next.selectedChapter, equals(chA));
      expect(next.navExpandedChapter, equals(chA));
    });
  });

  group('reduceSubItemTap — לחיצה על תת-פריט', () {
    test('לחיצה על תת-פריט בפרק לא-נבחר מחליפה את בחירת הפרק לאותו פרק', () {
      // תרחיש: המשתמש פתח פרק ב בניווט (חץ פתיחה), ופרק א הוא הנבחר.
      // כעת הוא לוחץ על פסוק בפרק ב. הבחירה צריכה לעבור לפרק ב + אותו פסוק.
      final chA = chapterA();
      final chB = chapterB();
      final state = CommentatorsNavSelection(
        selectedChapter: chA,
        selectedVerseIdx: -1,
        navExpandedChapter: chB,
      );

      final next = reduceSubItemTap(state, chB, 2);

      expect(next.selectedChapter, equals(chB));
      expect(next.selectedVerseIdx, equals(2));
      expect(next.navExpandedChapter, equals(chB));
    });

    test('לחיצה על תת-פריט בפרק הנבחר מעדכנת רק את אינדקס הפסוק', () {
      final chA = chapterA();
      final state = CommentatorsNavSelection(
        selectedChapter: chA,
        selectedVerseIdx: -1,
        navExpandedChapter: chA,
      );

      final next = reduceSubItemTap(state, chA, 7);

      expect(next.selectedChapter, equals(chA));
      expect(next.selectedVerseIdx, equals(7));
      expect(next.navExpandedChapter, equals(chA));
    });
  });
}
