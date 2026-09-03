import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/windowing/window_bus.dart';

/// סנכרון הגדרות **חי** בין חלונות אוצריא.
///
/// ## למה בכלל, ולמה לא דרך המאגר המשותף
///
/// חלון משני מקבל שורש Hive פרטי, ולכן `app_preferences` שלו הוא קובץ
/// נפרד שנזרע פעם אחת בפתיחה. זריעה חד-פעמית פירושה שהחלפת ערכת נושא או
/// גודל גופן בחלון אחד לא נראית בשני — והמשתמש רואה שני חלונות של אותה
/// תוכנה נראים שונה.
///
/// ניתוב ההגדרות לבעלים, כמו ההיסטוריה והסימניות, **אינו** אפשרי כאן:
/// `Settings.getValue` סינכרוני ונקרא מתוך `build`, מאות פעמים בפריים.
/// בקשת אפיק לכל קריאה כזו אינה באה בחשבון.
///
/// ## המודל: כתיבה מקומית + שידור
///
/// כל חלון ממשיך לכתוב ל-box שלו — קריאה נשארת סינכרונית וחינמית. אחרי
/// הכתיבה הערך **משודר**, ושאר החלונות מחילים אותו על ה-box שלהם ומרעננים
/// את ה-state שנגזר ממנו.
///
/// ⚠️ אין כאן פתרון להתנגשויות, ובמכוון: הגדרה היא ערך יחיד שהמשתמש שינה
/// בחלון אחד, ואין "מיזוג" של שתי בחירות. האחרון קובע, וזה גם מה שהמשתמש
/// מצפה שיקרה.
class SettingsSync {
  SettingsSync._();

  static final SettingsSync instance = SettingsSync._();

  /// סוג הבקשה באפיק.
  static const String requestChanged = 'settingChanged';

  /// ⚠️ debounce לכל מפתח. גרירת מחוון גודל גופן כותבת עשרות פעמים
  /// בשנייה, וכל כתיבה הייתה שידור לשלושה חלונות. הערך האחרון הוא היחיד
  /// שמעניין.
  static const Duration _coalesce = Duration(milliseconds: 150);

  /// הפונקציה שכותבת ערך ל-box המקומי. מוזרקת על ידי `HiveCache`, כדי
  /// שהקובץ הזה לא יהיה תלוי בשכבת הנתונים.
  Future<void> Function(String key, Object? value)? applyLocally;

  final Map<String, Timer> _pending = {};
  final Map<String, Object?> _latest = {};

  final StreamController<String> _changes = StreamController<String>.broadcast(
    sync: true,
  );

  /// מפתחות שהשתנו **בחלון אחר**. מי שמאזין צריך לטעון מחדש את ה-state
  /// שנגזר מהם.
  Stream<String> get changes => _changes.stream;

  /// ⚠️ מונע לופ. החלת שינוי מרוחק כותבת ל-box, והכתיבה הזו עוברת דרך
  /// אותם setters — בלי הדגל היא הייתה משודרת בחזרה, לנצח.
  bool _applyingRemote = false;

  /// מפתחות שהם **מצב של חלון** ולא הגדרה של התוכנה, ולכן אינם מסונכרנים.
  ///
  /// ⚠️ גבולות החלון ומצב המיקסום נשמרים באותו box, אבל שידורם היה מזיז
  /// חלון אחד בכל פעם שהמשתמש מזיז את השני. `WindowPersistence` כבר אינו
  /// שומר אותם בחלון משני, וזו שכבת ההגנה השנייה — והמקום שאליו יתווסף כל
  /// מפתח פר-חלון עתידי.
  static const Set<String> _windowScopedPrefixes = {
    'window_bounds_',
    'window_is_',
  };

  static bool _isWindowScoped(String key) =>
      _windowScopedPrefixes.any(key.startsWith);

  /// נקרא מכל setter של `HiveCache` אחרי הכתיבה המקומית.
  void broadcastChange(String key, Object? value) {
    if (_applyingRemote) return;
    if (_isWindowScoped(key)) return;
    if (!_isSyncable(value)) return;
    _latest[key] = value;
    _pending[key]?.cancel();
    _pending[key] = Timer(_coalesce, () {
      _pending.remove(key);
      final latest = _latest.remove(key);
      WindowBus.instance.broadcast({
        'type': requestChanged,
        'key': key,
        'value': latest,
      });
    });
  }

  /// רק ערכים שעוברים את גבול ה-isolate כפי שהם.
  ///
  /// `SendPort` מעביר גרפים של אובייקטים, אבל ערך שאינו פרימיטיבי יגיע
  /// כעותק שאינו זהה למה ש-`CacheProvider` יודע לקרוא. שאר המפתחות פשוט
  /// אינם מסונכרנים, וזה עדיף על ערך שנכתב שבור.
  static bool _isSyncable(Object? value) =>
      value == null ||
      value is bool ||
      value is num ||
      value is String ||
      (value is List && value.every((e) => e is String));

  /// מטפל בהודעת שינוי שהגיעה מחלון אחר. מחזיר null כשהבקשה אינה שלנו.
  Future<Object?> handleRequest(Map<String, dynamic> request) async {
    if (request['type'] != requestChanged) return null;
    final key = request['key'];
    if (key is! String) return null;

    final apply = applyLocally;
    if (apply == null) return false;
    _applyingRemote = true;
    try {
      await apply(key, request['value']);
    } catch (e) {
      debugPrint('SettingsSync: failed to apply $key: $e');
      return false;
    } finally {
      _applyingRemote = false;
    }
    _changes.add(key);
    return true;
  }

  /// ⚠️ חובה בסגירת חלון: טיימר שנשאר משדר שינוי אחרי שהחלון נעלם.
  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    _latest.clear();
  }
}
