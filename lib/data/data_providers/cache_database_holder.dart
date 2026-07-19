import 'package:flutter/foundation.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';

/// סינגלטון שמחזיק את ה-DB וה-repository הכתיבים למטמונים תפעוליים.
///
/// ה-DB עצמו (`cache.db`) משתמש באותה סכמה ובאותם DAOs כמו `seforim.db`,
/// אך הוא קובץ נפרד וכתיב בתיקיית מסדי הנתונים הפעילה. ההפרדה מאפשרת
/// ל-`seforim.db` הרשמי להיפתח read-only — כתיבות מטמון בזמן ריצה
/// (כגון מטמון ה-outline של קובצי PDF חיצוניים) זורמות לכאן במקום.
///
/// המופע מאותחל בעצלתיים — בקריאה הראשונה ל-[repository].
class CacheDatabaseHolder {
  CacheDatabaseHolder._();

  static final CacheDatabaseHolder instance = CacheDatabaseHolder._();

  MyDatabase? _database;
  SeforimRepository? _repository;
  Future<SeforimRepository>? _initFuture;

  /// מחזיר את ה-repository הכתיב של המטמון, מאתחל אם צריך.
  ///
  /// אם האתחול נכשל (DB נעול, נתיב חסר הרשאות וכו'), ה-Future שנשמר
  /// מאופס כדי שקריאה חוזרת תנסה לפתוח את ה-DB מחדש במקום להחזיר את
  /// אותה שגיאה לנצח.
  Future<SeforimRepository> get repository {
    if (_repository != null) return Future.value(_repository!);
    return _initFuture ??= _initialize().onError<Object>((error, stackTrace) {
      _initFuture = null;
      throw error;
    });
  }

  /// נתיב ה-DB. שימושי בזרימות isolate שצריכות לפתוח את הקובץ ישירות.
  static Future<String> resolveDbPath() => AppPaths.resolveCacheDbPath();

  Future<SeforimRepository> _initialize() async {
    final dbPath = await AppPaths.resolveCacheDbPath();
    debugPrint('🗂️ [CacheDB] Opening cache.db at $dbPath');
    final db = MyDatabase.withPath(dbPath);
    final repo = SeforimRepository(db);
    try {
      await repo.ensureInitialized();
    } catch (e) {
      // כשל באתחול — סוגרים את החיבור כדי לא להדליף קובץ פתוח/נעול.
      db.close();
      rethrow;
    }
    _database = db;
    _repository = repo;
    return repo;
  }

  /// סוגר את ה-DB. שימושי בעיקר לבדיקות.
  Future<void> close() async {
    _database?.close();
    _database = null;
    _repository = null;
    _initFuture = null;
  }
}
