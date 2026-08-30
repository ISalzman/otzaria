import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/cache/books_cache.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';

/// issue #839 — "מא" לא החזיר את יומא.
///
/// התאמת תת-מחרוזת (matchRank=2) קיימת ופועלת במטמון הספרים — "ומא" ו-"כה"
/// כן מחזירים את יומא/סוכה. "מא" נכשל כי ההתאמות המוכלות מורעבות בשתי שכבות:
///   א. ה-limit של [ReferenceBooksCache.search] מתמלא כולו בהתאמות-תחילית
///      (56 ספרי "מא..." > 50) וההתאמות המוכלות שממוזגות אחריהן נחתכות.
///   ב. ה-cap מודע-הרלוונטיות של _rankResults (20) — כל התאמות-התחילית
///      גוברות בדירוג, וההתאמות המוכלות שמעבר לגבול נמחקות.
/// חוסר העקביות בין "מא" ל-"ומא" הוא הבאג; מדיניות הדירוג אינה משתנה —
/// התאמות-תחילית נשארות ראשונות, וההתאמות המוכלות מובטחות בזנב הרשימה.
ReferenceBookHit _hit({
  required int bookId,
  required String title,
  int matchRank = 0,
  double orderIndex = 0.0,
}) => ReferenceBookHit(
  bookId: bookId,
  title: title,
  normalizedTitle: title,
  filePath: '',
  fileType: 'txt',
  matchRank: matchRank,
  orderIndex: orderIndex,
);

void main() {
  group('ReferenceBooksCache.search — הרעבת contains ע"י ה-limit', () {
    final cache = ReferenceBooksCache.instance;

    tearDown(() {
      cache.clear();
      BooksCache.instance.clear();
    });

    test('התאמות-תחילית שממלאות את ה-limit לא מוחקות התאמת תת-מחרוזת', () {
      final books = <BookCacheEntry>[
        for (var i = 0; i < 55; i++)
          BookCacheEntry(
            id: i + 10,
            title: 'מאירי על מסכת $i',
            filePath: null,
            fileType: 'txt',
            categoryId: 1,
            orderIndex: 100.0 + i,
          ),
        BookCacheEntry(
          id: 1,
          title: 'יומא',
          filePath: null,
          fileType: 'txt',
          categoryId: 1,
          orderIndex: 5.0,
        ),
      ];
      BooksCache.instance.setBooksForTesting(books);
      cache.seedForTesting(
        normalizedTitles: {for (final b in books) b.id: b.title},
        categoryPaths: {for (final b in books) b.id: ''},
      );

      final hits = cache.search('מא', limit: 50);

      expect(hits.length, lessThanOrEqualTo(50));
      expect(
        hits.map((h) => h.title),
        contains('יומא'),
        reason: '55 התאמות-תחילית אסור שידחקו את יומא (contains) מהתוצאות',
      );
      expect(
        hits.first.title,
        startsWith('מא'),
        reason: 'התאמות-התחילית נשארות ראשונות — הדירוג לא השתנה',
      );
    });

    test('בלי גלישה מעל ה-limit — המיזוג הקיים נשאר כמות שהוא', () {
      final books = <BookCacheEntry>[
        for (var i = 0; i < 5; i++)
          BookCacheEntry(
            id: i + 10,
            title: 'מאירי על מסכת $i',
            filePath: null,
            fileType: 'txt',
            categoryId: 1,
            orderIndex: 100.0 + i,
          ),
        BookCacheEntry(
          id: 1,
          title: 'יומא',
          filePath: null,
          fileType: 'txt',
          categoryId: 1,
          orderIndex: 5.0,
        ),
      ];
      BooksCache.instance.setBooksForTesting(books);
      cache.seedForTesting(
        normalizedTitles: {for (final b in books) b.id: b.title},
        categoryPaths: {for (final b in books) b.id: ''},
      );

      final hits = cache.search('מא', limit: 50);

      expect(hits.length, 6);
      expect(hits.last.title, 'יומא', reason: 'contains אחרי כל ה-starts');
    });
  });

  group('findRefs — ה-cap של הדירוג לא מוחק התאמות תת-מחרוזת', () {
    FindRefRepository buildRepo(List<ReferenceBookHit> hits) {
      return FindRefRepository(
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) => hits,
        getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async =>
            const [],
        getAllAltTocFlatEntries: () async => const [],
        getCategoryPathSync: (_) => null,
      );
    }

    test('"מא" מחזיר את יומא גם כשהתאמות-תחילית ממלאות את ה-cap', () async {
      final repo = buildRepo([
        for (var i = 0; i < 30; i++)
          _hit(
            bookId: i + 10,
            title: 'מאירי על מסכת $i',
            matchRank: 1,
            orderIndex: 100.0 + i,
          ),
        _hit(bookId: 1, title: 'יומא', matchRank: 2, orderIndex: 5.0),
      ]);

      final results = await repo.findRefs('מא');
      final titles = results.map((r) => r.title).toList();

      expect(
        titles,
        contains('יומא'),
        reason: 'התאמת תת-מחרוזת חייבת לשרוד את חיתוך הרלוונטיות',
      );
      expect(
        titles.indexOf('יומא'),
        greaterThan(titles.indexOf('מאירי על מסכת 0')),
        reason: 'ההתאמה המוכלת מדורגת אחרי התאמות-התחילית — המדיניות לא השתנתה',
      );
    });

    test('בלי גלישה מעל ה-cap — הסדר הקיים לא משתנה', () async {
      final repo = buildRepo([
        for (var i = 0; i < 3; i++)
          _hit(
            bookId: i + 10,
            title: 'מאירי על מסכת $i',
            matchRank: 1,
            orderIndex: 100.0 + i,
          ),
        _hit(bookId: 1, title: 'יומא', matchRank: 2, orderIndex: 5.0),
      ]);

      final results = await repo.findRefs('מא');
      final titles = results.map((r) => r.title).toList();

      expect(titles.length, 4);
      expect(titles.last, 'יומא');
    });
  });
}
