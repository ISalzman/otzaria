import 'package:flutter/foundation.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';

/// סינגלטון שמחזיק את ה-DB וה-repository של ספרי המשתמש (תיקיות
/// מותאמות אישית).
///
/// ה-DB עצמו (`user_books.db`) משתמש באותה סכמה ובאותם DAOs כמו
/// `seforim.db`, אך הוא קובץ נפרד ב-`<dataRoot>/databases/`.
/// ההפרדה מבטיחה ששינויים בספרייה הרשמית לא ימחקו את הספרים של המשתמש,
/// ולהפך.
///
/// המופע מאותחל בעצלתיים — בקריאה הראשונה ל-[repository].
class UserBooksDatabaseHolder {
  UserBooksDatabaseHolder._();

  static final UserBooksDatabaseHolder instance = UserBooksDatabaseHolder._();

  MyDatabase? _database;
  SeforimRepository? _repository;
  Future<SeforimRepository>? _initFuture;

  /// מחזיר את ה-repository של ספרי המשתמש, מאתחל אם צריך.
  Future<SeforimRepository> get repository {
    if (_repository != null) return Future.value(_repository!);
    return _initFuture ??= _initialize();
  }

  /// נתיב ה-DB. שימושי בזרימות isolate שצריכות לפתוח את הקובץ ישירות.
  static Future<String> resolveDbPath() => AppPaths.resolveUserBooksDbPath();

  Future<SeforimRepository> _initialize() async {
    final dbPath = await AppPaths.resolveUserBooksDbPath();
    debugPrint('📚 [UserBooksDB] Opening user_books.db at $dbPath');
    final db = MyDatabase.withPath(dbPath);
    final repo = SeforimRepository(db);
    // ב-user_books.db אין תוכן רשמי עם IDs קבועים שעלולים להתנגש,
    // אז נותנים ל-SQLite להקצות IDs חיוביים אוטומטית.
    repo.useAutoIncrementIds = true;
    await repo.ensureInitialized();
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

/// מיפוי IDs של `user_books.db` ל-IDs פנימיים באפליקציה.
///
/// שני קבצי ה-DB מקצים IDs משלהם, ולכן `bookId=1` או `categoryId=1`
/// יכולים להתקיים גם ב-`seforim.db` וגם ב-`user_books.db`. כדי להעביר
/// IDs דרך מודלים קיימים בלי להוסיף שדה "מקור" לכל קריאה, ספרי המשתמש
/// מקבלים מרחב IDs נפרד: מספרים שליליים רחוקים שאינם מתנגשים עם ה-IDs
/// השליליים הישנים של `seforim.db`.
class UserBooksDatabaseIds {
  UserBooksDatabaseIds._();

  static const int _categoryOffset = 1000000000000;
  static const int _bookOffset = 2000000000000;

  static int toAppCategoryId(int dbCategoryId) =>
      -_categoryOffset - dbCategoryId;

  static int toDbCategoryId(int appCategoryId) =>
      isAppCategoryId(appCategoryId)
          ? -_categoryOffset - appCategoryId
          : appCategoryId;

  static bool isAppCategoryId(int categoryId) =>
      categoryId <= -_categoryOffset && categoryId > -_bookOffset;

  static int toAppBookId(int dbBookId) => -_bookOffset - dbBookId;

  static int toDbBookId(int appBookId) =>
      isAppBookId(appBookId) ? -_bookOffset - appBookId : appBookId;

  static bool isAppBookId(int bookId) => bookId <= -_bookOffset;
}
