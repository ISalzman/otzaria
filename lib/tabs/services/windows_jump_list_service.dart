import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/tabs/models/tab.dart';

/// מסנכרן את רשימת הטאבים הפתוחים ל-Jump List של שורת המשימות ב-Windows.
///
/// כל פריט ב-Jump List מריץ את אוצריא עם `otzaria://open/tab/<index>`, וה-runner
/// הנייטיב מעביר זאת למופע החי (single-instance) שמחליף לטאב המבוקש. הסנכרון
/// מתבצע רק ב-Windows; בשאר הפלטפורמות הקריאות הן no-op.
class WindowsJumpListService {
  static const MethodChannel _channel = MethodChannel('otzaria/jumplist');

  /// כותרות הטאבים שנשלחו לאחרונה — מונע קריאות נייטיב מיותרות כשהמצב לא השתנה.
  List<String>? _lastTitles;

  /// הכותרות שנשלחות כרגע ואלה שיישלחו אחריהן.
  List<String>? _sendingTitles;
  List<String>? _queuedTitles;

  bool get _isSupported => !kIsWeb && Platform.isWindows;

  /// מעדכן את ה-Jump List לרשימת הטאבים הנתונה (לפי הסדר). שולח רק כאשר
  /// הכותרות או סדרן שונים מהמצב שאליו ה-Jump List מתקדם.
  ///
  /// עדכון שמגיע בזמן ששליחה רצה מחליף את התור במקום להצטבר — כל שליחה היא
  /// קריאת COM יקרה, ופתיחת ספרים ברצף מייצרת עדכון לכל ספר.
  Future<void> sync(List<OpenedTab> tabs) async {
    if (!_isSupported) return;

    final titles = tabs.map((tab) => tab.title).toList(growable: false);
    // ההשוואה היא מול היעד שאליו מתקדמים, ולא מול מה שנשלח בעבר: אחרת חזרה
    // למצב הקודם בזמן שליחה נבלעת, וה-Jump List נשאר על מצב שאינו קיים.
    final target = _queuedTitles ?? _sendingTitles ?? _lastTitles;
    if (listEquals(target, titles)) return;

    _queuedTitles = titles;
    if (_sendingTitles != null) return;

    try {
      while (_queuedTitles != null) {
        final pending = _queuedTitles!;
        _queuedTitles = null;
        _sendingTitles = pending;
        try {
          final ok = await _channel.invokeMethod<bool>('updateTabs', {
            'titles': pending,
          });
          // מעדכנים את הזיכרון רק בהצלחה — אחרת אותה רשימה תישלח שוב בשינוי
          // הבא במקום להיתקע על מצב שלא נכתב בפועל.
          if (ok == true) {
            _lastTitles = pending;
          }
        } catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint('עדכון ה-Jump List נכשל: $error\n$stackTrace');
          }
        }
      }
    } finally {
      _sendingTitles = null;
    }
  }
}
