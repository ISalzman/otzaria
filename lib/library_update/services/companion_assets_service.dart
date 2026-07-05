import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/external_catalog/repository/external_catalog_repository.dart';
import 'package:otzaria/search/magic_dictionary_downloader.dart';
import 'package:otzaria/utils/file/tar_zst_extractor.dart';
import 'package:path/path.dart' as p;

/// מוודא שהקבצים הנלווים לספרייה — התלמוד הבבלי, קטלוג otzar-HB ומילון
/// החיפוש — קיימים ומעודכנים, כחלק מזרימת עדכון הספרייה.
///
/// כל פריט הוא best-effort: כשל (אין רשת, קובץ נעול) נרשם ללוג ולא מפיל את
/// העדכון. הקטלוג והמילון משתמשים במנגנוני הגרסה הקיימים שלהם; לתלמוד נוסף
/// כאן סימון גרסה (תג ה-release) בקובץ בתוך התיקייה.
class CompanionAssetsService {
  static const String talmudReleaseApi =
      'https://api.github.com/repos/Otzaria/otzaria-library/releases/latest';
  static const String talmudVersionFileName = '.version';

  /// נכתב לקובץ הגרסה לפני החילוץ; חילוץ שנקטע משאיר אותו, וכך ההתקנה
  /// החלקית לא נחתמת כשלמה במסלול "ללא סימון גרסה" אלא מורדת מחדש.
  static const String talmudInstallingMarker = 'installing';
  static const Duration _apiTimeout = Duration(seconds: 15);

  final http.Client Function() _clientFactory;
  final ExternalCatalogRepository Function() _catalogRepository;
  final MagicDictionaryDownloader Function() _dictionaryFactory;
  final Future<void> Function(String archivePath, String outputDir,
      void Function(double progress)? onProgress) _extractTarArchive;
  final List<String> Function() _talmudDirsProvider;
  final VoidCallback _invalidateExternalBooksCache;
  final VoidCallback _invalidateLibraryCaches;
  final String _talmudReleaseApiUrl;

  CompanionAssetsService({
    http.Client Function()? clientFactory,
    ExternalCatalogRepository Function()? catalogRepository,
    MagicDictionaryDownloader Function()? dictionaryFactory,
    Future<void> Function(String, String, void Function(double)?)?
        extractTarArchive,
    List<String> Function()? talmudDirsProvider,
    VoidCallback? invalidateExternalBooksCache,
    VoidCallback? invalidateLibraryCaches,
    String? talmudReleaseApiUrl,
  })  : _clientFactory = clientFactory ?? http.Client.new,
        _catalogRepository =
            catalogRepository ?? (() => ExternalCatalogRepository.instance),
        _dictionaryFactory = dictionaryFactory ?? MagicDictionaryDownloader.new,
        _extractTarArchive = extractTarArchive ??
            ((archive, outputDir, onProgress) =>
                extractTarZstToDir(archive, outputDir, onProgress: onProgress)),
        _talmudDirsProvider = talmudDirsProvider ??
            DatabaseConstants.getTalmudBavliDirectoryPaths,
        _invalidateExternalBooksCache = invalidateExternalBooksCache ??
            (() => DataRepository.instance.invalidateExternalBooksCache()),
        _invalidateLibraryCaches = invalidateLibraryCaches ??
            (() => FileSystemData.instance.clearBookCache()),
        _talmudReleaseApiUrl = talmudReleaseApiUrl ?? talmudReleaseApi;

