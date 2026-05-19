import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/repository/alt_toc_flat_entry.dart';
import 'package:otzaria/find_ref/repository/db_commentator_entry.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/services/commentary_service.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

class FindRefRepository {
  /// שמור לצורך תאימות לאחור עם call-sites קיימים.
  /// אינו בשימוש בפועל בקוד ה-repository.
  final DataRepository? dataRepository;

  final Future<void> Function()? warmUpReferenceBooksCache;
  final bool Function()? isReferenceBooksCacheLoaded;
  final List<ReferenceBookHit> Function(String query, {int limit})?
      searchReferenceBooks;
  final Future<List<Map<String, dynamic>>> Function(
    int bookId,
    String bookTitle, {
    List<String>? queryTokens,
  })? getTocEntriesForReference;

  final Future<List<Map<String, dynamic>>> Function(
    int bookId,
    String bookTitle, {
    List<String>? queryTokens,
  })? getAltTocEntriesForReference;

  /// Injection for testing: returns the global flat list of AltToc entries
  /// across all books, as raw rows. In production this calls
  /// [SeforimRepository.getAllAltTocFlatEntries].
  ///
  /// כל row כולל את המפתחות: `bookId`, `bookTitle`, `bookOrderIndex`,
  /// `reference` (נתיב מלא יחסי לספר), `segment`, `level`, `dbLineId`.
  ///
  /// מחליף את הזוג הישן (`getAllBooksWithAltToc` + לולאת
  /// `getAltTocEntriesForReference`) — המעבר ל-fetch יחיד חסך פעם 339
  /// שאילתות סדרתיות.
  final Future<List<Map<String, dynamic>>> Function()? getAllAltTocFlatEntries;

  /// Injection for testing: returns the category path string for a given bookId.
  /// In production this calls [ReferenceBooksCache.instance.getCategoryPathForBook].
  final Future<String> Function(int bookId)? getCategoryPath;

  /// Injection for testing: returns outline entries for a FS PDF file.
  /// In production this calls [ReferenceBooksCache.instance.getPdfOutlineEntries].
  final Future<List<(String, String, int)>> Function(String filePath)?
      getPdfOutlineEntries;

  /// Injection for testing: returns all books from the user personal books DB.
  /// Each record: (id, title, filePath, fileType, orderIndex).
  /// In production calls [UserBooksDatabaseHolder.instance.repository].
  final Future<
          List<
              ({
                int id,
                String title,
                String? filePath,
                String fileType,
                double orderIndex
              })>>
      Function()? getAllUserBooks;

  /// Injection for testing: returns TOC entries from the user personal books DB.
  /// In production calls [UserBooksDatabaseHolder.instance.repository].
  final Future<List<Map<String, dynamic>>> Function(
    int bookId,
    String bookTitle, {
    List<String>? queryTokens,
  })? getUserBookTocEntries;

  /// Injection for testing: returns commentator rows for a specific source line.
  /// In production calls [LinkDao.selectCommentatorsBySourceLine].
  ///
  /// כל row צפוי לכלול לפחות `targetBookTitle` ו-`targetLineIndex` (השורה
  /// הראשונה בספר המפרש שמקושרת לשורת המקור).
  final Future<List<Map<String, dynamic>>> Function(int sourceLineId)?
      selectCommentatorsBySourceLine;

  /// Injection for testing: returns commentator rows for a whole book.
  /// In production calls [LinkDao.selectCommentatorsByBook].
  ///
  /// אין כאן `targetLineIndex` משמעותי לכל מפרש; הקוד נופל ל-best-effort
  /// (`ref.segment.toInt()`) בהנחת alignment שורה-שורה.
  final Future<List<Map<String, dynamic>>> Function(int bookId)?
      selectCommentatorsByBook;

  /// Injection for testing: מחזירה את הדור של מפרש לפי שם.
  /// In production calls [CommentaryService.getBookEra].
  final Future<CommentaryEra> Function(String bookTitle)? getBookEra;

  /// קאש בזיכרון: מפתח = "bookId:sourceLineId" (sourceLineId=0 כשנופלים ל-book-level).
  /// חי כל זמן שה-repository חי. אינו מתנקה אוטומטית — קטן יחסית
  /// (לכל היותר ~15 מפתחות פר session, רוב המשתמשים פחות).
  final Map<String, List<DbCommentatorEntry>> _commentatorsCache = {};

  /// קאש שטוח של כל ערכי ה-AltToc על פני כל הספרים. נבנה lazy בקריאה
  /// הראשונה ל-fallback הגלובלי, ומשרת את כל ה-sessions שלאחר מכן.
  /// השדה נשמר ברמת ה-instance של [FindRefRepository] (singleton באפליקציה).
  List<AltTocFlatEntry>? _altTocFlatCache;

