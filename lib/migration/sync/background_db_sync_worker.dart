import 'dart:isolate';

import '../../data/data_providers/database_library_provider.dart';
import '../dao/daos/database.dart';
import '../dao/repository/seforim_repository.dart';
import '../dao/sqflite/query_loader.dart';
import '../../settings/services/custom_folders/custom_folder.dart';
import 'file_sync_service.dart';

/// Runs a full custom-folders DB sync inside a background isolate.
///
/// All calls are serialised through [DatabaseLibraryProvider.operationQueue]
/// so that concurrent writes to the same SQLite file are impossible,
/// regardless of which call site invokes this function.
///
/// [QueryLoader] is pre-initialised on the main isolate and its cache is
/// forwarded in the payload, avoiding any [rootBundle] access inside the
/// worker isolate.
Future<FileSyncResult> runCustomFoldersDbSyncInIsolate({
  required String dbPath,
  required String libraryPath,
  required List<CustomFolder> customFolders,
}) {
  return DatabaseLibraryProvider.operationQueue.enqueue(() async {
    await QueryLoader.initialize();
    final payload = <String, Object?>{
      'queryCache': QueryLoader.cacheSnapshot,
      'dbPath': dbPath,
      'libraryPath': libraryPath,
      'customFolders': customFolders.map((f) => f.toJson()).toList(),
    };
    final resultMap = await Isolate.run(() => _syncWorkerEntryPoint(payload));
    return FileSyncResult(
      addedBooks: resultMap['addedBooks'] as int,
      updatedBooks: resultMap['updatedBooks'] as int,
      addedCategories: resultMap['addedCategories'] as int,
      addedLinks: resultMap['addedLinks'] as int,
      skippedFiles: resultMap['skippedFiles'] as int,
      errors: List<String>.from(resultMap['errors'] as List),
      duration: Duration(milliseconds: resultMap['durationMs'] as int),
    );
  });
}

/// Runs a folder-delete operation inside a background isolate.
///
/// [folderCategoryId] and [personalCategoryId] must be resolved by the
/// caller on the main isolate before invoking this function.
/// Serialised through the same [DatabaseLibraryProvider.operationQueue].
Future<void> runDeleteFolderFromDbInIsolate({
  required String dbPath,
  required int folderCategoryId,
  required int personalCategoryId,
}) {
  return DatabaseLibraryProvider.operationQueue.enqueue(() async {
    await QueryLoader.initialize();
    // Build payload on the main isolate so cacheSnapshot is evaluated here,
    // not lazily inside the worker closure.
    final payload = <String, Object?>{
      'queryCache': QueryLoader.cacheSnapshot,
      'dbPath': dbPath,
      'folderCategoryId': folderCategoryId,
      'personalCategoryId': personalCategoryId,
    };
    await Isolate.run(() => _deleteWorkerEntryPoint(payload));
  });
}

// ── worker entry points (top-level so they're transferable) ──────────────────

Future<Map<String, Object?>> _syncWorkerEntryPoint(
    Map<String, Object?> payload) async {
  QueryLoader.seedCache(
    (payload['queryCache'] as Map).cast<String, Map<String, String>>(),
  );

  final dbPath = payload['dbPath'] as String;
  final libraryPath = payload['libraryPath'] as String;
  final rawFolders =
      (payload['customFolders'] as List).cast<Map<String, dynamic>>();
  final customFolders = rawFolders.map(CustomFolder.fromJson).toList();

  final database = MyDatabase.withPath(dbPath);
  final repository = SeforimRepository(database);
  await repository.ensureInitialized();
  final service = FileSyncService.createForWorker(repository);

  try {
    final result = await service.syncCustomFoldersWithInputs(
      libraryPath: libraryPath,
      customFolders: customFolders,
    );
    return {
      'addedBooks': result.addedBooks,
      'updatedBooks': result.updatedBooks,
      'addedCategories': result.addedCategories,
      'addedLinks': result.addedLinks,
      'skippedFiles': result.skippedFiles,
      'errors': result.errors,
      'durationMs': result.duration.inMilliseconds,
    };
  } finally {
    database.close();
  }
}

Future<void> _deleteWorkerEntryPoint(Map<String, Object?> payload) async {
  QueryLoader.seedCache(
    (payload['queryCache'] as Map).cast<String, Map<String, String>>(),
  );

  final dbPath = payload['dbPath'] as String;
  final folderCategoryId = payload['folderCategoryId'] as int;
  final personalCategoryId = payload['personalCategoryId'] as int;

  final database = MyDatabase.withPath(dbPath);
  final repository = SeforimRepository(database);
  await repository.ensureInitialized();
  final service = FileSyncService.createForWorker(repository);

  try {
    await service.deleteFolderFromDatabase(folderCategoryId, personalCategoryId);
  } finally {
    database.close();
  }
}
