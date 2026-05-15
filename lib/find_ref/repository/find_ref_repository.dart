import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

class FindRefRepository {
  final DataRepository dataRepository;

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

  /// Injection for testing: returns all books that have AltToc structures.
  /// In production this calls [SeforimRepository.getAllBooksWithAltToc].
  final Future<List<({int bookId, String bookTitle})>> Function()?
      getAllBooksWithAltToc;

  /// Injection for testing: returns the category path string for a given bookId.
  /// In production this calls [ReferenceBooksCache.instance.getCategoryPathForBook].
  final Future<String> Function(int bookId)? getCategoryPath;

  /// Injection for testing: returns outline entries for a FS PDF file.
  /// In production this calls [ReferenceBooksCache.instance.getPdfOutlineEntries].
  final Future<List<(String, String, int)>> Function(String filePath)?
      getPdfOutlineEntries;

  FindRefRepository({
    required this.dataRepository,
    this.warmUpReferenceBooksCache,
    this.isReferenceBooksCacheLoaded,
    this.searchReferenceBooks,
    this.getTocEntriesForReference,
    this.getAltTocEntriesForReference,
    this.getAllBooksWithAltToc,
    this.getCategoryPath,
    this.getPdfOutlineEntries,
  });

  Future<List<DbReferenceResult>> findRefs(String ref) async {
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
        if (hit.matchRank == 2) return false; // contains-only – never accept for n>1
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
          ));
        }
      }
    }

    // Global AltToc fallback: when no AltToc results were found in the per-book
    // loop, search AltToc across all books. This handles queries like "נח עליה ב"
    // where the user doesn't type the book name, even if some other book matched
    // the first token (e.g., "תולדות יצחק" matching "תולדות").
    if (!results.any((r) => r.isAltToc) && queryTokens.length >= 2) {
      final fetchAllBooks = getAllBooksWithAltToc;
      final altTocBooks = fetchAllBooks != null
          ? await fetchAllBooks()
          : (await repository?.getAllBooksWithAltToc() ?? const []);

      for (final (:bookId, :bookTitle) in altTocBooks) {
        final bookHit = searchBooks(bookTitle, limit: 1).firstOrNull;
        final orderIdx = bookHit?.orderIndex ?? 0.0;
        final altTocEntries = await fetchAltTocEntries(
          bookId,
          bookTitle,
          queryTokens: queryTokens,
        );
        for (final entry in altTocEntries) {
          final ref = entry['reference'] as String;
          // Require that ALL query tokens appear in the matched reference.
          // Prevents partial matches from unrelated books (e.g., "הפטרת נח"
          // matching only "נח" when the query is "נח עליה ב").
          final refTokens = _tokenize(_normalizeForMatch(ref));
          if (!queryTokens.every((qt) => refTokens.contains(qt))) continue;

          results.add(DbReferenceResult(
            title: bookTitle,
            reference: ref,
            segment: entry['segment'] as int,
            orderIndex: orderIdx,
            tocLevel: entry['level'] as int,
            isAltToc: true,
            bookId: bookId,
          ));
        }
      }
    }

    final unique = _dedupeRefs(results);
    final ranked = _rankResults(unique, queryTokens);
    final limited = ranked.length > 15 ? ranked.take(15).toList() : ranked;

    debugPrint('[FindRef] Final results: ${limited.length}');

    return await _enrichWithPaths(limited);
  }

  Future<List<DbReferenceResult>> _enrichWithPaths(
      List<DbReferenceResult> results) async {
    // Collect unique bookIds (DB books only) and fetch paths in parallel.
    final uniqueIds =
        results.map((r) => r.bookId).where((id) => id > 0).toSet();
    if (uniqueIds.isEmpty) return results;

    final pathFn =
        getCategoryPath ?? ReferenceBooksCache.instance.getCategoryPathForBook;
    final pathMap = <int, String>{};
    await Future.wait(uniqueIds.map((id) async {
      pathMap[id] = await pathFn(id);
    }));

    return results.map((r) {
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
          if (queryToken.length == 1) continue; // ← skip single-char location tokens
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
      final orderCmp =
          a.result.orderIndex.compareTo(b.result.orderIndex);
      if (orderCmp != 0) return orderCmp;

      // 6. סדר: TOC L1 < TOC L2 < AltToc < TOC L3+
      // AltToc (כותרות-משנה) מופיע אחרי הכותרות הבסיסיות (רמה 2) אך לפני הכותרות הפנימיות (רמה 3+).
      final aRank = a.result.isAltToc
          ? 3
          : (a.result.tocLevel <= 2 ? a.result.tocLevel : a.result.tocLevel + 1);
      final bRank = b.result.isAltToc
          ? 3
          : (b.result.tocLevel <= 2 ? b.result.tocLevel : b.result.tocLevel + 1);
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
      'פרק', 'משנה', 'פסוק', 'הלכה', 'סעיף', 'סימן', 'חלק', 'שאלה'
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
