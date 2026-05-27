import 'package:kosher_dart/kosher_dart.dart';

/// הקשר החישוב המועבר לכל פונקציית חישוב של זמן.
class ZmanComputeContext {
  final ComplexZmanimCalendar cal;
  final JewishCalendar jewishCalendar;
  final String city;
  final DateTime date;

  const ZmanComputeContext({
    required this.cal,
    required this.jewishCalendar,
    required this.city,
    required this.date,
  });
}

/// מחזירה את ה-DateTime של הזמן, או null אם לא ניתן לחשב.
typedef ZmanCompute = DateTime? Function(ZmanComputeContext ctx);

/// קובעת אם הגדרת הזמן רלוונטית ליום הנתון.
typedef ZmanRelevance = bool Function(JewishCalendar jc);

/// הגדרת זמן בודד.
///
/// תצוגה:
/// • כרטיס בודד בלוח — שורה 1: [title]; שורה 2 (קטנה יותר): [subtitle];
///   ומתחת השעה.
/// • כרטיס משולב (שתי הגדרות עם אותו [pairId]) — כותרת אחת [title] משותפת,
///   וכל ערך מתויג ב-[pairLabel] (למשל "מג"א"/"גר"א" או "72 דק׳ (מעלות)").
/// • טבלת "זמנים נוספים" — שם מלא = [title] + [subtitle].
class ZmanDefinition {
  /// מזהה ייחודי — מפתח ב-dailyTimes, מזהה התראה, ומפתח העדפת הצגה.
  final String id;

  /// שם כללי של הזמן (שורה ראשית בכרטיס; כותרת משותפת בכרטיס משולב).
  final String title;

  /// פירוט השיטה (שורה משנית בכרטיס בודד ובטבלה). למשל
  /// "מג"א 90 דק׳ (מעלות)", "גר"א", "72 דק׳ (מעלות)". ריק כשאין פירוט.
  final String subtitle;

  /// קטגוריה לקיבוץ בטבלה.
  final String category;

  /// הסבר אופן החישוב — לטולטיפ/חלונית המידע.
  final String explanation;

  /// פונקציית החישוב.
  final ZmanCompute compute;

  /// רלוונטיות תלוית-יום. null = תמיד רלוונטי.
  final ZmanRelevance? isRelevant;

  /// הדגשה כ"זמן מיוחד" (רקע שונה).
  final bool isHolidaySpecial;

  /// מוצג כברירת מחדל.
  final bool defaultEnabled;

  /// תצוגת תאריך עברי (ליל-שבוע + יום-חודש) במקום שעה בלבד — לקידוש לבנה.
  final bool showHebrewDate;

  /// כיוון התאמת זמן-יום עבור זמני קידוש לבנה (רלוונטי רק כש-[showHebrewDate]).
  /// רגע קידוש הלבנה (מולד + ימים) עלול ליפול בשעות היום, שאז אי-אפשר לקדש;
  /// כש-true (תחילת הזמן) הרגע נדחה קדימה לצאת הכוכבים, וכש-false (סוף הזמן)
  /// הוא נדחה אחורה לעלות השחר.
  final bool moladPushToTzais;

  /// זיווג לכרטיס משולב בלוח: שתי הגדרות עם אותו pairId מוצגות יחד.
  /// בטבלה כל אחת מופיעה כשורה נפרדת. null = תמיד כרטיס בודד.
  final String? pairId;

  /// תווית הערך בתוך הכרטיס המשולב (קצרה — "מג"א" / "72 דק׳ (מעלות)").
  final String pairLabel;

  const ZmanDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.explanation,
    required this.compute,
    this.subtitle = '',
    this.isRelevant,
    this.isHolidaySpecial = false,
    this.defaultEnabled = false,
    this.showHebrewDate = false,
    this.moladPushToTzais = true,
    this.pairId,
    this.pairLabel = '',
  });

  /// שם מלא לטבלה: כותרת ופירוט.
  String get fullName => subtitle.isEmpty ? title : '$title — $subtitle';
}
