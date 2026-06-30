import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/user_content_import/models/user_import_models.dart';
import 'package:otzaria/user_content_import/repository/user_content_repository.dart';
import 'package:otzaria/user_content_import/services/user_import_parser.dart';

/// תוצאת ייבוא נתוני-משתמש מתיקייה: ספירות + שגיאות מרוכזות (עם הקשר קובץ).
class UserImportResult {
  final int generationsApplied;
  final int linksApplied;
  final int booksWithLinks;
  final List<String> errors;

  const UserImportResult({
    this.generationsApplied = 0,
    this.linksApplied = 0,
    this.booksWithLinks = 0,
    this.errors = const [],
  });

  bool get hasAny =>
      generationsApplied > 0 || linksApplied > 0 || errors.isNotEmpty;
}

/// קולט קבצי CSV שהמשתמש הכין מראש בתיקייה מותאמת, וכותב את הדורות
/// והקישורים ל-user_books.db. רץ בכל סריקה (idempotent) כדי לקלוט גם
/// מצב שבו רק ה-CSV נערך (קובץ הספר לא השתנה).
///
/// שמות קבצים שמזוהים (בכל עומק בעץ התיקייה):
/// - `דורות.csv` / `generations.csv` — דורות (עמודות: ספר, דור).
/// - `קישורים.csv|json` / `links.csv|json` — קישורים רוחביים (עם ספר_מקור).
/// - `<שם הספר>.links.csv` / `<שם הספר>.links.json` — קישורים לספר בודד.
///
/// קובץ קישורים ב-JSON הוא מערך אובייקטים באותה סמנטיקה כמו ה-CSV
/// (ראה [UserImportParser.parseLinksJson]).
class UserContentImporter {
  static const _generationFileNames = {'דורות.csv', 'generations.csv'};
  static const _folderLinkFileNames = {
    'קישורים.csv',
    'links.csv',
    'קישורים.json',
    'links.json',
  };

  /// ייבוא תיקייה בודדת (עוטף את [importFolders]).
  static Future<UserImportResult> importFolder(
    String folderPath,
    MyDatabase userDb,
  ) =>
      importFolders([folderPath], userDb);

  /// ייבוא של כמה תיקיות כפעולה אחת קוהרנטית: אוסף את כל קבצי הייבוא
  /// (CSV/JSON), מנקה את נתוני-הייבוא הקיימים, ואז מיישם — כך מחיקת שורה/קובץ
  /// משתקפת ב-DB (idempotent מלא). אם לא נמצא אף קובץ ייבוא — לא נוגעים בקיים.
  static Future<UserImportResult> importFolders(
    Iterable<String> folderPaths,
    MyDatabase userDb,
  ) async {
    final repo = UserContentRepository(userDb);
    final errors = <String>[];

    // bookId → שם דור (אחרון מנצח); bookId → רשימת קישורים מצטברת.
    final generationByBook = <int, String>{};
    final linksByBook = <int, List<UserLinkRecord>>{};
    var anyImportFile = false;

    for (final folderPath in folderPaths) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;
      final files = await dir
          .list(recursive: true, followLinks: false)
          .where((e) =>
              e is File &&
              (e.path.toLowerCase().endsWith('.csv') ||
                  e.path.toLowerCase().endsWith('.json')))
          .cast<File>()
          .toList();
      if (files.isEmpty) continue;
      for (final file in files) {
        final name = _baseName(file.path);
        final lower = name.toLowerCase();
        // anyImportFile מסומן רק לקובץ *מוכר* — קובץ CSV/JSON לא-קשור בתיקייה
        // לא ייחשב מקור-אמת ולא יגרור ניקוי.
        if (_generationFileNames.contains(name)) {
          anyImportFile = true;
          await _ingestGenerations(file, repo, generationByBook, errors);
        } else if (_folderLinkFileNames.contains(name)) {
          anyImportFile = true;
          await _ingestLinks(file, repo, linksByBook, errors,
              bookTitleFromFile: null);
        } else if (lower.endsWith('.links.csv')) {
          anyImportFile = true;
          final bookTitle =
              name.substring(0, name.length - '.links.csv'.length);
          await _ingestLinks(file, repo, linksByBook, errors,
              bookTitleFromFile: bookTitle);
        } else if (lower.endsWith('.links.json')) {
          anyImportFile = true;
          final bookTitle =
              name.substring(0, name.length - '.links.json'.length);
          await _ingestLinks(file, repo, linksByBook, errors,
              bookTitleFromFile: bookTitle);
        }
      }
    }

    // החלטת-מוצר מכוונת: כשאין אף קובץ ייבוא (CSV/JSON; אולי תיקייה לא-זמינה
    // זמנית/באג) לא מוחקים נתונים שכבר יובאו — בטיחות מעל מקור-אמת. מחיקת
    // *שורה* או *קובץ* בודד כן משתקפת (clear+apply למטה), רק מחיקת הכל אינה מנקה.
    if (!anyImportFile) return const UserImportResult();

