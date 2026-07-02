import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/utils/link_anchor_markers.dart';

Link _anchorLink({
  required String heRef,
  required String path2,
  int? anchorStart,
  String? anchorLabel,
}) {
  return Link(
    heRef: heRef,
    index1: 4,
    path2: path2,
    index2: 1,
    connectionType: 'commentary',
    anchorStart: anchorStart,
    anchorEnd: null,
    anchorLabel: anchorLabel,
  );
}

void main() {
  group('anchorMarkerLetter', () {
    test('מעדיף את התווית השמורה במסד', () {
      final link = _anchorLink(
        heRef: 'באר הגולה על שולחן ערוך אורח חיים א, ב',
        path2: 'באר הגולה על שולחן ערוך אורח חיים',
        anchorStart: 35,
        anchorLabel: 'א',
      );
      expect(anchorMarkerLetter(link), 'א');
    });

    test('נגזר מהרכיב האחרון של heRef כשאין תווית', () {
      final link = _anchorLink(
        heRef: 'טורי זהב על שולחן ערוך אורח חיים א, ז',
        path2: 'טורי זהב על שולחן ערוך אורח חיים',
        anchorStart: 35,
      );
      expect(anchorMarkerLetter(link), 'ז');
    });

    test('גרשיים בתוך האות נשמרים בתצוגה', () {
      final link = _anchorLink(
        heRef: 'משנה ברורה,  א, קכ"ט',
        path2: 'משנה ברורה',
        anchorStart: 10,
      );
      expect(anchorMarkerLetter(link), 'קכ"ט');
    });

    test('רכיב אחרון שאינו גימטריה — אין אות', () {
      final link = _anchorLink(
        heRef: 'פירוש כלשהו, פסקה ארוכה מאוד שאינה אות',
        path2: 'פירוש כלשהו',
        anchorStart: 5,
      );
      expect(anchorMarkerLetter(link), isNull);
    });
  });

  group('injectLinkAnchorMarkers', () {
    // שורת שולחן ערוך או"ח א:א כפי שהיא שמורה במסד (הקטע הרלוונטי): התגים
    // המקוריים של ספריא אינם נספרים כתווים גלויים, והעוגן של באר הגולה יושב
    // באופסט גלוי 35 — מיד לפני "יתגבר".
    const saLine = '(א) <b>דין השכמת הבוקר. ובו ט סעיפים:</b> '
        '<i data-commentator="Be\'er HaGolah" data-label="א" data-order="1"></i>'
        '<i data-commentator="Turei Zahav" data-order="1"></i>יתגבר '
        '<i data-commentator="Ba\'er Hetev" data-order="1"></i>כארי לעמוד בבוקר';

    test('סמן מוזרק בדיוק לפני המילה המעוגנת, בתוך תוכן אמיתי', () {
      final bhg = _anchorLink(
        heRef: 'באר הגולה על שולחן ערוך אורח חיים א, א',
        path2: 'באר הגולה על שולחן ערוך אורח חיים',
        anchorStart: 35,
        anchorLabel: 'א',
      );
      final result = injectLinkAnchorMarkers(
        rawLine: saLine,
        anchorLinks: [bhg],
        styleIndexByCommentator: const {
          'באר הגולה על שולחן ערוך אורח חיים': 0,
        },
      );
      expect(
        result,
        contains('<sup class="link-anchor link-anchor-0">(א)</sup>'),
      );
      // הסמן נכנס צמוד לפני "יתגבר" — אחרי תגי ה-itag הבלתי-נראים.
      final markerIndex = result.indexOf('<sup class="link-anchor');
      final wordIndex = result.indexOf('יתגבר');
      expect(markerIndex, lessThan(wordIndex));
      final between = result.substring(
          markerIndex +
              '<sup class="link-anchor link-anchor-0">(א)</sup>'.length,
          wordIndex);
      expect(between, isEmpty);
    });

    test('כמה מפרשים באותה שורה — סגנון שונה לכל אחד', () {
      final bhg = _anchorLink(
        heRef: 'באר הגולה על שולחן ערוך אורח חיים א, א',
        path2: 'באר הגולה על שולחן ערוך אורח חיים',
        anchorStart: 35,
        anchorLabel: 'א',
      );
      final baerHetev = _anchorLink(
        heRef: 'באר היטב אורח חיים א, א',
        path2: 'באר היטב אורח חיים',
        anchorStart: 41,
      );
      final styles = anchorStyleIndexByCommentator([bhg, baerHetev]);
      expect(styles.values.toSet().length, 2);

      final result = injectLinkAnchorMarkers(
        rawLine: saLine,
        anchorLinks: [bhg, baerHetev],
        styleIndexByCommentator: styles,
      );
      expect(result, contains('link-anchor-${styles[bhg.path2]}">(א)</sup>'));
      expect(
        result,
        contains('link-anchor-${styles[baerHetev.path2]}">(א)</sup>'),
      );
      // העוגן של באר היטב (41) יושב אחרי "יתגבר " — לפני "כארי".
      final hetevMarker =
          '<sup class="link-anchor link-anchor-${styles[baerHetev.path2]}">(א)</sup>';
      expect(result.indexOf(hetevMarker), lessThan(result.indexOf('כארי')));
      expect(result.indexOf(hetevMarker), greaterThan(result.indexOf('יתגבר')));
    });

    test('entity נספר כתו גלוי אחד', () {
      const line = 'אב&nbsp;גד';
      final link = _anchorLink(
        heRef: 'ספר כלשהו א, ב',
        path2: 'ספר כלשהו',
        anchorStart: 3,
        anchorLabel: 'ב',
      );
      final result = injectLinkAnchorMarkers(
        rawLine: line,
        anchorLinks: [link],
        styleIndexByCommentator: const {'ספר כלשהו': 1},
      );
      expect(
        result,
        'אב&nbsp;<sup class="link-anchor link-anchor-1">(ב)</sup>גד',
      );
    });

    test('עוגן מעבר לאורך השורה נצמד לסוף', () {
      final link = _anchorLink(
        heRef: 'ספר כלשהו א, ג',
        path2: 'ספר כלשהו',
        anchorStart: 999,
        anchorLabel: 'ג',
      );
      final result = injectLinkAnchorMarkers(
        rawLine: 'אבג',
        anchorLinks: [link],
        styleIndexByCommentator: const {'ספר כלשהו': 0},
      );
      expect(result, 'אבג<sup class="link-anchor link-anchor-0">(ג)</sup>');
    });

    test('שורה בלי עוגנים חוזרת כמות שהיא', () {
      expect(
        injectLinkAnchorMarkers(
          rawLine: saLine,
          anchorLinks: const [],
          styleIndexByCommentator: const {},
        ),
        saLine,
      );
    });
  });
}
