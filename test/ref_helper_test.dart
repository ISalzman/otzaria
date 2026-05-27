import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/text/ref_helper.dart';

/// בונה TocEntry עם ילדים. עוזר לקיצור הטסטים של closestTocEntryIndex.
TocEntry _entry(String text, int index, int level, {List<TocEntry>? children}) {
  final e = TocEntry(text: text, index: index, level: level);
  if (children != null) {
    for (final c in children) {
      e.children.add(c);
    }
  }
  return e;
}

void main() {
  group('closestTocEntryIndex', () {
    // הפונקציה הזו מחושבת *פעם אחת* בכל emit של TextBookBloc ב-TocViewer
    // (commit 5ca70f2). אם מישהו ישבור את האלגוריתם, ה-active item
    // יוצג שגוי בכל הספרים — ולכן חשוב לכסות את הקצוות.

    test('רשימה ריקה מחזירה null', () {
      expect(closestTocEntryIndex(const [], 0), isNull);
      expect(closestTocEntryIndex(const [], 999), isNull);
    });

    test('כל הערכים אחרי היעד - מחזיר null', () {
      final entries = [
        _entry('a', 10, 1),
        _entry('b', 20, 1),
      ];
      expect(closestTocEntryIndex(entries, 5), isNull);
    });

    test('יעד שווה לאינדקס - מחזיר אותו אינדקס', () {
      final entries = [
        _entry('a', 0, 1),
        _entry('b', 5, 1),
        _entry('c', 10, 1),
      ];
      expect(closestTocEntryIndex(entries, 5), 5);
    });

    test('בוחר את האחרון שאינדקסו <= target ברמה אחת', () {
      final entries = [
        _entry('a', 0, 1),
        _entry('b', 5, 1),
        _entry('c', 10, 1),
        _entry('d', 15, 1),
      ];
      expect(closestTocEntryIndex(entries, 7), 5);
      expect(closestTocEntryIndex(entries, 9), 5);
      expect(closestTocEntryIndex(entries, 10), 10);
      expect(closestTocEntryIndex(entries, 11), 10);
      expect(closestTocEntryIndex(entries, 100), 15);
    });

    test('יורד לעומק בעץ - מוצא ילד עם אינדקס גבוה מההורה', () {
      // הורה ב-0, ילדים ב-1,2,3 — היעד 2 צריך להחזיר את הילד (2), לא ההורה
      final entries = [
        _entry('parent', 0, 1, children: [
          _entry('c1', 1, 2),
          _entry('c2', 2, 2),
          _entry('c3', 3, 2),
        ]),
        _entry('next', 10, 1),
      ];
      expect(closestTocEntryIndex(entries, 2), 2);
      expect(closestTocEntryIndex(entries, 4), 3);
    });

    test('יעד בין שני אבות - לא יורד לעץ של האב הרחוק', () {
      // ההגנה החשובה: כשאב נמצא אחרי היעד, האלגוריתם לא יורד לילדיו
      // כי אינדקסיהם בהכרח גבוהים יותר. זה התנאי `if (entry.index <= target)`.
      final entries = [
        _entry('p1', 0, 1, children: [
          _entry('p1c', 1, 2),
        ]),
        _entry('p2', 10, 1, children: [
          _entry('p2c', 11, 2),
        ]),
      ];
      expect(closestTocEntryIndex(entries, 5), 1);
    });

    test('היררכיה עמוקה - בוחר את האינדקס המקסימלי בכל הרמות', () {
      final entries = [
        _entry('A', 0, 1, children: [
          _entry('A1', 1, 2, children: [
            _entry('A1a', 2, 3),
            _entry('A1b', 3, 3),
          ]),
          _entry('A2', 4, 2, children: [
            _entry('A2a', 5, 3),
          ]),
        ]),
      ];
      expect(closestTocEntryIndex(entries, 5), 5);
      expect(closestTocEntryIndex(entries, 4), 4);
      expect(closestTocEntryIndex(entries, 3), 3);
      expect(closestTocEntryIndex(entries, 0), 0);
    });

    test('יעד שלילי - מחזיר null אם אין אינדקסים שליליים', () {
      final entries = [
        _entry('a', 0, 1),
        _entry('b', 5, 1),
      ];
      expect(closestTocEntryIndex(entries, -1), isNull);
    });

    test('יציב לאינדקסים זהים בעלים שונים - מחזיר את אחד מהם', () {
      // קצה לא טיפוסי, אבל יציבות חשובה אם זה קורה בנתונים אמיתיים
      final entries = [
        _entry('a', 5, 1),
        _entry('b', 5, 1),
      ];
      expect(closestTocEntryIndex(entries, 5), 5);
    });

    test('עץ גדול (8000 ערכים) - תוצאה נכונה במבנה מציאותי', () {
      // מבנה דמוי-ספר אמיתי: siman_s מתחיל באינדקס s*100, ילדיו ב-s*100+1..+99.
      // לא טסט ביצועים, אבל מוודא שאין רגרסיה לעצירה בלולאה אינסופית.
      final simanim = List.generate(80, (s) {
        final base = s * 100;
        final children = List.generate(
          99,
          (i) => _entry('seif$i', base + 1 + i, 2),
        );
        return _entry('siman$s', base, 1, children: children);
      });
      expect(closestTocEntryIndex(simanim, 99), 99);
      // ערך באמצע: siman40 מתחיל ב-4000, ילדים ב-4001..4099
      expect(closestTocEntryIndex(simanim, 4050), 4050);
      // יעד בדיוק על siman - לא בורר אחד מהילדים
      expect(closestTocEntryIndex(simanim, 4000), 4000);
    });
  });

  group('formatDisplayReference', () {
    test('adds the book title when resolved reference omits it', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          resolvedRef: 'פרק א',
          fallbackRef: 'א',
        ),
        'בראשית, פרק א',
      );
    });

    test('keeps the resolved reference when it already starts with title', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          resolvedRef: 'בראשית, פרק א',
          fallbackRef: 'פרק א',
        ),
        'בראשית, פרק א',
      );
    });

    test('removes adjacent duplicate toc segments', () {
      expect(
        formatDisplayReference(
          bookTitle: 'לבני מחולקת על כרכות',
          resolvedRef: 'לבני מחולקת על כרכות, לבני מחולקת על כרכות, כרכות',
        ),
        'לבני מחולקת על כרכות, כרכות',
      );
    });

    test(
        'falls back to the existing link reference when TOC ref is unavailable',
        () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          fallbackRef: 'פרק א',
        ),
        'בראשית, פרק א',
      );
    });

    test('returns only the book title when no reference is available', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
        ),
        'בראשית',
      );
    });

    test('normalizes whitespace and keeps only adjacent unique segments', () {
      expect(
        formatDisplayReference(
          bookTitle: 'בראשית',
          resolvedRef: '  פרק א  ,   פרק א , פסוק ב  ',
        ),
        'בראשית, פרק א, פסוק ב',
      );
    });

    test('prefers fallback reference when it is more specific than TOC', () {
      expect(
        formatDisplayReference(
          bookTitle: 'כמלכל',
          resolvedRef: 'פרק ו',
          fallbackRef: 'פרק ו, פסוק ג',
        ),
        'כמלכל, פרק ו, פסוק ג',
      );
    });
  });
}
