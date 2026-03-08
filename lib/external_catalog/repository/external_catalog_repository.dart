import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/models/books.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:zstandard/zstandard.dart';

/// מנהל את מסד הקטלוגים החיצוניים (אוצר החכמה והיברובוקס).
class ExternalCatalogRepository {
  static const String releaseApiUrl =
      'https://api.github.com/repos/Otzaria/otzar-HB_catalog/releases/latest';

  static final ExternalCatalogRepository instance = ExternalCatalogRepository();

  final http.Client _httpClient;
  final Zstandard _zstandard;

  ExternalCatalogRepository({
    http.Client? httpClient,
    Zstandard? zstandard,
  })  : _httpClient = httpClient ?? http.Client(),
        _zstandard = zstandard ?? Zstandard();

  /// מחזיר את נתיב קובץ ה-DB של הקטלוגים.
  String get databasePath => DatabaseConstants.getExternalCatalogDatabasePath();

  /// בודק האם מסד הקטלוגים קיים ליד `seforim.db`.
  Future<bool> databaseExists() async {
    return File(databasePath).exists();
  }

  /// מחזיר את ספרי אוצר החכמה מתוך מסד הקטלוגים החיצוני.
  Future<List<ExternalLibraryBook>> getOtzarBooks() async {
    return _loadBooks(
      tableName: 'otzar_hahochma',
      mapper: _mapOtzarBook,
    );
  }

  /// מחזיר את ספרי היברובוקס מתוך מסד הקטלוגים החיצוני.
  Future<List<Book>> getHebrewBooks() async {
    return _loadBooks(
      tableName: 'hebrew_books',
      mapper: _mapHebrewBook,
    );
  }

  /// מוריד את מסד הקטלוגים מהרליס האחרון ומחלץ אותו ליד `seforim.db`.
  Future<void> downloadLatestDatabase() async {
    final asset = await _fetchLatestDatabaseAsset();
    final dbDir = Directory(path.dirname(databasePath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final downloadedBytes = await _downloadAssetBytes(asset.downloadUrl);
    final dbBytes = asset.isCompressed
        ? await _zstandard.decompress(downloadedBytes)
        : downloadedBytes;
    if (dbBytes == null) {
      throw Exception('חילוץ DB הקטלוגים נכשל');
    }

    final dbFile = File(databasePath);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await dbFile.writeAsBytes(dbBytes, flush: true);
  }

  Future<List<T>> _loadBooks<T extends Book>({
    required String tableName,
    required T Function(Map<String, Object?> row) mapper,
  }) async {
    if (!await databaseExists()) {
      return <T>[];
    }

    sqflite.Database? db;
    try {
      db = await sqflite.openDatabase(
        databasePath,
        readOnly: true,
        singleInstance: false,
      );

      final rows = await db.rawQuery(
        'SELECT * FROM $tableName ORDER BY title COLLATE NOCASE',
      );

      return rows.map((row) => mapper(row)).toList(growable: false);
    } catch (e) {
      debugPrint('Error loading external catalog table $tableName: $e');
      return <T>[];
    } finally {
      await db?.close();
    }
  }

  Future<ExternalCatalogReleaseAsset> _fetchLatestDatabaseAsset() async {
    final response = await _httpClient.get(
      Uri.parse(releaseApiUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'שגיאה בקבלת רליס הקטלוגים האחרון: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('מבנה תשובת GitHub של קטלוג הספרים אינו תקין');
    }

    final asset = parseLatestDatabaseAsset(decoded);
    if (asset == null) {
      throw Exception('לא נמצא קובץ DB של הקטלוגים ברליס האחרון');
    }

    return asset;
  }

  Future<Uint8List> _downloadAssetBytes(String downloadUrl) async {
    final response = await _httpClient.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('שגיאה בהורדת DB הקטלוגים: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  @visibleForTesting
  static ExternalCatalogReleaseAsset? parseLatestDatabaseAsset(
    Map<String, dynamic> releaseJson,
  ) {
    final assets = releaseJson['assets'];
    if (assets is! List) {
      return null;
    }

    ExternalCatalogReleaseAsset? fallbackDb;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }

      final name = asset['name']?.toString() ?? '';
      final downloadUrl = asset['browser_download_url']?.toString() ?? '';
      if (downloadUrl.isEmpty) {
        continue;
      }

      if (name == DatabaseConstants.externalCatalogArchiveFileName) {
        return ExternalCatalogReleaseAsset(
          fileName: name,
          downloadUrl: downloadUrl,
          isCompressed: true,
        );
      }

      if (name == DatabaseConstants.externalCatalogDatabaseFileName) {
        fallbackDb = ExternalCatalogReleaseAsset(
          fileName: name,
          downloadUrl: downloadUrl,
          isCompressed: false,
        );
      }
    }

    return fallbackDb;
  }

  ExternalLibraryBook _mapOtzarBook(Map<String, Object?> row) {
    final bookId = (row['book_id'] as num).toInt();
    final authors = _decodeStringList(row['authors']);
    final subjects = _decodeStringList(row['subjects']);
    final fromYear = row['from_year']?.toString().trim();
    final toYear = row['to_year']?.toString().trim();
    final years = _buildYearRange(fromYear, toYear);
    final places = _normalizeNullableString(row['places']);

    return ExternalLibraryBook(
      title: row['title']?.toString() ?? '',
      id: bookId,
      author: authors.isEmpty ? null : authors.join(', '),
      pubPlace: places,
      pubDate: years,
      topics: subjects.join(', '),
      link: 'https://tablet.otzar.org/book/book.php?book=$bookId',
      externalLibraryId: 'oh:$bookId',
    );
  }

  ExternalLibraryBook _mapHebrewBook(Map<String, Object?> row) {
    final bookId = (row['id_book'] as num).toInt();
    final tags = _decodeStringList(row['tags']);
    final author = _normalizeNullableString(row['author']);
    final printingPlace = _normalizeNullableString(row['printing_place']);
    final printingYear = _normalizeNullableString(row['printing_year']);
    final pubDateYear = row['pub_date']?.toString();

    return ExternalLibraryBook(
      title: row['title']?.toString() ?? '',
      id: bookId,
      author: author,
      pubPlace: printingPlace,
      pubDate: printingYear ?? pubDateYear,
      topics: tags.join(', '),
      link: 'https://hebrewbooks.org/$bookId',
      externalLibraryId: 'hb:$bookId',
    );
  }

  static List<String> _decodeStringList(Object? rawValue) {
    if (rawValue == null) {
      return const <String>[];
    }

    final value = rawValue.toString().trim();
    if (value.isEmpty) {
      return const <String>[];
    }

    if (value.startsWith('[') && value.endsWith(']')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        // Fall back to plain-text splitting below.
      }
    }

    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _buildYearRange(String? fromYear, String? toYear) {
    if (fromYear == null || fromYear.isEmpty) {
      return toYear == null || toYear.isEmpty ? null : toYear;
    }
    if (toYear == null || toYear.isEmpty || toYear == fromYear) {
      return fromYear;
    }
    return '$fromYear-$toYear';
  }

  static String? _normalizeNullableString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class ExternalCatalogReleaseAsset {
  const ExternalCatalogReleaseAsset({
    required this.fileName,
    required this.downloadUrl,
    required this.isCompressed,
  });

  final String fileName;
  final String downloadUrl;
  final bool isCompressed;
}
