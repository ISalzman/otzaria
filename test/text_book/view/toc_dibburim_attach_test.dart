import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/view/toc_navigator_internals.dart';

TocEntry _e(String text, int index, int level, {List<TocEntry>? children}) {
  final entry = TocEntry(text: text, index: index, level: level);
  for (final c in children ?? const <TocEntry>[]) {
    entry.children.add(c);
  }
  return entry;
}

/// עץ לדוגמה: כותרת ראשית (0) → פרק א (2) → משנה א (4), משנה ב (9); פרק ב (14).
List<TocEntry> _toc() => [
  _e(
    'ספר',
    0,
    1,
    children: [
      _e(
        'פרק א',
        2,
        2,
        children: [_e('משנה א', 4, 3), _e('משנה ב', 9, 3)],
      ),
      _e('פרק ב', 14, 2),
    ],
  ),
];

List<String> _texts(List<TocEntry> entries) =>
    entries.map((e) => e.text).toList();

void main() {
  group('attachDibburimToToc', () {
    test('מפה ריקה — מחזירה את העץ המקורי עצמו', () {
      final toc = _toc();
      expect(identical(attachDibburimToToc(toc, const {}), toc), isTrue);
    });

    test('כל דיבור נתלה תחת הכותרת האחרונה שלפניו, גם כשהיא עלה', () {
      final merged = attachDibburimToToc(_toc(), {
        3: 'ד"ה שלפני משנה א',
        5: 'ד"ה במשנה א',
        7: 'ד"ה שני במשנה א',
        11: 'ד"ה במשנה ב',
        20: 'ד"ה בפרק ב',
      });

      final perekA = merged.single.children[0];
      final mishnaA = perekA.children[1];
      final mishnaB = perekA.children[2];
      final perekB = merged.single.children[1];

      // הדיבור שבין "פרק א" ל"משנה א" קודם לתתי-הכותרות של הפרק.
      expect(_texts(perekA.children), [
        'ד"ה שלפני משנה א',
        'משנה א',
        'משנה ב',
      ]);
      expect(_texts(mishnaA.children), ['ד"ה במשנה א', 'ד"ה שני במשנה א']);
      expect(_texts(mishnaB.children), ['ד"ה במשנה ב']);
      expect(_texts(perekB.children), ['ד"ה בפרק ב']);
    });

    test('דיבור הוא רמה אחת מתחת לכותרתו, עם parent ו-index של השורה', () {
      final merged = attachDibburimToToc(_toc(), {5: 'ד"ה'});
      final mishnaA = merged.single.children[0].children[0];
      final dibbur = mishnaA.children.single;

      expect(dibbur.index, 5);
      expect(dibbur.level, mishnaA.level + 1);
      expect(identical(dibbur.parent, mishnaA), isTrue);
      expect(dibbur.fullText, 'פרק א, משנה א, ד"ה');
    });

    test('העץ המקורי אינו משתנה', () {
      final toc = _toc();
      attachDibburimToToc(toc, {5: 'ד"ה', 20: 'ד"ה'});

      expect(toc.single.children[0].children[0].children, isEmpty);
      expect(toc.single.children[1].children, isEmpty);
    });

    test('דיבור שלפני הכותרת הראשונה או על שורת כותרת — נשמט', () {
      final toc = [_e('כותרת', 3, 1), _e('כותרת ב', 8, 1)];
      final merged = attachDibburimToToc(toc, {
        1: 'לפני הכל',
        8: 'על שורת הכותרת',
        9: 'אחרי כותרת ב',
      });

      expect(merged[0].children, isEmpty);
      expect(_texts(merged[1].children), ['אחרי כותרת ב']);
    });
  });
}
