import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/models/book_version.dart';
import 'package:otzaria/models/books.dart';

/// האם להציע לספר [book] את הפעולה "הצג נוסחאות נוספות".
///
/// מהדורות (book_version) קיימות רק לספרי הספרייה הרשמית, ורק כשיש מהדורה
/// לבחירה בפועל — ראו [DatabaseLibraryProvider.hasSelectableBookVersions].
Future<bool> hasBookVersionsToOpen(TextBook book) async {
  final probe = bookVersionsProbeForTesting;
  if (probe != null) return probe(book);

  final categoryId = book.categoryId;
  if (book.isUserBook || categoryId == null) return false;
  if (book.versionTitle != null) {
    final probe = availableBookVersionsProbeForTesting;
    final versions =
        await (probe?.call(book) ??
            DatabaseLibraryProvider.instance.getBookVersions(
              book.title,
              categoryId,
            ));
    return versions.any((version) => version.versionTitle != book.versionTitle);
  }
  return DatabaseLibraryProvider.instance.hasSelectableBookVersions(
    book.title,
    categoryId,
  );
}

/// מחליף את שאילתת המהדורות בבדיקות widget שאין להן seforim.db.
@visibleForTesting
Future<bool> Function(TextBook book)? bookVersionsProbeForTesting;

/// מחליף את טעינת המהדורות כשכבר פתוח נוסח מסוים.
@visibleForTesting
Future<List<BookVersionInfo>> Function(TextBook book)?
availableBookVersionsProbeForTesting;