  FindRefRepository({
    this.dataRepository,
    this.warmUpReferenceBooksCache,
    this.isReferenceBooksCacheLoaded,
    this.searchReferenceBooks,
    this.getTocEntriesForReference,
    this.getAltTocEntriesForReference,
    this.getAllAltTocFlatEntries,
    this.getCategoryPath,
    this.getPdfOutlineEntries,
    this.getAllUserBooks,
    this.getUserBookTocEntries,
    this.selectCommentatorsBySourceLine,
    this.selectCommentatorsByBook,
    this.getBookEra,
  });

  /// מחזיר את הקאש הגלובלי של AltToc; טוען אותו פעם אחת בקריאה הראשונה
  /// ושומר ב-[_altTocFlatCache]. כל קריאה לאחר מכן היא in-memory.
  ///
  /// הקריאה הזו אמורה להיות בטוחה לכשלון: אם השאילתה נופלת או שערך כלשהו
  /// אינו במבנה הצפוי — מוחזר רשימה ריקה (ולא מתפשטת חריגה). כך מסלול
  /// ה-per-book בתוך `findRefs` מתמיד גם אם ה-AltToc הגלובלי תקול.
  Future<List<AltTocFlatEntry>> _getAltTocFlatCache() async {
    final cached = _altTocFlatCache;
    if (cached != null) return cached;

    try {
      final fn = getAllAltTocFlatEntries;
      final rows = fn != null
          ? await fn()
          : (await SqliteDataProvider.instance.repository
                  ?.getAllAltTocFlatEntries() ??
              const <Map<String, dynamic>>[]);

      final list = <AltTocFlatEntry>[];
      for (final r in rows) {
        final reference = r['reference'] as String;
        final refTokens = _tokenize(_normalizeForMatch(reference));
        list.add(AltTocFlatEntry(
          bookId: r['bookId'] as int,
          bookTitle: r['bookTitle'] as String,
          // `book.orderIndex` הוא INTEGER NOT NULL בסכמה, אבל לא רוצים לסכן
          // ב-cast קשיח אם בעתיד יוסיפו ספרים בלי orderIndex.
          bookOrderIndex: (r['bookOrderIndex'] as num?)?.toDouble() ?? 999.0,
          reference: reference,
          segment: r['segment'] as int? ?? 0,
          level: r['level'] as int? ?? 0,
          dbLineId: r['dbLineId'] as int? ?? 0,
          refTokens: refTokens,
        ));
      }
      _altTocFlatCache = list;
      return list;
    } catch (e, st) {
      debugPrint('[FindRef] AltToc flat cache build failed: $e\n$st');
      // אל **תקבע** את הקאש לריק במקרה כשל — אם הסיבה הייתה זמנית
      // (rebuild של DB, lock רגעי), שאילתה הבאה תקבל ניסיון חוזר.
      // אם הכשל קבוע, ההשהיה ב-await יחזור ולא מקסים נזק.
      return const [];
    }
  }

  /// מחזיר רשימת רשומות מפרשים זמינים עבור תוצאה, מוכנות לפתיחה ישירה.
  ///
  /// כל [DbCommentatorEntry.targetSegment] הוא:
  ///   - `int` במסלול segment-level — `MIN(targetLineIndex)` של הקישורים
  ///     היוצאים מהשורה למפרש (=הקטע הראשון של המפרש על אותה שורה).
  ///   - `null` במסלול book-level — על הצרכן ליפול ל-best-effort
  ///     (`ref.segment.toInt()`) בהנחת alignment שורה-שורה.
  ///
  /// חשוב: `targetSegment` אינו תלוי ב-`ref.segment`. הקאש ממופתח לפי
  /// `bookId:sourceLineId` בלבד, ולכן שני refs עם אותו `bookId` ו-`sourceLineId == 0`
  /// אך `segment` שונה חולקים את אותה רשומה — והפתרון של ה-fallback חייב
  /// להישאר באחריות הצרכן.
  ///
  /// אסטרטגיה:
  /// 1. אם [DbReferenceResult.sourceLineId] > 0 — שאילתה segment-level
  ///    (`selectCommentatorsBySourceLine`). מחזירה גם `targetLineIndex`.
  /// 2. אחרת (או אם segment-level חזר ריק) — שאילתה book-level לכל הספר;
  ///    `targetSegment` יישאר `null`.
  /// 3. PDFs / ספרים מחוץ ל-DB (bookId <= 0) / ספרים אישיים — מחזיר ריק.
  ///    ספרים אישיים: ה-bookId/sourceLineId שלהם שייכים ל-user_books.db ולא
  ///    מתאימים ל-link table של ה-DB הראשי — שאילתה תחזיר מפרשים שגויים.
  ///
  /// תוצאות נשמרות בקאש בזיכרון לאורך חיי ה-repository.
  Future<List<DbCommentatorEntry>> getCommentatorsForResult(
      DbReferenceResult ref) async {
    if (ref.isPdf || ref.bookId <= 0 || ref.isUserBook) return const [];

    final cacheKey = '${ref.bookId}:${ref.sourceLineId}';
    final cached = _commentatorsCache[cacheKey];
    if (cached != null) return cached;

    final repository = SqliteDataProvider.instance.repository;
    final lineFn = selectCommentatorsBySourceLine ??
        (repository == null
            ? null
            : (int lineId) => repository.database.linkDao
                .selectCommentatorsBySourceLine(lineId));
    final bookFn = selectCommentatorsByBook ??
        (repository == null
            ? null
            : (int bookId) =>
                repository.database.linkDao.selectCommentatorsByBook(bookId));

    if (lineFn == null && bookFn == null) return const [];

    List<Map<String, dynamic>> rows = const [];
    var usedSegmentLevel = false;
    if (ref.sourceLineId > 0 && lineFn != null) {
      rows = await lineFn(ref.sourceLineId);
      usedSegmentLevel = rows.isNotEmpty;
    }
    if (rows.isEmpty && bookFn != null) {
      rows = await bookFn(ref.bookId);
    }

    final titles = <String>[];
    final segmentByTitle = <String, int?>{};
    for (final row in rows) {
      final title = row['targetBookTitle'] as String?;
      if (title == null || title.isEmpty) continue;
      if (segmentByTitle.containsKey(title)) continue;

      // segment-level → `targetLineIndex` אם ה-row כולל אותו, אחרת null;
      // book-level → null (הצרכן יפתור לפי ref.segment).
      final int? segment =
          usedSegmentLevel ? row['targetLineIndex'] as int? : null;
      titles.add(title);
      segmentByTitle[title] = segment;
    }

    if (titles.isEmpty) {
      _commentatorsCache[cacheKey] = const [];
      return const [];
    }

    // מיון לפי סדר הדורות (תורה → חז"ל → ראשונים → אחרונים → מודרני → שאר),
    // ובתוך כל דור — אלפביתי. תואם להתנהגות תפריט המפרשים ב-text-book viewer.
    final eraResolver = getBookEra ?? CommentaryService.getBookEra;
    final eras = await Future.wait(titles.map(eraResolver));
    final indices = List<int>.generate(titles.length, (i) => i)
      ..sort((a, b) {
        final ea = eras[a];
        final eb = eras[b];
        if (ea.order != eb.order) return ea.order.compareTo(eb.order);
        return titles[a].compareTo(titles[b]);
      });
    final sorted = [
      for (final i in indices)
        DbCommentatorEntry(
          title: titles[i],
          targetSegment: segmentByTitle[titles[i]],
        ),
    ];

    _commentatorsCache[cacheKey] = sorted;
    return sorted;
  }

