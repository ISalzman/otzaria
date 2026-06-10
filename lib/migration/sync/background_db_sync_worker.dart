import 'dart:isolate';

import '../../data/data_providers/database_library_provider.dart';
import '../database/daos/database.dart';
import '../database/repository/seforim_repository.dart';
import '../database/sql/query_loader.dart';
import '../../settings/services/custom_folders/custom_folder.dart';
import 'file_sync_service.dart';

/// תקרת זמן לעבודת האיזולייט. אם הוא נתקע, ה-await נכשל ב-TimeoutException
/// וה-finally הפנימי תמיד מריץ את [restoreAfterWrite] (פתיחה-מחדש של ה-RO) —
/// כך לא נשארת דליפת write-session (מסך עיון/תצוגה מקדימה ריקים עד restart).
const Duration _isolateSyncWatchdog = Duration(seconds: 90);

/// Runs a full custom-folders DB sync inside a background isolate.
///
/// All calls are serialised through [DatabaseLibraryProvider.operationQueue]
/// so that concurrent writes to the same SQLite file are impossible,
/// regardless of which call site invokes this function.
///
/// [QueryLoader] is pre-initialised on the main isolate and its cache is
/// forwarded in the payload, avoiding any [rootBundle] access inside the
/// worker isolate.
///
/// [dbPath] — נתיב `seforim.db` (לתוכן רשמי + links).
/// [userBooksDbPath] — נתיב `user_books.db` (לתיקיות מותאמות אישית).
///
/// [prepareForWrite]/[restoreAfterWrite] — וו אופציונלי שהקורא מזריק כדי לסגור
/// ולפתוח-מחדש את חיבור הקריאה ל-seforim.db (closeForExternalWrite/reopen).
/// הם רצים *בתוך* יחידת התור (לא בזמן ההמתנה בתור), צמודים ב-try/finally כך
/// שה-RO נסגר רק למשך הכתיבה ולא בזמן שפעולת תור אחרת (למשל סריקת ספרים
/// אישיים) רצה לפנינו. שכבת הנתונים עצמה אינה תלויה ב-SqliteDataProvider —
/// הקורא (שכבת האפליקציה) מזריק את הלוגיקה.
Future<FileSyncResult> runCustomFoldersDbSyncInIsolate({
  required String dbPath,
  required String userBooksDbPath,
  required String libraryPath,
  required List<CustomFolder> customFolders,
  String folderName = '',
  Future<void> Function()? prepareForWrite,
  Future<void> Function()? restoreAfterWrite,
}) async {
  Map<String, Object?> buildPayload({
    required bool syncFolders,
    required bool syncLinks,
  }) =>
      <String, Object?>{
        'queryCache': QueryLoader.cacheSnapshot,
        'dbPath': dbPath,
        'userBooksDbPath': userBooksDbPath,
        'libraryPath': libraryPath,
        'folderName': folderName,
        'customFolders': customFolders.map((f) => f.toJson()).toList(),
        'syncFolders': syncFolders,
        'syncLinks': syncLinks,
      };

  // שלב 1 — כתיבת הספרים האישיים ל-user_books.db. seforim.db נפתח RO (רק
  // קריאות), ולכן *אין* קריאה ל-prepareForWrite/restoreAfterWrite: ה-RO הראשי
  // נשאר פתוח וקריאות עובדות לכל אורך החלק הכבד הזה.
  final folders =
      await DatabaseLibraryProvider.operationQueue.enqueue(() async {
    await QueryLoader.initialize();
    final resultMap = await _runSyncWorkerIsolate(
      buildPayload(syncFolders: true, syncLinks: false),
    );
    return _resultFromMap(resultMap);
  });

  // שלב 2 — עיבוד ה-links → seforim.db (RW). *רק כאן* סוגרים את ה-RO הראשי
  // (prepareForWrite) ופותחים מחדש (restoreAfterWrite), לזמן הקצר של כתיבת
  // ה-links בלבד.
  final links = await DatabaseLibraryProvider.operationQueue.enqueue(() async {
    await QueryLoader.initialize();
    final payload = buildPayload(syncFolders: false, syncLinks: true);
    if (prepareForWrite != null) await prepareForWrite();
    try {
      final resultMap = await _runSyncWorkerIsolate(payload);
      return _resultFromMap(resultMap);
    } finally {
      if (restoreAfterWrite != null) await restoreAfterWrite();
    }
  });

  return FileSyncResult(
    addedBooks: folders.addedBooks + links.addedBooks,
    updatedBooks: folders.updatedBooks + links.updatedBooks,
    addedCategories: folders.addedCategories + links.addedCategories,
    addedLinks: folders.addedLinks + links.addedLinks,
    skippedFiles: folders.skippedFiles + links.skippedFiles,
    errors: [...folders.errors, ...links.errors],
    duration: folders.duration + links.duration,
  );
}

FileSyncResult _resultFromMap(Map<String, Object?> resultMap) => FileSyncResult(
      addedBooks: resultMap['addedBooks'] as int,
      updatedBooks: resultMap['updatedBooks'] as int,
      addedCategories: resultMap['addedCategories'] as int,
      addedLinks: resultMap['addedLinks'] as int,
      skippedFiles: resultMap['skippedFiles'] as int,
      errors: List<String>.from(resultMap['errors'] as List),
      duration: Duration(milliseconds: resultMap['durationMs'] as int),
    );

