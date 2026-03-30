import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/services/data_collection_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:zstandard/zstandard.dart';
import 'package:zstandard_native/zstandard_native_bindings.dart';

class FileSyncRepository {
  static const int _legacyDirectUpgradeSourceVersion = 3;
  static const int _legacyDirectUpgradePublishedFromVersion = 133;
  static const int _legacyDirectUpgradeTargetVersion = 134;
  static const String _fullDatabaseAssetName = 'seforim.db.zst';

  final String githubOwner;
  final String repositoryName;
  bool isSyncing = false;
  int _currentProgress = 0;
  int _totalFiles = 0;
  final http.Client _httpClient;
  final Zstandard _zstandard;
  final Future<Uint8List> Function(Uint8List compressedBytes)? _decompressDiff;
  final Future<void> Function(String downloadUrl, String outputPath)?
      _replaceDatabaseFromCompressedAsset;

  FileSyncRepository({
    required this.githubOwner,
    required this.repositoryName,
    http.Client? httpClient,
    Zstandard? zstandard,
    Future<Uint8List> Function(Uint8List compressedBytes)? decompressDiff,
    Future<void> Function(String downloadUrl, String outputPath)?
        replaceDatabaseFromCompressedAsset,
  })  : _httpClient = httpClient ?? http.Client(),
        _zstandard = zstandard ?? Zstandard(),
        _decompressDiff = decompressDiff,
        _replaceDatabaseFromCompressedAsset =
            replaceDatabaseFromCompressedAsset;

  int get currentProgress => _currentProgress;
  int get totalFiles => _totalFiles;

  Future<List<String>> checkForUpdates({int? targetVersion}) async {
    final currentVersion = await getCurrentLibraryVersion();
    final assets = await fetchAvailableDiffAssets();
    final chain = buildUpdateChain(
      currentVersion: currentVersion,
      availableAssets: assets,
      targetVersion: targetVersion,
    );
    if (chain.isNotEmpty) {
      return chain.map((asset) => asset.assetName).toList();
    }

    final legacyReplacement = findLegacyFullDatabaseReplacementRelease(
      currentVersion: currentVersion,
      availableAssets: assets,
      targetVersion: targetVersion,
    );
    if (legacyReplacement != null) {
      return const [_fullDatabaseAssetName];
    }

    return const [];
  }

  Future<int> syncFiles({int? targetVersion}) async {
    if (isSyncing) {
      return 0;
    }

    isSyncing = true;
    _currentProgress = 0;
    _totalFiles = 0;

    try {
      final currentVersion = await getCurrentLibraryVersion();
      final assets = await fetchAvailableDiffAssets();
      final chain = buildUpdateChain(
        currentVersion: currentVersion,
        availableAssets: assets,
        targetVersion: targetVersion,
      );
      final legacyReplacement = findLegacyFullDatabaseReplacementRelease(
        currentVersion: currentVersion,
        availableAssets: assets,
        targetVersion: targetVersion,
      );

      if (targetVersion != null &&
          currentVersion < targetVersion &&
          (chain.isEmpty || chain.last.toVersion != targetVersion) &&
          legacyReplacement == null) {
        throw Exception(
          'לא נמצא רצף עדכונים מלא מגרסה $currentVersion לגרסה $targetVersion',
        );
      }

      _totalFiles = chain.isNotEmpty
          ? chain.length
          : legacyReplacement == null
              ? 0
              : 1;

      if (chain.isEmpty) {
        if (legacyReplacement != null) {
          final outputPath = DatabaseConstants.getDatabasePath();
          final downloadUrl =
              _buildFullDatabaseDownloadUrl(legacyReplacement.releaseTag);

          developer.log(
            'Applying full DB replacement for legacy upgrade '
            'v$currentVersion -> v${legacyReplacement.toVersion}',
            name: 'FileSyncRepository',
          );

          await (_replaceDatabaseFromCompressedAsset?.call(
                downloadUrl,
                outputPath,
              ) ??
              _downloadAndReplaceDatabaseFromCompressedAsset(
                downloadUrl,
                outputPath,
              ));
          _currentProgress = 1;
          return _currentProgress;
        }

        developer.log(
          'No library DIFF updates found for version $currentVersion',
          name: 'FileSyncRepository',
        );
      } else {
        for (final asset in chain) {
          if (!isSyncing) {
            break;
          }

          developer.log(
            'Applying library DIFF ${asset.assetName}',
            name: 'FileSyncRepository',
          );

          final sql = await _downloadAndExtractDiff(asset);
          await _applyDiffSql(sql);
          _currentProgress++;
        }
      }

      return _currentProgress;
    } catch (e) {
      developer.log(
        'Error during DB DIFF sync',
        name: 'FileSyncRepository',
        error: e,
      );
      rethrow;
    } finally {
      isSyncing = false;
    }
  }