  Future<List<DbReferenceResult>> findRefs(
    String ref, {
    bool includePersonalBooks = false,
  }) async {
    final cleanedQuery = _normalizeForMatch(ref);
    if (cleanedQuery.isEmpty) {
      return const [];
    }

    final queryTokens = _tokenize(cleanedQuery);
    if (queryTokens.isEmpty) {
      return const [];
    }

    final SeforimRepository? repository =
        SqliteDataProvider.instance.repository;
    if (repository == null && getTocEntriesForReference == null) {
      debugPrint('[FindRef] Database not initialized');
      return const [];
    }

    Future<List<Map<String, dynamic>>> fetchTocEntries(
      int bookId,
      String bookTitle, {
      List<String>? queryTokens,
    }) {
      final injected = getTocEntriesForReference;
      if (injected != null) {
        return injected(bookId, bookTitle, queryTokens: queryTokens);
      }
      return repository!.getTocEntriesForReference(
        bookId,
        bookTitle,
        queryTokens: queryTokens,
      );
    }

    Future<List<Map<String, dynamic>>> fetchAltTocEntries(
      int bookId,
      String bookTitle, {
      List<String>? queryTokens,
    }) {
      final injected = getAltTocEntriesForReference;
      if (injected != null) {
        return injected(bookId, bookTitle, queryTokens: queryTokens);
      }
      return repository?.getAltTocEntriesForReference(
            bookId,
            bookTitle,
            queryTokens: queryTokens,
          ) ??
          Future.value(const []);
    }

    final cacheLoaded = isReferenceBooksCacheLoaded?.call() ??
        ReferenceBooksCache.instance.isLoaded;
    if (!cacheLoaded) {
      await (warmUpReferenceBooksCache?.call() ??
          ReferenceBooksCache.instance.warmUp());
    }

    final searchBooks =
        searchReferenceBooks ?? ReferenceBooksCache.instance.search;

    // Prefer matching the longest leading phrase (up to 3 tokens) as the book key.
    // This supports multi-word acronyms like "שוע אוח".
    final maxPhraseTokens = queryTokens.length >= 3 ? 3 : queryTokens.length;
    var bookQueryTokenCount = 1;
    List<ReferenceBookHit> bookHits = const <ReferenceBookHit>[];
    for (var n = maxPhraseTokens; n >= 1; n--) {
      final phrase = queryTokens.take(n).join(' ');
      final hits = searchBooks(phrase, limit: 50);
      if (hits.isEmpty) continue;

      // For single-token queries, keep all hits as usual.
      if (n == 1) {
        bookHits = hits;
        bookQueryTokenCount = n;
        break;
      }

      // For multi-token phrases: only accept a hit if every query token at
      // position i (0-indexed) starts a word at position i in the book title.
      // This prevents "בראשית א" from matching "גור אריה על בראשית פסוק א"
      // (matchRank=2, "א" appears in the 5th word, not the 2nd).
      // Acronym hits (matchRank >= 3) are accepted without this restriction
      // because the phrase matched as a whole acronym.
      // Contains-only hits (matchRank == 2) are always excluded for multi-token
      // phrases: "גור אריה על בראשית" should never be selected when the user
      // types "בראשית א".
      final phraseTokens = queryTokens.take(n).toList();
      final qualifiedHits = hits.where((hit) {
        if (hit.matchRank >= 3) return true; // acronym match – always accept
        if (hit.matchRank == 2) {
          return false; // contains-only – never accept for n>1
        }
        // הכותרת המנורמלת כבר מחושבת מראש בתוך הקאש.
        final titleTokens = _tokenize(hit.normalizedTitle);
        // Every phrase token at index i must match the start of title token i.
        for (var i = 0; i < phraseTokens.length; i++) {
          if (i >= titleTokens.length) return false;
          if (!titleTokens[i].startsWith(phraseTokens[i])) return false;
        }
        return true;
      }).toList();

      if (qualifiedHits.isNotEmpty) {
        bookHits = qualifiedHits;
        bookQueryTokenCount = n;
        break;
      }
    }

    debugPrint(
        '[FindRef] Found ${bookHits.length} books matching leading phrase (memory)');

    final results = <DbReferenceResult>[];

    // Single-word query: do NOT search TOC at all.
    if (queryTokens.length == 1) {
      for (final hit in bookHits) {
        final isPdf = hit.fileType == 'pdf';

        results.add(DbReferenceResult(
          title: hit.title,
          reference: hit.title,
          segment: 0,
          isPdf: isPdf,
          filePath: hit.filePath,
          orderIndex: hit.orderIndex,
          bookId: hit.bookId,
        ));
      }

      if (includePersonalBooks) {
        results.addAll(await _searchPersonalBooks(queryTokens));
      }

      final unique = _dedupeRefs(results);
      final ranked = _rankResults(unique, queryTokens);
      final limited = ranked.length > 15 ? ranked.take(15).toList() : ranked;
      return await _enrichWithPaths(limited);
    }

    // If the *next* token after the matched book-phrase is an exact book match,
    // avoid TOC search to prevent cross-book false positives.
    final nextTokenIndex = bookQueryTokenCount;
    final nextToken =
        queryTokens.length > nextTokenIndex ? queryTokens[nextTokenIndex] : '';
    final nextTokenMatches = nextToken.isEmpty
        ? const <ReferenceBookHit>[]
        : searchBooks(nextToken, limit: 50);
    final hasExactNextTokenMatch =
        nextTokenMatches.any((hit) => hit.matchRank == 0);

    for (final hit in bookHits) {
      final bookId = hit.bookId;
      final title = hit.title;
      final isPdf = hit.fileType == 'pdf';

      // הכותרת המנורמלת כבר זמינה מהקאש — אין צורך לנרמל מחדש.
      final titleTokens = _tokenize(hit.normalizedTitle);
      final matchedByAcronym = hit.matchRank >= 3;
      final remainingTokens = _getRemainingTokens(
        queryTokens,
        titleTokens,
        stripLeadingTokensCount: matchedByAcronym ? bookQueryTokenCount : 0,
      );

      // bookId == -1: file-system PDF not in DB — use PDF outline as TOC,
      // mirroring the regular book flow as closely as possible.
      if (bookId == -1) {
        final outlineFn = getPdfOutlineEntries ??
            ReferenceBooksCache.instance.getPdfOutlineEntries;
        final outlineEntries = await outlineFn(hit.filePath);
        final normalizedBookTitle = _normalizeForMatch(title);

        if (remainingTokens.isEmpty) {
          // Mirror regular book: add the book title + all top-level outline entries.
          results.add(DbReferenceResult(
            title: title,
            reference: title,
            segment: 0,
            isPdf: true,
            filePath: hit.filePath,
            orderIndex: hit.orderIndex,
          ));
          for (final (normChapter, origChapter, pageNumber) in outlineEntries) {
            if (normChapter == normalizedBookTitle) continue;
            results.add(DbReferenceResult(
              title: title,
              reference: '$title $origChapter',
              segment: pageNumber,
              isPdf: true,
              filePath: hit.filePath,
              orderIndex: hit.orderIndex,
              tocLevel: 2,
            ));
          }
        } else if (!hasExactNextTokenMatch) {
          // Mirror regular book: add ALL matching outline entries (not just first).
          for (final (normChapter, origChapter, pageNumber) in outlineEntries) {
            if (normChapter == normalizedBookTitle) continue;
            final chapterWords = _tokenize(normChapter);
            final matches = remainingTokens.every(
              (t) => chapterWords.any((w) => w.startsWith(t)),
            );
            if (!matches) continue;
            results.add(DbReferenceResult(
              title: title,
              reference: '$title $origChapter',
              segment: pageNumber,
              isPdf: true,
              filePath: hit.filePath,
              orderIndex: hit.orderIndex,
              tocLevel: 2,
            ));
          }
        }
        // FS PDFs have no DB category path — bookPath stays ''.
        continue;
      }

      if (remainingTokens.isEmpty) {
        final tocEntries = await fetchTocEntries(bookId, title);

        results.add(DbReferenceResult(
          title: title,
          reference: title,
          segment: 0,
          isPdf: isPdf,
          filePath: hit.filePath,
          orderIndex: hit.orderIndex,
          bookId: bookId,
        ));

        for (final entry in tocEntries) {
          final level = entry['level'] as int;
          if (level == 2 && entry['reference'] != title) {
            results.add(DbReferenceResult(
              title: title,
              reference: entry['reference'] as String,
              segment: entry['segment'] as int,
              isPdf: isPdf,
              filePath: hit.filePath,
              orderIndex: hit.orderIndex,
              tocLevel: level,
              bookId: bookId,
              sourceLineId: entry['dbLineId'] as int? ?? 0,
            ));
          }
        }
      } else if (!hasExactNextTokenMatch) {
        final tocEntries = await fetchTocEntries(
          bookId,
          title,
          queryTokens: remainingTokens,
        );

        for (final entry in tocEntries) {
          results.add(DbReferenceResult(
            title: title,
            reference: entry['reference'] as String,
            segment: entry['segment'] as int,
            isPdf: isPdf,
            filePath: hit.filePath,
            orderIndex: hit.orderIndex,
            tocLevel: entry['level'] as int,
            bookId: bookId,
            sourceLineId: entry['dbLineId'] as int? ?? 0,
          ));
        }

        // חיפוש בכותרות-משנה (AltToc): עליות, פרשות ומבנים חלופיים נוספים.
        // ה-reference של AltToc אינו כולל שם הספר (הוא יחסי — "פרשת לך לך עליה ו").
        final altTocEntries = await fetchAltTocEntries(
          bookId,
          title,
          queryTokens: remainingTokens,
        );
        for (final entry in altTocEntries) {
          final ref = entry['reference'] as String;
          // Require that all remaining tokens appear in the reference.
          // Prevents partial AltToc matches when the book was loosely matched
          // (e.g., "נחל שורק" matching "נח" returning "הפטרת נח" for "נח עליה ב").
          final refTokens = _tokenize(_normalizeForMatch(ref));
          if (!remainingTokens.every((qt) => refTokens.contains(qt))) continue;

          results.add(DbReferenceResult(
            title: title,
            reference: ref,
            segment: entry['segment'] as int,
            isPdf: isPdf,
            filePath: hit.filePath,
            orderIndex: hit.orderIndex,
            tocLevel: entry['level'] as int,
            isAltToc: true,
            bookId: bookId,
            sourceLineId: entry['dbLineId'] as int? ?? 0,
          ));
        }
      }
    }

    // Global AltToc fallback: when no specific result was found in the per-book
    // loop, search AltToc across all books. This handles queries like
    // "נח עליה ב" where the user doesn't type the book name, even if some
    // other book matched the first token (e.g., "תולדות יצחק" matching "תולדות").
    //
    // התנאי הוא **AltToc *או* TOC L2+ ריקים** — כלומר, גם הפניות פנימיות
    // רגילות נחשבות "ספציפיות". הסיבה: עם המעבר לקאש השטוח הגלובלי, הפילטר
    // הוא רק `every(contains)`, שמייצר הרבה false-positives של AltToc
    // מספרים עם orderIndex נמוך. אלה דוחקים החוצה תוצאות TOC PDF מספרים עם
    // orderIndex גבוה (כי `_rankResults` בודק orderIndex לפני tocLevel),
    // ובפועל גורם ל"ברכות ב" לא להציג את ה-PDF של ברכות. אם ה-per-book כבר
    // החזיר התאמה ספציפית, אין צורך ב-fallback — שום שאילתה ש"דורשת" כותרת
    // פנימית של ספר אחר.
    //
    // היסטורית הוזרמו 339 שאילתות SQL סדרתיות (אחת לכל ספר עם AltToc).
    // עכשיו אנחנו מחזיקים קאש שטוח שנבנה פעם אחת ב-session, וכל הסינון
    // הוא O(N) ב-Dart על רשימה in-memory.
    //
    // נעטף ב-try/catch כדי שכשלון במסלול ה-fallback לא יבלע את התוצאות
    // הקיימות מהלולאת ה-per-book.
    final bool perBookHasSpecificMatch =
        results.any((r) => r.isAltToc || r.tocLevel >= 2);
    if (!perBookHasSpecificMatch && queryTokens.length >= 2) {
      try {
        final flat = await _getAltTocFlatCache();
        for (final entry in flat) {
          // Require that ALL query tokens appear in the matched reference.
          // Prevents partial matches from unrelated books (e.g., "הפטרת נח"
          // matching only "נח" when the query is "נח עליה ב").
          if (!queryTokens.every((qt) => entry.refTokens.contains(qt))) {
            continue;
          }

          results.add(DbReferenceResult(
            title: entry.bookTitle,
            reference: entry.reference,
            segment: entry.segment,
            orderIndex: entry.bookOrderIndex,
            tocLevel: entry.level,
            isAltToc: true,
            bookId: entry.bookId,
            sourceLineId: entry.dbLineId,
          ));
        }
      } catch (e, st) {
        debugPrint('[FindRef] Global AltToc fallback failed: $e\n$st');
      }
    }

    if (includePersonalBooks) {
      results.addAll(await _searchPersonalBooks(queryTokens));
    }

    final unique = _dedupeRefs(results);
    final ranked = _rankResults(unique, queryTokens);
    final limited = ranked.length > 15 ? ranked.take(15).toList() : ranked;

    debugPrint('[FindRef] Final results: ${limited.length}');

    return await _enrichWithPaths(limited);
  }