    // ייבוא אטומי: כל שגיאה (פענוח או ספר-לא-נמצא) חוסמת כתיבה כלשהי — לא
    // מוחקים ולא כותבים חלקית (replaceUserLinksForBook הוא הרסני פר-ספר). כך
    // טעות לא תאבד נתונים קיימים; המשתמש מתקן ומייבא שוב.
    if (errors.isNotEmpty) {
      return UserImportResult(errors: errors);
    }

    await repo.clearAllUserContent();
    for (final entry in generationByBook.entries) {
      await repo.setBookGeneration(entry.key, entry.value);
    }
    var linksApplied = 0;
    for (final entry in linksByBook.entries) {
      await repo.replaceUserLinksForBook(entry.key, entry.value);
      linksApplied += entry.value.length;
    }

    return UserImportResult(
      generationsApplied: generationByBook.length,
      linksApplied: linksApplied,
      booksWithLinks: linksByBook.length,
      errors: errors,
    );
  }

  static Future<void> _ingestGenerations(
    File file,
    UserContentRepository repo,
    Map<int, String> out,
    List<String> errors,
  ) async {
    final fileName = _baseName(file.path);
    final ParseResult<ParsedBookGeneration> parsed;
    try {
      parsed = UserImportParser.parseGenerations(await file.readAsString());
    } catch (e) {
      errors.add('$fileName: קריאת הקובץ נכשלה ($e)');
      return;
    }
    for (final err in parsed.errors) {
      errors.add('$fileName ${err.message} (שורה ${err.lineNumber})');
    }
    for (final row in parsed.rows) {
      final bookId =
          await repo.bookIdByTitle(row.bookTitle, categoryId: row.categoryId);
      if (bookId == null) {
        errors.add('$fileName: הספר "${row.bookTitle}" לא נמצא בספרייה האישית');
        continue;
      }
      out[bookId] = row.eraName;
    }
  }

  static Future<void> _ingestLinks(
    File file,
    UserContentRepository repo,
    Map<int, List<UserLinkRecord>> out,
    List<String> errors, {
    required String? bookTitleFromFile,
  }) async {
    final fileName = _baseName(file.path);
    final ParseResult<ParsedUserLink> parsed;
    try {
      final content = await file.readAsString();
      parsed = fileName.toLowerCase().endsWith('.json')
          ? UserImportParser.parseLinksJson(content)
          : UserImportParser.parseLinks(content);
    } catch (e) {
      errors.add('$fileName: קריאת הקובץ נכשלה ($e)');
      return;
    }
    for (final err in parsed.errors) {
      errors.add('$fileName ${err.message} (שורה ${err.lineNumber})');
    }
    for (final row in parsed.rows) {
      final sourceTitle = bookTitleFromFile ?? row.sourceBookTitle;
      if (sourceTitle == null || sourceTitle.isEmpty) {
        errors.add('$fileName: חסר ספר מקור (עמודת "ספר_מקור")');
        continue;
      }
      final sourceId = await repo.bookIdByTitle(sourceTitle);
      if (sourceId == null) {
        errors.add('$fileName: ספר המקור "$sourceTitle" לא נמצא');
        continue;
      }
      out.putIfAbsent(sourceId, () => []).add(_toRecord(sourceId, row));
    }
  }

  /// ממיר שורה שפוענחה לרשומת DB. "מיקום_יעד" מספרי → אינדקס שורה (0-based);
  /// אחרת נשמר כ-ref גולמי ל-resolution בזמן קריאה.
  static UserLinkRecord _toRecord(int sourceBookId, ParsedUserLink row) {
    final refRaw = row.targetRef;
    final refAsLine = refRaw == null ? null : int.tryParse(refRaw.trim());
    return UserLinkRecord(
      sourceBookId: sourceBookId,
      sourceLineIndex: row.sourceLineNumber - 1,
      targetTitle: row.targetTitle,
      targetCategoryId: row.targetCategoryId,
      targetIsUserBook: row.targetIsUserBook,
      targetRef: refAsLine == null ? refRaw : null,
      targetLineIndex: refAsLine == null ? null : refAsLine - 1,
      connectionType: row.connectionType,
    );
  }

  static String _baseName(String path) =>
      path.replaceAll('\\', '/').split('/').last;
}

/// עטיפה בטוחה לכל התיקיות בפעולה אחת — לעולם לא זורקת, רק מדווחת.
/// פעולה אחת לכל התיקיות (ולא לולאה) כי [UserContentImporter.importFolders]
/// מנקה את נתוני-הייבוא לפני היישום.
Future<UserImportResult> importUserContentSafe(
  Iterable<String> folderPaths,
  MyDatabase userDb,
) async {
  try {
    return await UserContentImporter.importFolders(folderPaths, userDb);
  } catch (e) {
    debugPrint('⚠️ [UserContentImport] failed: $e');
    return UserImportResult(errors: ['ייבוא נתוני-המשתמש נכשל: $e']);
  }
}
