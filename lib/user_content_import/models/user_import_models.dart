/// מודלים לייבוא נתוני-משתמש (דורות וקישורים) מקבצי CSV שהוכנו מראש.
///
/// ה-parser ([UserImportParser]) ממיר טקסט CSV למודלים האלה; שכבת ה-repository
/// כותבת אותם ל-user_books.db (דור → book_generation, קישור → user_link).
library;

/// שמות הדורות הקנוניים שמותר להזין בקובץ הדורות.
///
/// "שאר מפרשים" אינו ברשימה — הוא משמעו "בלי דור" ואין טעם לייבא אותו.
const Set<String> kCanonicalEraNames = {
  'תורה שבכתב',
  'חז"ל',
  'ראשונים',
  'אחרונים',
  'מחברי זמננו',
};

/// מיפוי תווית-סוג בעברית (בקובץ הקישורים) לשם connection_type ב-DB.
///
/// פירוש/תרגום הם תלויי-טקסט (מוצגים בפאנל המפרשים); הפניה/מקור מוצגים
/// בפאנל הקישורים. ראה [LinkTypes].
const Map<String, String> kHebrewConnectionTypes = {
  'פירוש': 'COMMENTARY',
  'תרגום': 'TARGUM',
  'הפניה': 'REFERENCE',
  'מקור': 'SOURCE',
  'אחר': 'OTHER',
};

/// שורת דור שפוענחה מקובץ הדורות.
class ParsedBookGeneration {
  /// כותרת הספר האישי שאליו משויך הדור.
  final String bookTitle;

  /// שם הדור הקנוני (אחד מ-[kCanonicalEraNames]).
  final String eraName;

  /// שם המחבר, אם צוין.
  final String? author;

  /// מזהה קטגוריה, אם צוין (לפירוק כפילות-כותרת).
  final int? categoryId;

  const ParsedBookGeneration({
    required this.bookTitle,
    required this.eraName,
    this.author,
    this.categoryId,
  });
}

/// שורת קישור שפוענחה מקובץ הקישורים.
class ParsedUserLink {
  /// כותרת ספר המקור — רלוונטי רק בקובץ הרוחבי (עמודת "ספר_מקור").
  /// בקובץ פר-ספר הערך null וספר המקור נקבע מהקשר.
  final String? sourceBookTitle;

  /// מספר השורה בספר המקור כפי שהמשתמש כתב (1-based).
  final int sourceLineNumber;

  /// כותרת ספר היעד (זיהוי לפי שם — תומך חוצה-DB).
  final String targetTitle;

  /// כתובת היעד כפי שנכתבה (ref), אם צוינה.
  final String? targetRef;

  /// שם connection_type ב-DB (אחד מערכי [kHebrewConnectionTypes]).
  final String connectionType;

  /// האם ספר היעד הוא ספר אישי (מפריד בין מרחבי ה-id).
  final bool targetIsUserBook;

  /// מזהה קטגוריית היעד, אם צוין (רמז ל-resolution).
  final int? targetCategoryId;

  const ParsedUserLink({
    this.sourceBookTitle,
    required this.sourceLineNumber,
    required this.targetTitle,
    this.targetRef,
    required this.connectionType,
    this.targetIsUserBook = false,
    this.targetCategoryId,
  });
}

/// רשומת קישור-משתמש כפי שהיא נשמרת בטבלת user_link ב-user_books.db.
///
/// אינדקסי השורות הם 0-based (כמו line.lineIndex ב-DB); בעת בניית [Link]
/// לתצוגה מוסיפים 1 (כמו [getLinksForBookRange]).
class UserLinkRecord {
  final int sourceBookId;
  final int sourceLineIndex;
  final String targetTitle;
  final int? targetCategoryId;
  final bool targetIsUserBook;
  final String? targetRef;
  final int? targetLineIndex;
  final String connectionType;

  /// כותרת ספר המקור — ממולא רק בשאילתת הקישורים ההפוכים ([inverseUserLinks]),
  /// כדי לבנות קישור שמצביע חזרה אל ספר-המשתמש.
  final String? sourceTitle;

  /// קטגוריית ספר המקור — ממולא רק ב-[inverseUserLinks], כדי שהקישור ההפוך
  /// יוכל לפתוח את ספר-המשתמש הנכון כששתי כותרות זהות בקטגוריות שונות.
  final int? sourceCategoryId;

  const UserLinkRecord({
    required this.sourceBookId,
    required this.sourceLineIndex,
    required this.targetTitle,
    this.targetCategoryId,
    this.targetIsUserBook = false,
    this.targetRef,
    this.targetLineIndex,
    required this.connectionType,
    this.sourceTitle,
    this.sourceCategoryId,
  });
}

/// שגיאת פענוח של שורה בודדת, לדיווח מרוכז למשתמש.
class ImportRowError {
  /// מספר השורה בקובץ (1-based, כולל שורת הכותרת).
  final int lineNumber;

  /// הודעת השגיאה בעברית.
  final String message;

  const ImportRowError(this.lineNumber, this.message);

  @override
  String toString() => 'שורה $lineNumber: $message';
}

/// תוצאת פענוח: השורות התקינות שנקלטו + רשימת השגיאות (שורות פגומות מדולגות).
class ParseResult<T> {
  final List<T> rows;
  final List<ImportRowError> errors;

  const ParseResult(this.rows, this.errors);

  bool get hasErrors => errors.isNotEmpty;
}
