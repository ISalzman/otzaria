import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
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
  return DatabaseLibraryProvider.instance.hasSelectableBookVersions(
    book.title,
    categoryId,
  );
}

/// מחליף את שאילתת המהדורות בבדיקות widget שאין להן seforim.db.
@visibleForTesting
Future<bool> Function(TextBook book)? bookVersionsProbeForTesting;