  Future<void> stopSyncing() async {
    isSyncing = false;
  }

  Future<int> getCurrentLibraryVersion() async {
    sqlite3.Database? db;
    try {
      db = _openRawDatabase();
      final result = db.select(
        'SELECT value FROM db_meta WHERE key = ? LIMIT 1',
        ['content_version_int'],
      );

      if (result.isNotEmpty) {
        final rawValue = result.first['value']?.toString();
        final parsed = int.tryParse(rawValue ?? '');
        if (parsed != null) {
          return parsed;
        }
      }
    } finally {
      db?.close();
    }

    final displayVersion = await DataCollectionService().readLibraryVersion();
    final match = RegExp(r'(\d+)').firstMatch(displayVersion);
    final fallback = match == null ? null : int.tryParse(match.group(1)!);
    if (fallback != null) {
      return fallback;
    }

    throw Exception('לא ניתן לזהות את גרסת מסד הנתונים הנוכחית');
  }

  Future<List<DiffReleaseAsset>> fetchAvailableDiffAssets() async {
    final url = Uri.parse(
        'https://api.github.com/repos/$githubOwner/$repositoryName/releases');
    final response = await _httpClient.get(
      url,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('שגיאה בקבלת רשימת רליסים: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw Exception('מבנה התשובה של GitHub אינו תקין');
    }

    final assets = <DiffReleaseAsset>[];

    for (final rawRelease in decoded) {
      if (rawRelease is! Map<String, dynamic>) {
        continue;
      }

      if (rawRelease['draft'] == true || rawRelease['prerelease'] == true) {
        continue;
      }

      final tagName = rawRelease['tag_name']?.toString() ?? '';
      final releaseName = rawRelease['name']?.toString() ?? tagName;
      final rawAssets = rawRelease['assets'];

      if (rawAssets is! List) {
        continue;
      }

      for (final rawAsset in rawAssets) {
        if (rawAsset is! Map<String, dynamic>) {
          continue;
        }

        final parsed = DiffReleaseAsset.tryParse(
          rawAsset,
          releaseTag: tagName,
          releaseName: releaseName,
        );
        if (parsed != null) {
          assets.add(parsed);
        }
      }
    }

    assets.sort(
      (a, b) => a.fromVersion == b.fromVersion
          ? a.toVersion.compareTo(b.toVersion)
          : a.fromVersion.compareTo(b.fromVersion),
    );

    return assets;
  }

  @visibleForTesting
  static List<DiffReleaseAsset> buildUpdateChain({
    required int currentVersion,
    required List<DiffReleaseAsset> availableAssets,
    int? targetVersion,
  }) {
    final bySourceVersion = <int, List<DiffReleaseAsset>>{};

    for (final asset in availableAssets) {
      bySourceVersion.putIfAbsent(asset.fromVersion, () => []).add(asset);
    }

    final chain = <DiffReleaseAsset>[];
    var version = currentVersion;

    while (true) {
      final candidates = bySourceVersion[version];
      if (candidates == null || candidates.isEmpty) {
        break;
      }

      DiffReleaseAsset? nextAsset;
      for (final candidate in candidates) {
        if (candidate.toVersion == version + 1) {
          nextAsset = candidate;
          break;
        }
      }

      if (nextAsset == null) {
        break;
      }

      chain.add(nextAsset);
      version = nextAsset.toVersion;
      if (targetVersion != null && version >= targetVersion) {
        break;
      }
    }

    return chain;
  }

  @visibleForTesting
  static DiffReleaseAsset? findLegacyFullDatabaseReplacementRelease({
    required int currentVersion,
    required List<DiffReleaseAsset> availableAssets,
    int? targetVersion,
  }) {
    if (currentVersion != _legacyDirectUpgradeSourceVersion) {
      return null;
    }

    if (targetVersion != null &&
        targetVersion < _legacyDirectUpgradeTargetVersion) {
      return null;
    }

    for (final asset in availableAssets) {
      if (asset.fromVersion == _legacyDirectUpgradePublishedFromVersion &&
          asset.toVersion == _legacyDirectUpgradeTargetVersion) {
        return asset;
      }
    }

    return null;
  }

  Future<String> _downloadAndExtractDiff(DiffReleaseAsset asset) async {
    final response = await _httpClient.get(
      Uri.parse(asset.downloadUrl),
      headers: const {'Accept': 'application/octet-stream'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'שגיאה בהורדת ${asset.assetName}: ${response.statusCode}',
      );
    }

    final compressedBytes = Uint8List.fromList(response.bodyBytes);
    final extractedBytes = _decompressDiff != null
        ? await _decompressDiff(compressedBytes)
        : await _zstandard.decompress(compressedBytes);

    if (extractedBytes == null || extractedBytes.isEmpty) {
      throw Exception('קובץ ה-DIFF שחולץ ריק: ${asset.assetName}');
    }

    return utf8.decode(extractedBytes);
  }

  Future<void> _downloadAndReplaceDatabaseFromCompressedAsset(
    String downloadUrl,
    String outputPath,
  ) async {
    final response = await _httpClient.get(
      Uri.parse(downloadUrl),
      headers: const {'Accept': 'application/octet-stream'},
    );

    if (response.statusCode != 200) {
      throw Exception(
          'שגיאה בהורדת $_fullDatabaseAssetName: ${response.statusCode}');
    }

    final tempDir = await Directory.systemTemp.createTemp('otzaria-full-db-');
    final archivePath = '$tempDir/$_fullDatabaseAssetName';
    final extractedPath = '$tempDir/${DatabaseConstants.databaseFileName}';

    try {
      await File(archivePath).writeAsBytes(response.bodyBytes, flush: true);
      await _extractCompressedDatabaseToPath(archivePath, extractedPath);
      await _replaceDatabaseFileAtomically(
        extractedPath: extractedPath,
        outputPath: outputPath,
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _extractCompressedDatabaseToPath(
    String archivePath,
    String outputPath,
  ) async {
    try {
      await _extractCompressedDatabaseWithSystemProcess(archivePath, outputPath);
      return;
    } catch (e) {
      developer.log(
        'System zstd extraction unavailable, falling back to native streaming',
        name: 'FileSyncRepository',
        error: e,
      );
    }

    try {
      await Isolate.run(() => _decompressZstStreaming(archivePath, outputPath));
      return;
    } catch (e) {
      developer.log(
        'Native streaming extraction unavailable, falling back to in-memory decompression',
        name: 'FileSyncRepository',
        error: e,
      );
    }

    final compressedBytes = await File(archivePath).readAsBytes();
    final decompressed = await _zstandard.decompress(compressedBytes);
    if (decompressed == null) {
      throw Exception('חילוץ $_fullDatabaseAssetName נכשל');
    }

    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    await outputFile.writeAsBytes(decompressed, flush: true);
  }

  Future<void> _extractCompressedDatabaseWithSystemProcess(
    String archivePath,
    String outputPath,
  ) async {
    final process = await Process.start(
      'zstd',
      ['--long=31', '-dc', archivePath],
      runInShell: false,
    );

    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    final sink = outputFile.openWrite();

    try {
      await process.stdout.pipe(sink);
      final stderr = await utf8.decoder.bind(process.stderr).join();
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception(stderr.trim().isEmpty ? 'zstd exited with $exitCode' : stderr.trim());
      }
    } catch (_) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      rethrow;
    } finally {
      await sink.close();
    }
  }

  Future<void> _replaceDatabaseFileAtomically({
    required String extractedPath,
    required String outputPath,
  }) async {
    await SqliteDataProvider.instance.dispose();

    final destinationFile = File(outputPath);
    await destinationFile.parent.create(recursive: true);

    final tempOutput = File('$outputPath.tmp');
    if (await tempOutput.exists()) {
      await tempOutput.delete();
    }
    await File(extractedPath).rename(tempOutput.path);

    final backupFile = File('$outputPath.old');
    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    if (await destinationFile.exists()) {
      await destinationFile.rename(backupFile.path);
    }

    try {
      await tempOutput.rename(outputPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }
      if (await backupFile.exists()) {
        await backupFile.rename(outputPath);
      }
      rethrow;
    }
  }

  String _buildFullDatabaseDownloadUrl(String releaseTag) {
    return 'https://github.com/$githubOwner/$repositoryName/releases/download/'
        '$releaseTag/$_fullDatabaseAssetName';
  }

  Future<void> _applyDiffSql(String sql) async {
    final statements = splitSqlStatements(sql);
    if (statements.isEmpty) {
      throw Exception('קובץ ה-DIFF אינו מכיל פקודות SQL');
    }

    await SqliteDataProvider.instance.dispose();

    sqlite3.Database? db;
    try {
      db = _openRawDatabase();

      for (final statement in statements) {
        if (!isSyncing) {
          throw Exception('הסינכרון בוטל');
        }

        db.execute(statement);
      }
    } finally {
      db?.close();
    }
  }

  sqlite3.Database _openRawDatabase() {
    return sqlite3.sqlite3.open(
      DatabaseConstants.getDatabasePath(),
    );
  }

  @visibleForTesting
  static List<String> splitSqlStatements(String sql) {
    final statements = <String>[];
    var buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var inLineComment = false;
    var inBlockComment = false;

    for (var i = 0; i < sql.length; i++) {
      final char = sql[i];
      final nextChar = i + 1 < sql.length ? sql[i + 1] : '';

      if (inLineComment) {
        buffer.write(char);
        if (char == '\n') {
          inLineComment = false;
        }
        continue;
      }

      if (inBlockComment) {
        buffer.write(char);
        if (char == '*' && nextChar == '/') {
          buffer.write(nextChar);
          i++;
          inBlockComment = false;
        }
        continue;
      }

      if (!inSingleQuote && !inDoubleQuote) {
        if (char == '-' && nextChar == '-') {
          buffer.write(char);
          buffer.write(nextChar);
          i++;
          inLineComment = true;
          continue;
        }

        if (char == '/' && nextChar == '*') {
          buffer.write(char);
          buffer.write(nextChar);
          i++;
          inBlockComment = true;
          continue;
        }
      }

      if (char == "'" && !inDoubleQuote) {
        if (inSingleQuote && nextChar == "'") {
          buffer.write(char);
          buffer.write(nextChar);
          i++;
          continue;
        }

        inSingleQuote = !inSingleQuote;
        buffer.write(char);
        continue;
      }

      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(char);
        continue;
      }

      if (char == ';' && !inSingleQuote && !inDoubleQuote) {
        final statement = buffer.toString().trim();
        if (statement.isNotEmpty) {
          statements.add(statement);
        }
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
    }

    final trailingStatement = buffer.toString().trim();
    if (trailingStatement.isNotEmpty) {
      statements.add(trailingStatement);
    }

    return statements;
  }

  static void _decompressZstStreaming(String archivePath, String outputPath) {
    final dylib = _openZstandardDynamicLibrary();
    final bindings = ZstandardNativeBindings(dylib);

    const int windowLogMax = 31;
    final inBufSize = bindings.ZSTD_DStreamInSize();
    final outBufSize = bindings.ZSTD_DStreamOutSize();

    final dStream = bindings.ZSTD_createDStream();
    if (dStream == nullptr) {
      throw Exception('ZSTD_createDStream נכשל');
    }

    try {
      var ret = bindings.ZSTD_DCtx_setParameter(
        dStream.cast(),
        ZSTD_dParameter.ZSTD_d_windowLogMax,
        windowLogMax,
      );
      if (bindings.ZSTD_isError(ret) != 0) {
        throw Exception('הגדרת ZSTD_d_windowLogMax נכשלה: $ret');
      }

      ret = bindings.ZSTD_initDStream(dStream);
      if (bindings.ZSTD_isError(ret) != 0) {
        throw Exception('ZSTD_initDStream נכשל: $ret');
      }

      final inNative = malloc.allocate<Uint8>(inBufSize);
      final outNative = malloc.allocate<Uint8>(outBufSize);
      final inBuf = malloc<ZSTD_inBuffer_s>();
      final outBuf = malloc<ZSTD_outBuffer_s>();

      try {
        final inputRaf = File(archivePath).openSync();
        final outputFile = File(outputPath);
        if (outputFile.existsSync()) {
          outputFile.deleteSync();
        }
        final outputRaf = outputFile.openSync(mode: FileMode.writeOnly);

        try {
          final inView = inNative.asTypedList(inBufSize);
          var lastRet = 0;

          while (true) {
            final bytesRead = inputRaf.readIntoSync(inView);
            if (bytesRead == 0) {
              break;
            }

            inBuf.ref.src = inNative.cast();
            inBuf.ref.size = bytesRead;
            inBuf.ref.pos = 0;

            while (inBuf.ref.pos < inBuf.ref.size) {
              outBuf.ref.dst = outNative.cast();
              outBuf.ref.size = outBufSize;
              outBuf.ref.pos = 0;

              lastRet = bindings.ZSTD_decompressStream(dStream, outBuf, inBuf);
              if (bindings.ZSTD_isError(lastRet) != 0) {
                throw Exception('שגיאת ZSTD בחילוץ (קוד: $lastRet)');
              }

              if (outBuf.ref.pos > 0) {
                outputRaf.writeFromSync(outNative.asTypedList(outBuf.ref.pos));
              }
            }
          }

          if (lastRet != 0) {
            throw Exception(
              'קובץ ה-ZST קטוע או פגום: ה-frame לא הושלם (נותרו $lastRet bytes לפענוח)',
            );
          }

          outputRaf.flushSync();
        } finally {
          inputRaf.closeSync();
          outputRaf.closeSync();
        }
      } finally {
        malloc.free(inNative);
        malloc.free(outNative);
        malloc.free(inBuf);
        malloc.free(outBuf);
      }
    } finally {
      bindings.ZSTD_freeDStream(dStream);
    }
  }

  static DynamicLibrary _openZstandardDynamicLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libzstandard_android.so');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libzstandard_linux_plugin.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('zstandard_macos.framework/zstandard_macos');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('zstandard_windows.dll');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.open('zstandard_ios.framework/zstandard_ios');
    }
    throw UnsupportedError(
        'Platform not supported: ${Platform.operatingSystem}');
  }
}

