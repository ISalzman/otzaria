import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/db_reference_result.dart';
import 'package:otzaria/migration/dao/repository/seforim_repository.dart';
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:otzaria/find_ref/reference_books_cache.dart';

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

  FindRefRepository({
    required this.dataRepository,
    this.warmUpReferenceBooksCache,
    this.isReferenceBooksCacheLoaded,
    this.searchReferenceBooks,
    this.getTocEntriesForReference,
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

    // Get repository from SqliteDataProvider.
    // In tests we may inject [getTocEntriesForReference] to avoid requiring
    // a real SQLite DB.
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

    // Search for books by title or acronym from in-memory cache.
    // This avoids hitting SQLite on every keystroke.
    final cacheLoaded = isReferenceBooksCacheLoaded?.call() ??
        ReferenceBooksCache.instance.isLoaded;
    if (!cacheLoaded) {
      await (warmUpReferenceBooksCache?.call() ??
          ReferenceBooksCache.instance.warmUp());
    }

    final bookHits =
        (searchReferenceBooks ?? ReferenceBooksCache.instance.search)(
      queryTokens.first,
      limit: 50,
    );

    debugPrint(
        '[FindRef] Found ${bookHits.length} books matching first word (memory)');

    final results = <DbReferenceResult>[];

    // Step 2 requirement: for a single-word query, do NOT search TOC at all.
    // Only return book-name matches (book + book_acronym via in-memory cache).
    if (queryTokens.length == 1) {
      for (final hit in bookHits) {
        final fileType = hit.fileType;
        final isPdf = fileType == 'pdf';

        results.add(DbReferenceResult(
          title: hit.title,
          reference: hit.title,
          segment: 0,
          isPdf: isPdf,
          filePath: hit.filePath,
        ));
      }

      final unique = _dedupeRefs(results);
      final ranked = _rankResults(unique, queryTokens);
      return ranked.length > 15 ? ranked.take(15).toList() : ranked;
    }

    // Step 3: For multi-word queries, check if remaining words match book names
    // If the second word has an exact match in book names, don't search TOC
    // Example: "בראשית א" - if "א" doesn't match any book exactly, search TOC
    // But "בראשית רבא" - "רבא" matches a book, so don't search TOC for "בראשית"

    final secondWordMatches =
        (searchReferenceBooks ?? ReferenceBooksCache.instance.search)(
      queryTokens.length > 1 ? queryTokens[1] : '',
      limit: 50,
    );

    // Check if second word has exact match (rank 0 = exact match)
    final hasExactSecondWordMatch =
        secondWordMatches.any((hit) => hit.matchRank == 0);

    debugPrint(
        '[FindRef] Second word "${queryTokens.length > 1 ? queryTokens[1] : ''}" has exact match: $hasExactSecondWordMatch');

    for (final hit in bookHits) {
      final bookId = hit.bookId;
      final title = hit.title;
      final filePath = hit.filePath;
      final fileType = hit.fileType;
      final isPdf = fileType == 'pdf';

      // Get remaining tokens after matching book title
      final titleTokens = _tokenize(_normalizeForMatch(title));
      // If the book was matched by acronym, the first query token is NOT part
      // of the title or TOC reference path (e.g., "משנב ב" should search TOC
      // for ["ב"], not ["משנב", "ב"]).
      final matchedByAcronym = hit.matchRank >= 3;
      final remainingTokens = _getRemainingTokens(
        queryTokens,
        titleTokens,
        stripFirstQueryToken: matchedByAcronym,
      );

      if (remainingTokens.isEmpty) {
        // Query is just the book name - return book root and top-level TOC entries
        final tocEntries = await fetchTocEntries(bookId, title);

        // Add book root
        results.add(DbReferenceResult(
          title: title,
          reference: title,
          segment: 0,
          isPdf: isPdf,
          filePath: filePath,
        ));

        // Add top-level TOC entries (level 2 only - skip level 1)
        // Step 4: Level 1 always contains book name, causing duplicates like "בראשית בראשית"
        for (final entry in tocEntries) {
          final level = entry['level'] as int;
          if (level == 2 && entry['reference'] != title) {
            results.add(DbReferenceResult(
              title: title,
              reference: entry['reference'] as String,
              segment: entry['segment'] as int,
              isPdf: isPdf,
              filePath: filePath,
            ));
          }
        }
      } else if (!hasExactSecondWordMatch) {
        // Step 3: Only search TOC if second word doesn't have exact book match
        // This prevents "בראשית א" from matching "בראשית רבא"
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
            filePath: filePath,
          ));
        }
      }
      // else: second word has exact book match, skip TOC search for this book
    }

    // Deduplicate and rank results
    final unique = _dedupeRefs(results);
    final ranked = _rankResults(unique, queryTokens);

    debugPrint('[FindRef] Final results: ${ranked.length}');

    return ranked.length > 15 ? ranked.take(15).toList() : ranked;
  }

  /// Gets tokens that remain after matching book title tokens
  List<String> _getRemainingTokens(
      List<String> queryTokens, List<String> titleTokens,
      {bool stripFirstQueryToken = false}) {
    final remaining = List<String>.from(queryTokens);

    if (stripFirstQueryToken && remaining.isNotEmpty) {
      remaining.removeAt(0);
    }

    for (final token in titleTokens) {
      final idx = remaining.indexOf(token);
      if (idx != -1) {
        remaining.removeAt(idx);
      }
    }

    return remaining;
  }

  /// Deduplicates results based on reference text
  List<DbReferenceResult> _dedupeRefs(List<DbReferenceResult> results) {
    final seen = <String>{};
    final out = <DbReferenceResult>[];

    for (final r in results) {
      final key = '${_normalize(r.reference)}|${r.title}|${r.segment}';
      if (seen.add(key)) {
        out.add(r);
      }
    }

    return out;
  }

  /// Ranks results by relevance
  List<DbReferenceResult> _rankResults(
      List<DbReferenceResult> results, List<String> queryTokens) {
    // Sort by:
    // 1. Exact title match first
    // 2. Title starts with query
    // 3. Reference length (shorter = more specific)
    results.sort((a, b) {
      final aTitle = _normalize(a.title);
      final bTitle = _normalize(b.title);
      final query = queryTokens.join(' ');

      // Exact title match
      if (aTitle == query && bTitle != query) return -1;
      if (bTitle == query && aTitle != query) return 1;

      // Title starts with query
      if (aTitle.startsWith(query) && !bTitle.startsWith(query)) return -1;
      if (bTitle.startsWith(query) && !aTitle.startsWith(query)) return 1;

      // Shorter reference = more specific
      return a.reference.length.compareTo(b.reference.length);
    });

    return results;
  }

  String _normalize(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _normalizeForMatch(String input) {
    var cleaned = removeTeamim(removeVolwels(input));

    // Remove quotes/gershayim completely (don't convert to space)
    // This way מ"ב becomes מב (not מ ב)
    cleaned = cleaned.replaceAll('"', '').replaceAll("'", '');
    cleaned = cleaned.replaceAll('\u05F4', '').replaceAll('\u05F3', '');

    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\u0590-\u05FF\s]'), ' ');
    cleaned = cleaned.toLowerCase();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _tokenize(String text) => text
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}