/// מריץ את ה-worker באיזולייט. *חובה* להישאר פונקציה נפרדת: ה-closure שנשלח
/// ל-[Isolate.run] חייב לסגור רק על [payload] (מפה של ערכים שליחים). אם ה-
/// Isolate.run נכתב ישירות בתוך הפונקציה הקוראת — שחולקת scope עם
/// prepareForWrite/restoreAfterWrite — הקומפיילר מאגד אותם ל-context משותף,
/// וה-closure "סוחב" איתו את ה-SqliteDataProvider/FfiDatabase הלא-שליח
/// (Illegal argument in isolate message: object is unsendable).
Future<Map<String, Object?>> _runSyncWorkerIsolate(
  Map<String, Object?> payload,
) {
  return Isolate.run(() => _syncWorkerEntryPoint(payload))
      .timeout(_isolateSyncWatchdog);
}

/// כמו [_runSyncWorkerIsolate] עבור מחיקה — נפרדת כדי שה-closure של
/// [Isolate.run] יסגור רק על [payload] (ראה ההסבר שם).
Future<void> _runDeleteWorkerIsolate(Map<String, Object?> payload) {
  return Isolate.run(() => _deleteWorkerEntryPoint(payload))
      .timeout(_isolateSyncWatchdog);
}

/// Runs a folder-delete operation inside a background isolate.
///
/// [folderPath] הוא הנתיב המלא של התיקייה — ממנו נגזר שם ה-`source`
/// הייחודי שלפיו מזוהים ספרי התיקייה למחיקה. זיהוי לפי source (ולא לפי שם
/// קטגוריה) מונע פגיעה בתיקייה אחרת בעלת אותו basename.
/// Serialised through the same [DatabaseLibraryProvider.operationQueue].
///
/// [userBooksDbPath] — נתיב `user_books.db` (שם נמצאות התיקיות המותאמות).
/// [dbPath] — נתיב `seforim.db`. נדרש כי `FileSyncService` מצפה לשני repos.
Future<void> runDeleteFolderFromDbInIsolate({
  required String dbPath,
  required String userBooksDbPath,
  required String folderPath,
  Future<void> Function()? prepareForWrite,
  Future<void> Function()? restoreAfterWrite,
}) {
  return DatabaseLibraryProvider.operationQueue.enqueue(() async {
    await QueryLoader.initialize();
    // Build payload on the main isolate so cacheSnapshot is evaluated here,
    // not lazily inside the worker closure.
    final payload = <String, Object?>{
      'queryCache': QueryLoader.cacheSnapshot,
      'dbPath': dbPath,
      'userBooksDbPath': userBooksDbPath,
      'folderPath': folderPath,
    };
    // [prepareForWrite]/[restoreAfterWrite] רצים בתוך יחידת התור — ראה ההסבר
    // ב-[runCustomFoldersDbSyncInIsolate].
    if (prepareForWrite != null) await prepareForWrite();
    try {
      await _runDeleteWorkerIsolate(payload);
    } finally {
      if (restoreAfterWrite != null) await restoreAfterWrite();
    }
  });
}

// ── worker entry points (top-level so they're transferable) ──────────────────

Future<Map<String, Object?>> _syncWorkerEntryPoint(
    Map<String, Object?> payload) async {
  QueryLoader.seedCache(
    (payload['queryCache'] as Map).cast<String, Map<String, String>>(),
  );

  final dbPath = payload['dbPath'] as String;
  final userBooksDbPath = payload['userBooksDbPath'] as String;
  final libraryPath = payload['libraryPath'] as String;
  final folderName = (payload['folderName'] as String?) ?? '';
  final syncFolders = (payload['syncFolders'] as bool?) ?? true;
  final syncLinks = (payload['syncLinks'] as bool?) ?? true;
  final rawFolders =
      (payload['customFolders'] as List).cast<Map<String, dynamic>>();
  final customFolders = rawFolders.map(CustomFolder.fromJson).toList();

  // seforim.db נפתח RW *רק* כשמעבדים links (היחיד שכותב לשם). בשלב הספרים
  // האישיים אנחנו רק קוראים מ-seforim.db (בדיקת dedup), ולכן פותחים אותו RO —
  // כך החיבור הראשי לא צריך להיסגר והקריאות ממשיכות לעבוד לכל אורך הכתיבה.
  final database = MyDatabase.withPath(dbPath, readOnly: !syncLinks);
  final repository = SeforimRepository(database);
  await repository.ensureInitialized();

  final userBooksDatabase = MyDatabase.withPath(userBooksDbPath);
  final userBooksRepository = SeforimRepository(userBooksDatabase);
  await userBooksRepository.ensureInitialized();

  final service = FileSyncService.createForWorker(
    repository,
    userBooksRepository: userBooksRepository,
  );

  try {
    final result = await service.syncCustomFoldersWithInputs(
      libraryPath: libraryPath,
      customFolders: customFolders,
      folderName: folderName,
      syncFolders: syncFolders,
      syncLinks: syncLinks,
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
    userBooksDatabase.close();
  }
}

Future<void> _deleteWorkerEntryPoint(Map<String, Object?> payload) async {
  QueryLoader.seedCache(
    (payload['queryCache'] as Map).cast<String, Map<String, String>>(),
  );

  final dbPath = payload['dbPath'] as String;
  final userBooksDbPath = payload['userBooksDbPath'] as String;
  final folderPath = payload['folderPath'] as String;

  final database = MyDatabase.withPath(dbPath);
  final repository = SeforimRepository(database);
  await repository.ensureInitialized();

  final userBooksDatabase = MyDatabase.withPath(userBooksDbPath);
  final userBooksRepository = SeforimRepository(userBooksDatabase);
  await userBooksRepository.ensureInitialized();

  final service = FileSyncService.createForWorker(
    repository,
    userBooksRepository: userBooksRepository,
  );

  try {
    await service.deleteFolderFromDatabase(folderPath);
  } finally {
    database.close();
    userBooksDatabase.close();
  }
}