  /// מריץ אימות ועדכון של שלושת הפריטים הנלווים, לפי הסדר: תלמוד, קטלוג,
  /// מילון. מחזיר האם תוכן הספרייה השתנה (תלמוד/קטלוג הותקנו או עודכנו) —
  /// אז נדרש ריענון ספרייה; עדכון מילון אינו משנה את הספרייה.
  Future<bool> verifyAndUpdate({
    void Function(String message)? onStatus,
    void Function(int received, int? total)? onDownloadProgress,
    bool Function()? isCancelled,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    var libraryChanged = false;

    try {
      if (await _ensureTalmud(onStatus, onDownloadProgress, cancelled)) {
        libraryChanged = true;
      }
    } catch (e) {
      debugPrint('[CompanionAssets] talmud update failed: $e');
    }
    if (cancelled()) return libraryChanged;

    try {
      if (await _ensureCatalog(onStatus)) libraryChanged = true;
    } catch (e) {
      debugPrint('[CompanionAssets] catalog update failed: $e');
    }
    if (cancelled()) return libraryChanged;

    try {
      onStatus?.call('בודק מילון חיפוש');
      final downloader = _dictionaryFactory();
      try {
        // ensureLatest מדווח 1.0 גם כשהמילון כבר מעודכן — לא מציגים "מוריד".
        var announced = false;
        await downloader.ensureLatest(onProgress: (progress) {
          if (progress >= 1.0) return;
          if (!announced) {
            announced = true;
            onStatus?.call('מוריד מילון לחיפוש המקורב');
          }
          onDownloadProgress?.call((progress * 10000).round(), 10000);
        });
      } finally {
        downloader.dispose();
      }
    } catch (e) {
      debugPrint('[CompanionAssets] dictionary update failed: $e');
    }
    return libraryChanged;
  }

  // ── תלמוד בבלי ────────────────────────────────────────────────────────

  /// מחזיר `true` רק כשהתלמוד הורד והותקן בפועל.
  Future<bool> _ensureTalmud(
    void Function(String message)? onStatus,
    void Function(int received, int? total)? onDownloadProgress,
    bool Function() cancelled,
  ) async {
    onStatus?.call('בודק את התלמוד הבבלי');
    final dirs = _talmudDirsProvider();
    final existingDir = dirs.where((d) {
      // תיקייה שאינה נגישה לקריאה (הרשאות, אחסון חיצוני) נחשבת כלא קיימת.
      try {
        final dir = Directory(d);
        return dir.existsSync() && dir.listSync().whereType<File>().isNotEmpty;
      } on FileSystemException {
        return false;
      }
    }).firstOrNull;

    final client = _clientFactory();
    try {
      final release = await _fetchTalmudRelease(client);
      if (existingDir != null) {
        final marker = File(p.join(existingDir, talmudVersionFileName));
        final installed =
            marker.existsSync() ? marker.readAsStringSync().trim() : '';
        if (installed.isEmpty) {
          // התקנה קיימת ללא סימון גרסה — מחתימים את התג הנוכחי בלי להוריד
          // מחדש; עדכונים יזוהו מה-release הבא ואילך.
          marker.writeAsStringSync(release.tag);
          return false;
        }
        if (installed == release.tag) return false;
      }
      if (cancelled()) return false;

      onStatus?.call('מוריד את התלמוד הבבלי');
      final targetDir = existingDir ?? dirs.first;
      final tempPath = p.join(Directory.systemTemp.path,
          'otzaria_${DatabaseConstants.talmudBavliArchiveFileName}');
      try {
        await _downloadToFile(
          client,
          release.assetUrl,
          tempPath,
          onDownloadProgress,
          cancelled,
        );
        if (cancelled()) return false;

        onStatus?.call('מחלץ את התלמוד הבבלי');
        Directory(targetDir).createSync(recursive: true);
        File(p.join(targetDir, talmudVersionFileName))
            .writeAsStringSync(talmudInstallingMarker);
        // הארכיון מכיל את התיקייה 'תלמוד בבלי/' — מחולץ לתיקיית האב.
        // ההתקדמות מכסה את שלב ה-zst; שלב פריסת ה-tar ללא מדידה — עוברים
        // להודעת ספינר כדי שהמד לא ייתקע על 100%.
        var zstDone = false;
        await _extractTarArchive(tempPath, p.dirname(targetDir), (progress) {
          if (zstDone) return;
          if (progress >= 0.999) {
            zstDone = true;
            onStatus?.call('פורס את קבצי התלמוד');
          } else {
            onDownloadProgress?.call((progress * 10000).round(), 10000);
          }
        });
      } finally {
        // גם הורדה שנכשלה/בוטלה משאירה קובץ חלקי של מאות MB — מנקים תמיד.
        await File(tempPath).delete().catchError((_) => File(tempPath));
      }
      File(p.join(targetDir, talmudVersionFileName))
          .writeAsStringSync(release.tag);
      // קיום תיקיית התלמוד ממוטמן ב-DatabaseLibraryProvider — בלי ניקוי,
      // הריענון שאחרי העדכון לא יגלה את התיקייה החדשה עד הפעלה מחדש.
      _invalidateLibraryCaches();
      return true;
    } finally {
      client.close();
    }
  }

  Future<({String tag, String assetUrl})> _fetchTalmudRelease(
      http.Client client) async {
    final response = await client.get(
      Uri.parse(_talmudReleaseApiUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'otzaria',
      },
    ).timeout(_apiTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('GitHub API החזיר ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) {
      throw Exception('release ללא tag_name');
    }
    final assets = (json['assets'] as List?) ?? const [];
    for (final a in assets) {
      final asset = a as Map<String, dynamic>;
      if (asset['name'] == DatabaseConstants.talmudBavliArchiveFileName) {
        return (
          tag: tag,
          assetUrl: asset['browser_download_url'] as String,
        );
      }
    }
    throw Exception(
        'לא נמצא ${DatabaseConstants.talmudBavliArchiveFileName} ב-release $tag');
  }

  Future<void> _downloadToFile(
    http.Client client,
    String url,
    String destPath,
    void Function(int received, int? total)? onProgress,
    bool Function() cancelled,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw Exception('הורדה נכשלה (${response.statusCode})');
    }
    final total = response.contentLength;
    final sink = File(destPath).openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        if (cancelled()) {
          throw Exception('ההורדה בוטלה');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  // ── קטלוג otzar-HB ────────────────────────────────────────────────────

  /// מחזיר `true` כשהקטלוג הורד או עודכן בפועל.
  Future<bool> _ensureCatalog(
    void Function(String message)? onStatus,
  ) async {
    final repository = _catalogRepository();
    if (await repository.databaseExists()) {
      onStatus?.call('בודק עדכון קטלוגים');
      final updated = await repository.updateDatabaseIfNeeded();
      if (updated) _invalidateExternalBooksCache();
      return updated;
    }
    onStatus?.call('מוריד את הקטלוגים');
    await repository.downloadLatestDatabase();
    _invalidateExternalBooksCache();
    return true;
  }
}