  Future<List<DbReferenceResult>> _searchPersonalBooks(
    List<String> queryTokens,
  ) async {
    final out = <DbReferenceResult>[];
    try {
      // Resolve user books list (injection or live DB)
      final List<
          ({
            int id,
            String title,
            String? filePath,
            String fileType,
            double orderIndex
          })> allBooks;
      SeforimRepository? userRepo;

      if (getAllUserBooks != null) {
        allBooks = await getAllUserBooks!();
      } else {
        userRepo = await UserBooksDatabaseHolder.instance.repository;
        final raw = await userRepo.database.bookDao.getAllLocalBooks();
        allBooks = raw
            .map((b) => (
                  id: b.id,
                  title: b.title,
                  filePath: b.filePath,
                  fileType: b.fileType ?? 'txt',
                  orderIndex: b.order,
                ))
            .toList();
      }

      if (allBooks.isEmpty) return out;

      // Resolve user TOC fetcher (injection or live DB)
      Future<List<Map<String, dynamic>>> fetchUserToc(
        int bookId,
        String bookTitle, {
        List<String>? qt,
      }) {
        final injected = getUserBookTocEntries;
        if (injected != null) {
          return injected(bookId, bookTitle, queryTokens: qt);
        }
        userRepo ??=
            UserBooksDatabaseHolder.instance.repository as SeforimRepository;
        return (userRepo as SeforimRepository).getTocEntriesForReference(
          bookId,
          bookTitle,
          queryTokens: qt,
        );
      }

      const personalBookPath = 'ספרים אישיים';
      final maxN = queryTokens.length >= 3 ? 3 : queryTokens.length;

      for (final book in allBooks) {
        final normalizedTitle = _normalizeForMatch(book.title);
        final titleTokens = _tokenize(normalizedTitle);

        // Find the longest leading phrase that matches position-by-position
        int? matchedN;
        for (var n = maxN; n >= 1; n--) {
          final phrase = queryTokens.take(n).toList();
          if (phrase.length > titleTokens.length) continue;
          var ok = true;
          for (var i = 0; i < phrase.length; i++) {
            if (!titleTokens[i].startsWith(phrase[i])) {
              ok = false;
              break;
            }
          }
          if (ok) {
            matchedN = n;
            break;
          }
        }
        if (matchedN == null) continue;

        final isPdf = book.fileType == 'pdf';
        final remainingTokens = _getRemainingTokens(queryTokens, titleTokens);

        if (queryTokens.length == 1) {
          // Single-word: only the book title, no TOC (mirrors main loop)
          out.add(DbReferenceResult(
            title: book.title,
            reference: book.title,
            segment: 0,
            isPdf: isPdf,
            filePath: book.filePath ?? '',
            orderIndex: book.orderIndex,
            bookId: book.id,
            bookPath: personalBookPath,
            isUserBook: true,
          ));
        } else if (remainingTokens.isEmpty) {
          // Book title + all level-2 TOC entries
          out.add(DbReferenceResult(
            title: book.title,
            reference: book.title,
            segment: 0,
            isPdf: isPdf,
            filePath: book.filePath ?? '',
            orderIndex: book.orderIndex,
            bookId: book.id,
            bookPath: personalBookPath,
            isUserBook: true,
          ));
          final toc = await fetchUserToc(book.id, book.title);
          for (final entry in toc) {
            final level = entry['level'] as int;
            if (level == 2 && entry['reference'] != book.title) {
              out.add(DbReferenceResult(
                title: book.title,
                reference: entry['reference'] as String,
                segment: entry['segment'] as int,
                isPdf: isPdf,
                filePath: book.filePath ?? '',
                orderIndex: book.orderIndex,
                tocLevel: level,
                bookId: book.id,
                bookPath: personalBookPath,
                sourceLineId: entry['dbLineId'] as int? ?? 0,
                isUserBook: true,
              ));
            }
          }
        } else {
          // Only TOC entries matching remainingTokens
          final toc = await fetchUserToc(
            book.id,
            book.title,
            qt: remainingTokens,
          );
          for (final entry in toc) {
            out.add(DbReferenceResult(
              title: book.title,
              reference: entry['reference'] as String,
              segment: entry['segment'] as int,
              isPdf: isPdf,
              filePath: book.filePath ?? '',
              orderIndex: book.orderIndex,
              tocLevel: entry['level'] as int,
              bookId: book.id,
              bookPath: personalBookPath,
              sourceLineId: entry['dbLineId'] as int? ?? 0,
              isUserBook: true,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[FindRef] Personal books search failed: $e');
    }
    return out;
  }

  Future<List<DbReferenceResult>> _enrichWithPaths(
      List<DbReferenceResult> results) async {
    // Only fetch paths for results that don't already have one set.
    // Personal books have bookPath='ספרים אישיים' pre-set; enriching them via
    // the official DB would overwrite that with a colliding official book's path
    // (user_books.db and seforim.db share no bookId namespace).
    final uniqueIds = results
        .where((r) => r.bookPath.isEmpty)
        .map((r) => r.bookId)
        .where((id) => id > 0)
        .toSet();
    if (uniqueIds.isEmpty) return results;

    final pathFn =
        getCategoryPath ?? ReferenceBooksCache.instance.getCategoryPathForBook;
    final pathMap = <int, String>{};
    await Future.wait(uniqueIds.map((id) async {
      pathMap[id] = await pathFn(id);
    }));

    return results.map((r) {
      if (r.bookPath.isNotEmpty) return r; // already set — don't overwrite
      final path = r.bookId > 0 ? (pathMap[r.bookId] ?? '') : '';
      if (path.isEmpty) return r;
      return DbReferenceResult(
        title: r.title,
        reference: r.reference,
        segment: r.segment,
        isPdf: r.isPdf,
        filePath: r.filePath,
        orderIndex: r.orderIndex,
        isAltToc: r.isAltToc,
        tocLevel: r.tocLevel,
        bookId: r.bookId,
        bookPath: path,
        sourceLineId: r.sourceLineId,
        isUserBook: r.isUserBook,
      );
    }).toList();
  }

  List<String> _getRemainingTokens(
    List<String> queryTokens,
    List<String> titleTokens, {
    int stripLeadingTokensCount = 0,
  }) {
    final remaining = List<String>.from(queryTokens);

    if (stripLeadingTokensCount > 0) {
      final toRemove = stripLeadingTokensCount.clamp(0, remaining.length);
      remaining.removeRange(0, toRemove);
    }

    for (final token in titleTokens) {
      final idx = remaining.indexOf(token);
      if (idx != -1) {
        remaining.removeAt(idx);
      }
    }

    return remaining;
  }

  List<DbReferenceResult> _dedupeRefs(List<DbReferenceResult> results) {
    final seen = <String>{};
    final out = <DbReferenceResult>[];

    for (final r in results) {
      // Deduplicate by (title, segment, isPdf): two entries that navigate to the
      // same line in the same book are duplicates regardless of reference format
      // (e.g., "בראשית תולדות עליה ב" vs "תולדות עליה ב" from TOC vs AltToc).
      final key = '${r.title}|${r.segment}|${r.isPdf}';
      if (seen.add(key)) {
        out.add(r);
      }
    }

    return out;
  }

  List<DbReferenceResult> _rankResults(
      List<DbReferenceResult> results, List<String> queryTokens) {
    if (results.length < 2) return results;

    final query = queryTokens.join(' ');
    final needsTokenWiseRanking = queryTokens.length >= 2;

    // זיהוי סגנון ציון גמרא: הטוקן האחרון הוא "א" או "ב" + לפחות עוד טוקן.
    // כשמזוהה — ערכים שה-reference שלהם מכיל "דף" יקבלו עדיפות על פני ערכים
    // שאינם מכילים "דף" (כגון משנה), כדי ש-"שבת עא ב" יציג גמרא לפני משנה.
    final isDafCitation = _queryLooksDafCitation(queryTokens);

    // Decorate: כל מפתחות המיון מחושבים פעם אחת לכל תוצאה.
    final decorated = List<_RankKey>.generate(results.length, (i) {
      final r = results[i];
      final normTitle = _normalize(r.title);
      // citationMatch=true  → מתאים לסגנון הציון שהוזן
      // citationMatch=false → אינו מתאים (ירד מתחת לספרים שמתאימים)
      final citationMatch = !isDafCitation || r.reference.contains('דף');
      return _RankKey(
        result: r,
        normTitle: normTitle,
        exactMatch: normTitle == query,
        startsWithMatch: normTitle.startsWith(query),
        titleTokens: needsTokenWiseRanking ? _tokenize(normTitle) : const [],
        citationMatch: citationMatch,
      );
    });

    decorated.sort((a, b) {
      // 1. התאמה מלאה של שם הספר
      if (a.exactMatch != b.exactMatch) return a.exactMatch ? -1 : 1;

      // 2. התאמה של התחלת שם הספר
      if (a.startsWithMatch != b.startsWithMatch) {
        return a.startsWithMatch ? -1 : 1;
      }

      // 3. התאמת מילים בודדות (מילה שנייה ואילך)
      // טוקנים שהם אות בודדת (מספר פרק/פסוק/דף) מדולגים — הם אינם חלק משם הספר.
      if (needsTokenWiseRanking) {
        for (int i = 1; i < queryTokens.length; i++) {
          final queryToken = queryTokens[i];
          if (queryToken.length == 1) {
            continue; // ← skip single-char location tokens
          }
          final aHasMatch = i < a.titleTokens.length &&
              a.titleTokens[i].startsWith(queryToken);
          final bHasMatch = i < b.titleTokens.length &&
              b.titleTokens[i].startsWith(queryToken);
          if (aHasMatch != bHasMatch) return aHasMatch ? -1 : 1;
        }
      }

      // 4. התאמה לסגנון הציון (גמרא/משנה/תנ"ך)
      if (a.citationMatch != b.citationMatch) return a.citationMatch ? -1 : 1;

      // 5. סדר ספר בספרייה — ספרי יסוד ודורות קדומים עולים ראשונים
      final orderCmp = a.result.orderIndex.compareTo(b.result.orderIndex);
      if (orderCmp != 0) return orderCmp;

      // 6. סדר: TOC L1 < TOC L2 < AltToc < TOC L3+
      // AltToc (כותרות-משנה) מופיע אחרי הכותרות הבסיסיות (רמה 2) אך לפני הכותרות הפנימיות (רמה 3+).
      final aRank = a.result.isAltToc
          ? 3
          : (a.result.tocLevel <= 2
              ? a.result.tocLevel
              : a.result.tocLevel + 1);
      final bRank = b.result.isAltToc
          ? 3
          : (b.result.tocLevel <= 2
              ? b.result.tocLevel
              : b.result.tocLevel + 1);
      if (aRank != bRank) return aRank.compareTo(bRank);

      // 7. ציון קצר יותר עולה קודם (כשאותו ספר מחזיר מספר רמות)
      return a.result.reference.length.compareTo(b.result.reference.length);
    });

    return decorated.map((d) => d.result).toList();
  }

  /// מחזיר true כשהשאילתה נראית כציון בסגנון גמרא (דף + עמוד).
  ///
  /// תנאי הזיהוי (כולם נדרשים):
  ///   1. הטוקן האחרון הוא "א" או "ב" (עמוד א/ב).
  ///   2. לפחות עוד טוקן קיים לפניו.
  ///   3. OR:  מופיע "דף" / "עמוד" במפורש בשאילתה
  ///      OR:  הטוקן לפני האחרון הוא מספר עברי של 2–4 אותיות (כמו "עא", "לט", "קה", "קמד"),
  ///           ואינו מילת מבנה ("פרק", "משנה", "פסוק", ...).
  ///           טוקן של אות בודדת או שם ספר ארוך אינם מפעילים את הבוסט.
  ///
  /// דוגמות שמפעילות: ["שבת","עא","ב"], ["ברכות","דף","כ","א"], ["נדה","ל","ב"]
  /// דוגמות שלא מפעילות: ["בראשית","א","ב"], ["ברכות","ב"], ["ברכות","פרק","א","ב"]
  bool _queryLooksDafCitation(List<String> tokens) {
    if (tokens.length < 2) return false;
    final last = tokens.last;
    if (last != 'א' && last != 'ב') {
      return false;
    }
    // מפורש — מילת "דף" או "עמוד" בשאילתה
    if (tokens.contains('דף') || tokens.contains('עמוד')) return true;
    // מספר דף עברי: 2–4 אותיות עבריות, ואינו מילת מבנה
    const structureWords = {
      'פרק',
      'משנה',
      'פסוק',
      'הלכה',
      'סעיף',
      'סימן',
      'חלק',
      'שאלה'
    };
    final penultimate = tokens[tokens.length - 2];
    if (structureWords.contains(penultimate)) return false;
    return penultimate.length >= 2 &&
        penultimate.length <= 4 &&
        penultimate.codeUnits
            .every((c) => c >= 0x05D0 && c <= 0x05EA); // אותיות עבריות בלבד
  }

  String _normalize(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _normalizeForMatch(String input) => normalizeForFindRefMatch(input);

  List<String> _tokenize(String text) => text
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

/// מפתחות מיון מחושבים מראש לדירוג תוצאות (decorate-sort-undecorate).
/// מאפשר ל-comparator להישאר זול — בלי נורמליזציה/טוקניזציה חוזרת.
class _RankKey {
  final DbReferenceResult result;
  final String normTitle;
  final bool exactMatch;
  final bool startsWithMatch;
  final List<String> titleTokens;

  /// true = ה-reference מתאים לסגנון הציון שהוזן (למשל: מכיל "דף" כשמדובר
  /// בציון גמרא). false = אינו מתאים וירד בדירוג.
  final bool citationMatch;

  const _RankKey({
    required this.result,
    required this.normTitle,
    required this.exactMatch,
    required this.startsWithMatch,
    required this.titleTokens,
    required this.citationMatch,
  });
}
