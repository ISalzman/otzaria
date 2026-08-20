import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/text/html_link_handler.dart';

/// בונה עץ תוכן עניינים לפי מפרט מקונן: {טקסט: {טקסט-בן: ...}}.
List<TocEntry> _buildToc(
  Map<String, dynamic> spec, {
  int level = 1,
  TocEntry? parent,
  List<int>? counter,
}) {
  final index = counter ?? [0];
  final entries = <TocEntry>[];
  for (final key in spec.keys) {
    index[0]++;
    final entry = TocEntry(
      text: key,
      index: index[0],
      level: level,
      parent: parent,
    );
    final children = spec[key];
    if (children is Map<String, dynamic>) {
      entry.children = _buildToc(
        children,
        level: level + 1,
        parent: entry,
        counter: index,
      );
    }
    entries.add(entry);
  }
  return entries;
}

void main() {
  group('isHeaderMatch', () {
    test('התאמה מדויקת אחרי נרמול רווחים', () {
      expect(HtmlLinkHandler.isHeaderMatch('סימן   א', 'סימן א'), isTrue);
    });

    test('אין התאמת substring', () {
      expect(HtmlLinkHandler.isHeaderMatch('סימן א', 'סימן'), isFalse);
    });
  });

  group('resolveHeaderPath', () {
    final toc = _buildToc({
      'אורח חיים': {
        'סימן א': {'סעיף קטן יג': {}, 'סעיף קטן יד': {}},
        'סימן ב': {},
      },
      'יורה דעה': {'סימן פט': {}},
    });

    test('רמה אחת - מחזיר את השורש', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, ['יורה דעה']);
      expect(result.missingSegment, isNull);
      expect(result.reachedHeader, 'יורה דעה');
      expect(result.index, isNotNull);
    });

    test('נתיב בן שלוש רמות - מגיע לרמה העמוקה', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, [
        'אורח חיים',
        'סימן א',
        'סעיף קטן יג',
      ]);
      expect(result.missingSegment, isNull);
      expect(result.reachedHeader, 'סעיף קטן יג');
    });

    test('שתי רמות עמוקות נבדלות זו מזו', () {
      final first = HtmlLinkHandler.resolveHeaderPath(toc, [
        'אורח חיים',
        'סימן א',
        'סעיף קטן יג',
      ]);
      final second = HtmlLinkHandler.resolveHeaderPath(toc, [
        'אורח חיים',
        'סימן א',
        'סעיף קטן יד',
      ]);
      expect(first.index, isNot(second.index));
    });

    test('רמה חסרה באמצע - מדלג עליה ומוצא בתת-העץ', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, [
        'אורח חיים',
        'סעיף קטן יג',
      ]);
      expect(result.missingSegment, isNull);
      expect(result.reachedHeader, 'סעיף קטן יג');
    });

    test('רמה שאינה קיימת - מחזיר נחיתה חלקית ומדווח מה חסר', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, [
        'אורח חיים',
        'סימן א',
        'סעיף קטן צט',
      ]);
      expect(result.missingSegment, 'סעיף קטן צט');
      expect(result.reachedHeader, 'סימן א');
      expect(result.index, isNotNull);
    });

    test('הרמה הראשונה אינה קיימת - אין אינדקס בכלל', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, ['חושן משפט']);
      expect(result.missingSegment, 'חושן משפט');
      expect(result.index, isNull);
      expect(result.reachedHeader, isNull);
    });

    test('נתיב אינו קופץ לענף אחר - סימן פט אינו תחת אורח חיים', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, [
        'אורח חיים',
        'סימן פט',
      ]);
      expect(result.missingSegment, 'סימן פט');
      expect(result.reachedHeader, 'אורח חיים');
    });

    test('נתיב ריק - אין תוצאה ואין כותרת חסרה', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, const []);
      expect(result.index, isNull);
      expect(result.missingSegment, isNull);
    });

    test('כותרת עמוקה שנכתבה כרמה אחת בלבד נמצאת', () {
      final result = HtmlLinkHandler.resolveHeaderPath(toc, ['סימן ב']);
      expect(result.missingSegment, isNull);
      expect(result.reachedHeader, 'סימן ב');
    });
  });

  group('findIdAnchorLine', () {
    final lines = [
      'שורת גמרא רגילה',
      'טקסט עם סימן <a href="#footnote-1" id="noteref-1">[1]</a> בגוף',
      '<a href="#noteref-1" id="footnote-1">[1]</a> גוף ההערה הראשונה',
      '<a href="#noteref-11" id="footnote-11">[11]</a> גוף ההערה האחת-עשרה',
    ];

    test('קישור #footnote-1 מגיע לשורת גוף ההערה', () {
      expect(HtmlLinkHandler.findIdAnchorLine(lines, 'footnote-1'), 2);
    });

    test('קישור חזרה #noteref-1 מגיע לשורת הסימן בגוף', () {
      expect(HtmlLinkHandler.findIdAnchorLine(lines, 'noteref-1'), 1);
    });

    test('href="#..." לבדו אינו עוגן - id שאינו קיים לא נמצא', () {
      expect(HtmlLinkHandler.findIdAnchorLine(lines, 'footnote-2'), isNull);
    });

    test('אין התאמת קידומת - footnote-1 אינו תופס את footnote-11', () {
      expect(HtmlLinkHandler.findIdAnchorLine(lines, 'footnote-11'), 3);
    });

    test('כותרת עברית רגילה אינה מזוהה כעוגן', () {
      expect(HtmlLinkHandler.findIdAnchorLine(lines, 'דף ב'), isNull);
    });

    test('fragment ריק או היררכי אינו עוגן', () {
      expect(HtmlLinkHandler.findIdAnchorLine(lines, ''), isNull);
      expect(HtmlLinkHandler.findIdAnchorLine(lines, 'א#ב'), isNull);
    });
  });
}
