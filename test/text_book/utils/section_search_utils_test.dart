import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/utils/section_search_utils.dart';

void main() {
  tearDown(() async {
    await resetSectionSearchWorkerForTesting();
  });

  group('searchInContent - whole word matching', () {
    test('finds exact whole-word match', () async {
      final results = await searchInContent(
        content: ['שמע ישראל'],
        query: 'שמע',
      );
      expect(results.length, 1);
    });

    test('does not match partial word (query is prefix of longer word)',
        () async {
      final results = await searchInContent(
        content: ['שמעון'],
        query: 'שמע',
      );
      expect(results, isEmpty);
    });

    test('does not match partial word (query is suffix of longer word)',
        () async {
      final results = await searchInContent(
        content: ['ושמע'],
        query: 'שמע',
      );
      expect(results, isEmpty);
    });

    test('does not match partial word (query is infix of longer word)',
        () async {
      final results = await searchInContent(
        content: ['ושמעון'],
        query: 'שמע',
      );
      expect(results, isEmpty);
    });

    test('finds word at beginning of line', () async {
      final results = await searchInContent(
        content: ['ישראל עם'],
        query: 'ישראל',
      );
      expect(results.length, 1);
    });

    test('finds word at end of line', () async {
      final results = await searchInContent(
        content: ['עם ישראל'],
        query: 'ישראל',
      );
      expect(results.length, 1);
    });

    test('finds word surrounded by punctuation', () async {
      final results = await searchInContent(
        content: ['(שמע)'],
        query: 'שמע',
      );
      expect(results.length, 1);
    });

    test('does not match when query appears only as partial in all occurrences',
        () async {
      final results = await searchInContent(
        content: ['שמעון ושמעיהו'],
        query: 'שמע',
      );
      expect(results, isEmpty);
    });

    test('finds match when one occurrence is whole word and another is partial',
        () async {
      final results = await searchInContent(
        content: ['שמע ושמעון'],
        query: 'שמע',
      );
      expect(results.length, 1);
    });

    test('returns empty for empty content', () async {
      final results = await searchInContent(
        content: [],
        query: 'שמע',
      );
      expect(results, isEmpty);
    });

    test('returns empty for empty query', () async {
      final results = await searchInContent(
        content: ['שמע ישראל'],
        query: '',
      );
      expect(results, isEmpty);
    });
  });

  group('matchFractionInLine', () {
    test('מילה בתחילת השורה — שבר 0', () {
      expect(matchFractionInLine('ישראל עם קדוש', 'ישראל'), 0);
    });

    test('מילה בסוף השורה — שבר גבוה', () {
      expect(matchFractionInLine('שמע ישראל', 'ישראל'), greaterThan(0.3));
    });

    test('שאילתה מנוקדת מול שורה מנוקדת', () {
      final fraction =
          matchFractionInLine('בְּרֵאשִׁית בָּרָא אֱלֹהִים', 'אלהים');
      expect(fraction, greaterThan(0.5));
    });

    test('אין התאמה — שבר 0', () {
      expect(matchFractionInLine('שמע ישראל', 'משה'), 0);
    });

    test('שורה ריקה — שבר 0', () {
      expect(matchFractionInLine('', 'שמע'), 0);
    });
  });

  group('queryMatchesInlineNoteOnly', () {
    const noteLine = 'שלום עולם '
        '<sup class="footnote-marker">1</sup>'
        '<i class="footnote">כאן מופיע דין מיוחד</i>';

    test('מונח שנמצא רק בגוף ההערה — אמת', () {
      expect(queryMatchesInlineNoteOnly(noteLine, 'דין'), isTrue);
    });

    test('מונח שנמצא בטקסט הראשי — שקר (אין צורך בחלונית ההערות)', () {
      expect(queryMatchesInlineNoteOnly(noteLine, 'שלום'), isFalse);
    });

    test('מונח שאינו קיים כלל — שקר', () {
      expect(queryMatchesInlineNoteOnly(noteLine, 'משה'), isFalse);
    });

    test('שורה ללא הערת שוליים — שקר', () {
      expect(queryMatchesInlineNoteOnly('שלום עולם דין', 'דין'), isFalse);
    });

    test('התאמה חלקית בהערה (תת-מחרוזת) אינה נספרת', () {
      expect(queryMatchesInlineNoteOnly(noteLine, 'די'), isFalse);
    });

    test('מונח מנוקד מול הערה — מתעלם מניקוד', () {
      const vocalized = 'פתיחה '
          '<sup class="footnote-marker">2</sup>'
          '<i class="footnote">אֱלֹהִים חיים</i>';
      expect(queryMatchesInlineNoteOnly(vocalized, 'אלהים'), isTrue);
    });

    test('שאילתה ריקה — שקר', () {
      expect(queryMatchesInlineNoteOnly(noteLine, ''), isFalse);
    });
  });
}
