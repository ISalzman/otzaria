import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/dictionary/dictionary_context_menu_entries.dart';
import 'package:otzaria/tools/dictionary/repository/dictionary_lookup_repository.dart';

void main() {
  group('DictionaryLookupRepository', () {
    late DictionaryLookupRepository repository;

    setUp(() {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'רש"י': <String>['רבי שלמה יצחקי', 'רבן של ישראל'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(aramaic: 'אבא', hebrew: 'יער'),
          AramaicDictionaryEntry(aramaic: 'בר אבא', hebrew: 'בן היער'),
          AramaicDictionaryEntry(aramaic: 'אבוה', hebrew: 'אביו'),
        ],
      );
    });

    test('מוצא ראשי תיבות גם עם גרשיים עבריים', () async {
      await repository.ensureLoaded();

      final entry = repository.findAcronym('רש״י');

      expect(entry, isNotNull);
      expect(entry!.meanings, contains('רבי שלמה יצחקי'));
      expect(entry.meanings, contains('רבן של ישראל'));
    });

    test('מחזיר צירופים ארמיים רק אם המילה קיימת כמונח במילון', () async {
      await repository.ensureLoaded();

      final matches = repository.findAramaicMatches('אבא');

      expect(matches.map((entry) => entry.aramaic), <String>[
        'אבא',
        'בר אבא',
      ]);
    });

    test('לא מחזיר צירופים אם המילה לא קיימת במילון כמונח עצמאי', () async {
      await repository.ensureLoaded();

      final matches = repository.findAramaicMatches('אביו');

      expect(matches, isEmpty);
    });
  });

  group('AramaicDictionaryEntryPresentation', () {
    test('מפרק פירושים מרובים לצורות תצוגה נפרדות', () {
      final presentation = AramaicDictionaryEntryPresentation.parse(
        '{אַהֲנֵי} הועיל *** {אַהָנֵי} (=א הני) על אלה',
      );

      expect(presentation.meanings, hasLength(2));
      expect(presentation.meanings.first.expression, 'אַהֲנֵי');
      expect(presentation.meanings.first.mainText, 'הועיל');
      expect(presentation.meanings.first.expansion, isNull);
      expect(presentation.meanings.last.expression, 'אַהָנֵי');
      expect(presentation.meanings.last.mainText, 'על אלה');
      expect(presentation.meanings.last.expansion, 'א הני');
    });

    test('מפרק גם הסבר שמופיע בתחילת הפירוש בלי ציטוט', () {
      final presentation = AramaicDictionaryEntryPresentation.parse(
        '(=אם תימצי לומר) אם תשיב לשאלה הקודמת באופן זה',
      );

      expect(presentation.meanings, hasLength(1));
      expect(presentation.meanings.single.expression, isNull);
      expect(
        presentation.meanings.single.mainText,
        'אם תשיב לשאלה הקודמת באופן זה',
      );
      expect(presentation.meanings.single.expansion, 'אם תימצי לומר');
    });
  });

  group('buildDictionaryContextMenuEntries', () {
    late DictionaryLookupRepository repository;

    setUp(() {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'רש"י': <String>['רבי שלמה יצחקי'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(
            aramaic: 'אבא',
            hebrew: '{אַבָּא} אב *** {אֲבָא} רוצה',
          ),
        ],
      );
    });

    testWidgets('בונה תפריט משנה לראשי תיבות', (tester) async {
      await repository.ensureLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: 'רש״י',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });

    testWidgets('בונה תפריט משנה למילה ארמית רגילה', (tester) async {
      await repository.ensureLoaded();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final entries = buildDictionaryContextMenuEntries(
        context: context,
        selectedText: 'אבא',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });
  });
}
