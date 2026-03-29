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

  group('buildDictionaryContextMenuEntries', () {
    late DictionaryLookupRepository repository;

    setUp(() async {
      repository = DictionaryLookupRepository(
        loadAcronyms: () async => <String, List<String>>{
          'רש"י': <String>['רבי שלמה יצחקי'],
        },
        loadAramaicEntries: () async => const <AramaicDictionaryEntry>[
          AramaicDictionaryEntry(aramaic: 'אבא', hebrew: 'יער'),
        ],
      );

      await repository.ensureLoaded();
    });

    test('בונה תפריט משנה לראשי תיבות', () {
      final entries = buildDictionaryContextMenuEntries(
        selectedText: 'רש״י',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });

    test('בונה תפריט משנה למילה ארמית רגילה', () {
      final entries = buildDictionaryContextMenuEntries(
        selectedText: 'אבא',
        repository: repository,
      );

      expect(entries, hasLength(1));
    });
  });
}
