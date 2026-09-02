import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
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

  /// שם ה-box של ההעדפות. חייב להתאים ל-[HiveCache.keyName].
  static const String _preferencesBoxName = 'app_preferences';

  /// המטען הוא מחרוזת ולא Map, כי הוא עובר כארגומנט לנקודת הכניסה של
  /// המנוע החדש (`set_dart_entrypoint_arguments`), וזו מקבלת מחרוזות בלבד.
  static String _encodePayload(OpenedTab? tab) {
    return jsonEncode({
      'version': 1,
      if (tab != null) 'tab': tab.toJson(),
      'settings': _snapshotPreferences(),
    });
  }

  /// צילום של כל העדפות החלון הנוכחי, כדי לזרוע בהן את החלון החדש.
  ///
  /// ⚠️ בלי זה החלון החדש חסר תועלת: שורש הנתונים שלו פרטי (Hive נועל
  /// בלעדית), ולכן הוא אינו יודע היכן הספרייה ומציג את מסך ההתחלה.
  ///
  /// זו **זריעה חד-פעמית ולא שיתוף חי**: שינוי הגדרה בחלון אחד לא יופיע
  /// בשני. השיתוף החי הוא פרק 3 במפת הדרכים.
  static Map<String, dynamic> _snapshotPreferences() {
    try {
      if (!Hive.isBoxOpen(_preferencesBoxName)) return const {};
      final box = Hive.box<dynamic>(_preferencesBoxName);
      final snapshot = <String, dynamic>{};
      for (final entry in box.toMap().entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String) continue;
        // רק ערכים שעוברים JSON. `CacheProvider` שומר פרימיטיבים ורשימות
        // מחרוזות בלבד, אבל בדיקה מפורשת עדיפה על מטען שנכשל בסריאליזציה
        // ומפיל את פתיחת החלון כולה.
        if (value is bool ||
            value is num ||
            value is String ||
            (value is List && value.every((e) => e is String))) {
          snapshot[key] = value;
        }
      }
      return snapshot;
    } catch (e) {
      debugPrint('_snapshotPreferences failed: $e');
      return const {};
    }
  }

  /// מפענח את צילום ההעדפות מתוך מטען.
  static Map<String, dynamic> decodePreferences(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return const {};
      final settings = decoded['settings'];
      if (settings is! Map) return const {};
      return Map<String, dynamic>.from(settings);
    } catch (e) {
      debugPrint('decodePreferences failed: $e');
      return const {};
    }
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
