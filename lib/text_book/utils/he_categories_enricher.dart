import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/book_database_resolver.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/models/books.dart';

/// מעשיר מידע קטגוריה לספר ברקע משלוש מקורות: DB, metadata, ונתיב.
/// מחזיר את ה-id שנמצא ב-DB אם הספר נמצא שם (ללא קשר אם heCategories הועשר).
Future<int?> enrichHeCategories(TextBook book) async {
  if (book.heCategories != null && book.heCategories!.isNotEmpty) {
    // heCategories קיים — אבל ייתכן שה-id עדיין חסר, נחפש ב-DB
    return _tryGetIdFromDatabase(book);
  }

  try {
    final id = await _tryLoadFromDatabase(book);
    if (id != null) return id;
    if (await _tryLoadFromMetadata(book)) return null;
    await _tryLoadFromPath(book);
  } catch (e) {
    debugPrint('⚠️ Failed to enrich heCategories in background: $e');
  }
  return null;
}

Future<int?> _tryLoadFromDatabase(TextBook book) async {
  final sqliteProvider = SqliteDataProvider.instance;
  if (!await sqliteProvider.databaseExists() && !book.isUserBook) {
    return null;
  }

  final resolvedBook = await BookDatabaseResolver.resolveBook(
    title: book.title,
    categoryId: book.categoryId,
    fileType: book.fileType,
    filePath: book.filePath,
    preferUserBooks: BookDatabaseResolver.isLikelyUserBook(
      isUserBook: book.isUserBook,
      categoryPath: book.categoryPath,
    ),
  );
  if (resolvedBook == null) return null;

  book.heCategories = await BookDatabaseResolver.buildCategoryPath(
    resolvedBook.repository,
    resolvedBook.book.categoryId,
  );
  debugPrint('📚 Background: נטען heCategories מה-DB: "${book.heCategories}"');
  return resolvedBook.book.id;
}

/// מחפש רק את ה-id ב-DB מבלי לשנות heCategories (כשהוא כבר קיים).
Future<int?> _tryGetIdFromDatabase(TextBook book) async {
  if (book.id != null) return null; // כבר יש id
  final sqliteProvider = SqliteDataProvider.instance;
  if (!await sqliteProvider.databaseExists() && !book.isUserBook) {
    return null;
  }
  try {
    final resolvedBook = await BookDatabaseResolver.resolveBook(
      title: book.title,
      categoryId: book.categoryId,
      fileType: book.fileType,
      filePath: book.filePath,
      preferUserBooks: BookDatabaseResolver.isLikelyUserBook(
        isUserBook: book.isUserBook,
        categoryPath: book.categoryPath,
      ),
    );
    return resolvedBook?.book.id;
  } catch (e) {
    debugPrint('⚠️ Failed to get book id from DB: $e');
    return null;
  }
}

Future<bool> _tryLoadFromMetadata(TextBook book) async {
  final metadata = await FileSystemData.instance.metadata;
  final bookMetadata = metadata[book.title];
  if (bookMetadata == null) return false;

  book.heCategories = bookMetadata['heCategories'];
  book.author ??= bookMetadata['author'];
  book.heEra ??= bookMetadata['heEra'];

  if (book.heCategories != null && book.heCategories!.isNotEmpty) {
    debugPrint(
        '📚 Background: נטען heCategories מ-metadata: "${book.heCategories}"');
    return true;
  }
  return false;
}

Future<void> _tryLoadFromPath(TextBook book) async {
  final titleToPath = await FileSystemData.instance.titleToPath;
  final bookPath = titleToPath[book.title];
  if (bookPath == null) return;

  if (bookPath.contains(Platform.pathSeparator)) {
    final pathParts = bookPath.split(Platform.pathSeparator);
    final otzariaIndex = pathParts.indexOf('אוצריא');
    if (otzariaIndex >= 0 && otzariaIndex < pathParts.length - 2) {
      final categories =
          pathParts.sublist(otzariaIndex + 1, pathParts.length - 1);
      book.heCategories = categories.join(', ');
      debugPrint(
          '📚 Background: נטען heCategories מהנתיב: "${book.heCategories}"');
    }
  } else {
    final normalized = bookPath
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(', ');
    if (normalized.isNotEmpty) {
      book.heCategories = normalized;
      debugPrint(
          '📚 Background: נטען heCategories מנתיב קטגוריה: "${book.heCategories}"');
    }
  }
}