class DiffReleaseAsset {
  final int fromVersion;
  final int toVersion;
  final String assetName;
  final String downloadUrl;
  final String releaseTag;
  final String releaseName;

  const DiffReleaseAsset({
    required this.fromVersion,
    required this.toVersion,
    required this.assetName,
    required this.downloadUrl,
    required this.releaseTag,
    required this.releaseName,
  });

  static final RegExp _assetPattern =
      RegExp(r'^(\d+)-(\d+)\.DIFF\.zst$', caseSensitive: false);

  static DiffReleaseAsset? tryParse(
    Map<String, dynamic> asset, {
    required String releaseTag,
    required String releaseName,
  }) {
    final assetName = asset['name']?.toString();
    final downloadUrl = asset['browser_download_url']?.toString();

    if (assetName == null || downloadUrl == null) {
      return null;
    }

    final match = _assetPattern.firstMatch(assetName);
    if (match == null) {
      return null;
    }

    final fromVersion = int.tryParse(match.group(1)!);
    final toVersion = int.tryParse(match.group(2)!);

    if (fromVersion == null || toVersion == null || toVersion <= fromVersion) {
      return null;
    }

    return DiffReleaseAsset(
      fromVersion: fromVersion,
      toVersion: toVersion,
      assetName: assetName,
      downloadUrl: downloadUrl,
      releaseTag: releaseTag,
      releaseName: releaseName,
    );
  }
}
