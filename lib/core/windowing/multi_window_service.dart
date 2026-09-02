import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/tabs/models/tab.dart';

/// פותח חלונות אוצריא נוספים.
///
/// כל חלון הוא `FlutterEngine` נפרד, ב-isolate נפרד, על thread ייעודי משלו —
/// **באותו תהליך** (מודל A; ראו `docs/P-0-stage3-result.md`). ה-runner הוא
/// שיוצר את החלון, כי יצירת thread ולולאת הודעות אינן זמינות מ-Dart.
///
/// ⚠️ ה-thread הייעודי אינו פרט מימוש שאפשר לוותר עליו: ב-Flutter 3.47
/// ה-platform thread וה-UI thread ממוזגים, ולכן שני מנועים על אותו thread
/// חוסמים זה את זה. נמדד 2092ms הקפאה מול 102ms כשיש thread לכל מנוע.
class MultiWindowService {
  const MultiWindowService();

  static const MethodChannel _channel = MethodChannel('otzaria/multiwindow');

  /// האם ריבוי חלונות נתמך בפלטפורמה הנוכחית.
  ///
  /// היום Windows בלבד — הצד הנייטיב מומש ב-`windows/runner`. macOS ו-Linux
  /// הם פרק 12 במפת הדרכים.
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// פותח חלון חדש, ואם [tab] אינו null — עם אותו טאב פתוח בו.
  ///
  /// מחזיר true אם הבקשה נמסרה ל-runner. הצלחת המסירה אינה מבטיחה שהחלון
  /// עלה: הוא נוצר על thread אחר ובאופן אסינכרוני.
  Future<bool> openWindow({OpenedTab? tab}) async {
    if (!isSupported) return false;
    try {
      await _channel.invokeMethod<void>('openWindow', _encodePayload(tab));
      return true;
    } on PlatformException catch (e) {
      debugPrint('openWindow failed: ${e.code} ${e.message}');
      return false;
    } on MissingPluginException {
      // ה-runner בגרסה זו אינו מכיר את הערוץ — למשל בבדיקות widget.
      return false;
    }
  }

  /// המטען הוא מחרוזת ולא Map, כי הוא עובר כארגומנט לנקודת הכניסה של
  /// המנוע החדש (`set_dart_entrypoint_arguments`), וזו מקבלת מחרוזות בלבד.
  static String _encodePayload(OpenedTab? tab) {
    if (tab == null) return '';
    return jsonEncode({'version': 1, 'tab': tab.toJson()});
  }

  /// מפענח מטען שהתקבל בנקודת הכניסה של חלון משני.
  ///
  /// מחזיר null כשאין מטען או כשהוא פגום — חלון שנפתח בלי טאב תקין עולה
  /// ריק, וזו התנהגות מכוונת: עדיף חלון ריק מחלון שקורס באתחול.
  static OpenedTab? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final tabJson = decoded['tab'];
      if (tabJson is! Map) return null;
      return OpenedTab.fromJson(Map<String, dynamic>.from(tabJson));
    } catch (e) {
      debugPrint('decodePayload failed: $e');
      return null;
    }
  }
}
