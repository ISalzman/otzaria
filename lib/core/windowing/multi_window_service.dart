import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
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

  /// הערוץ מול ה-runner.
  ///
  /// חשוף כי התקשורת דו-כיוונית: `adoptPayload` נשלחת מה-runner אל החלון
  /// כשהוא מחזיר חלון מוסתר לשימוש עם כרטיסיה חדשה.
  static const MethodChannel channel = MethodChannel('otzaria/multiwindow');
  static const MethodChannel _channel = channel;

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
      // המידות נשלחות ל-runner כדי שייצור את החלון בגודל הנכון מלכתחילה.
      // שינוי גודל אחרי היצירה היה מאתחל את ה-swapchain של המנוע וגורם
      // להבהוב, בדיוק כמו שקורה בחלון הראשון (ראו initSettingsAndWindow).
      Size? inherited;
      try {
        inherited = await windowManager.getSize();
      } catch (_) {
        // בלי מידות ה-runner ייצור בגודל ברירת מחדל.
      }
      final opened = await _channel.invokeMethod<bool>('openWindow', {
        'payload': _encodePayload(tab),
        if (inherited != null) 'width': inherited.width.round(),
        if (inherited != null) 'height': inherited.height.round(),
      });
      // false פירושו שהתקרה הושגה — ה-runner הוא מקור האמת למספר החלונות.
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('openWindow failed: ${e.code} ${e.message}');
      return false;
    } on MissingPluginException {
      // ה-runner בגרסה זו אינו מכיר את הערוץ — למשל בבדיקות widget.
      return false;
    }
  }

  /// מספר החלונות הפתוחים והתקרה.
  ///
  /// ה-runner הוא מקור האמת: ה-isolate של כל חלון רואה רק את עצמו.
  Future<({int count, int max})> windowCount() async {
    if (!isSupported) return (count: 1, max: 1);
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(
        'windowCount',
      );
      if (info == null) return (count: 1, max: 1);
      return (
        count: (info['count'] as int?) ?? 1,
        max: (info['max'] as int?) ?? 1,
      );
    } on PlatformException catch (e) {
      debugPrint('windowCount failed: ${e.code} ${e.message}');
      return (count: 1, max: 1);
    } on MissingPluginException {
      return (count: 1, max: 1);
    }
  }

  /// מביא את החלון הנוכחי לחזית.
  ///
  /// ⚠️ חלון משני נוצר מוסתר כדי שלא ייראה מצטייר, ו-`show()` על חלון
  /// מוסתר אינו מפעיל אותו — הוא נחשף **מאחורי** החלון שפתח אותו.
  Future<void> raiseSelf() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('raiseSelf');
    } catch (e) {
      debugPrint('raiseSelf failed: $e');
    }
  }

  /// מתחיל להציג את הכרטיסיה הנגררת **מחוץ** לחלון.
  ///
  /// ⚠️ ה-`feedback` של `Draggable` מצויר ב-Overlay של החלון ולכן נחתך
  /// בגבולותיו: ברגע שהסמן יוצא, הכרטיסיה נעלמת. המשתמש אינו רואה שהוא
  /// גורר משהו, ולכן גם אינו יכול לכוון לשורת המשימות או לחלון אחר.
  /// ה-runner מציג חלון layered שעוקב אחרי הסמן ומופיע רק בחוץ.
  Future<void> beginTabDrag(String title) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('beginTabDrag', title);
    } catch (e) {
      debugPrint('beginTabDrag failed: $e');
    }
  }

  /// מסיים את תצוגת הגרירה. חייב להיקרא בכל מסלולי הסיום — גם בביטול,
  /// אחרת התצוגה נשארת תלויה על המסך.
  Future<void> endTabDrag() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('endTabDrag');
    } catch (e) {
      debugPrint('endTabDrag failed: $e');
    }
  }

  /// משחזר את החלון האחרון שנסגר. מחזיר true אם היה כזה.
  ///
  /// ⚠️ אפשרי **רק** מפני שחלון סגור מוסתר ולא נהרס: המנוע שלו חי עם
  /// הכרטיסיות שהיו בו, ולכן השחזור הוא הצגה בלבד ולא טעינה מחדש.
  Future<bool> restoreLastClosedWindow() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('restoreLastClosedWindow') ??
          false;
    } catch (e) {
      debugPrint('restoreLastClosedWindow failed: $e');
      return false;
    }
  }

  /// ממיר נקודת מסך לקואורדינטות אזור-הלקוח של החלון הזה, בפיקסלים
  /// לוגיים.
  ///
  /// ⚠️ ההמרה ב-runner ולא כאן: המיקום מגיע מחלון אחר, ו-Flutter אינו
  /// יודע היכן החלון שלו יושב על המסך.
  Future<Offset?> screenToClient(int x, int y, double devicePixelRatio) async {
    if (!isSupported) return null;
    try {
      final p = await _channel.invokeMapMethod<String, dynamic>(
        'screenToClient',
        {'x': x, 'y': y},
      );
      if (p == null) return null;
      return Offset(
        ((p['x'] as int?) ?? 0) / devicePixelRatio,
        ((p['y'] as int?) ?? 0) / devicePixelRatio,
      );
    } catch (e) {
      debugPrint('screenToClient failed: $e');
      return null;
    }
  }

  /// מודיע ל-runner באיזו משבצת באפיק החלון הזה יושב.
  ///
  /// ⚠️ בלי זה אי אפשר לגרור כרטיסיה בין חלונות: Win32 יודע איזה **חלון**
  /// נמצא תחת הסמן, ו-Dart מזהה חלונות לפי משבצת. זה המתרגם.
  Future<void> setBusSlot(int slot) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setBusSlot', slot);
    } catch (e) {
      debugPrint('setBusSlot failed: $e');
    }
  }

  /// מה נמצא תחת סמן העכבר ברגע זה.
  ///
  /// [slot] הוא משבצת חלון אוצריא, או null כשהסמן מעל שולחן העבודה או מעל
  /// תוכנה אחרת. [isSelf] מבדיל בין שחרור מעל החלון שממנו גוררים לבין
  /// שחרור מעל חלון אחר.
  Future<({int? slot, bool isSelf, int x, int y})> windowAtCursor() async {
    if (!isSupported) return (slot: null, isSelf: false, x: 0, y: 0);
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(
        'windowAtCursor',
      );
      if (info == null) return (slot: null, isSelf: false, x: 0, y: 0);
      return (
        slot: info['slot'] as int?,
        isSelf: info['isSelf'] == true,
        x: (info['x'] as int?) ?? 0,
        y: (info['y'] as int?) ?? 0,
      );
    } catch (e) {
      debugPrint('windowAtCursor failed: $e');
      return (slot: null, isSelf: false, x: 0, y: 0);
    }
  }

  /// סוגר את החלון הנוכחי בלי לסיים את התהליך.
  ///
  /// ⚠️ ולא `windowManager.destroy()`: הוא קורא ל-`DestroyWindow` מתוך
  /// טיפול בערוץ, כלומר מתוך ריצת ה-Dart של החלון. הריסת מנוע משם היא
  /// ריאנטרנטית, ונמדד שהיא מפילה את התהליך כולו בכל סגירת חלון.
  Future<void> closeSelf() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('closeSelf');
    } catch (e) {
      debugPrint('closeSelf failed: $e');
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

  /// סוג בקשה באפיק: קבלת כרטיסיה שהועברה מחלון אחר.
  static const String requestReceiveTab = 'receiveTab';

  /// סוג בקשה באפיק: תיאור החלון לתצוגה בתפריט.
  static const String requestDescribe = 'describe';

  /// סוג בקשה באפיק: כרטיסיה נגררת מעל החלון הזה כרגע.
  ///
  /// ⚠️ החלון היעד אינו יודע דבר על גרירה שמתרחשת בחלון אחר — הם isolates
  /// נפרדים, ומחוות העכבר נתפסת אצל המקור. בלי ההודעה הזו אין דרך להציג
  /// קו חיווי או להדגיש את היעד.
  static const String requestDragOver = 'dragOver';

  /// סוג בקשה באפיק: הגרירה עזבה את החלון הזה או הסתיימה.
  static const String requestDragLeave = 'dragLeave';

  /// מודיע לחלון [slot] שכרטיסיה נגררת מעליו, בנקודה גלובלית נתונה.
  ///
  /// מחזיר את מיקום ההכנסה ברצועת הכרטיסיות שלו, או null כשהסמן אינו מעל
  /// הרצועה — כך המקור יודע אם השחרור ימזג למקום מדויק או רק יעביר.
  Future<int?> notifyDragOver(int slot, int x, int y, String title) async {
    final result = await WindowBus.instance.request(slot, {
      'type': requestDragOver,
      'x': x,
      'y': y,
      'title': title,
    }, timeout: const Duration(milliseconds: 400));
    return result is int ? result : null;
  }

  /// מודיע לחלון [slot] שהגרירה עזבה אותו. fire-and-forget: אם לא נמסר,
  /// החיווי ייעלם ממילא בסיום הגרירה.
  void notifyDragLeave(int slot) {
    unawaited(
      WindowBus.instance.request(slot, {'type': requestDragLeave}),
    );
  }

  /// מעביר [tab] לחלון קיים במשבצת [slot].
  ///
  /// מחזיר true רק אם החלון היעד **אישר** שקיבל את הכרטיסיה. זה חשוב:
  /// המעביר מסיר את הכרטיסיה מעצמו רק אחרי אישור, אחרת כרטיסיה שנשלחה
  /// לחלון שנסגר בדיוק אז הייתה נעלמת משני הצדדים.
  /// [index] הוא מיקום ההכנסה ברצועת היעד, כשהשחרור היה מעליה. `null`
  /// מוסיף בסוף — התנהגות "העבר לחלון קיים" מהתפריט.
  Future<bool> sendTabToWindow(int slot, OpenedTab tab, {int? index}) async {
    if (!canTransfer(tab)) return false;
    final result = await WindowBus.instance.request(slot, {
      'type': requestReceiveTab,
      'tab': tab.toJson(),
      'index': ?index,
    });
    return result == true;
  }

  /// החלונות האחרים הפתוחים, לתצוגה בתת-תפריט.
  Future<List<WindowPeer>> otherWindows() => WindowBus.instance.peers();

  /// הרשימה האחרונה שנסרקה, לשימוש מקוד **סינכרוני**.
  ///
  /// ⚠️ קיימת כי בניית תפריט ההקשר סינכרונית, וסריקת החלונות אינה יכולה
  /// להיות. `WindowBusHost` מרענן אותה ברקע. רשימה מעט לא-עדכנית אינה
  /// מסוכנת: שליחה לחלון שנסגר בינתיים נכשלת ומדווחת למשתמש, ולא מאבדת
  /// את הכרטיסיה.
  static List<WindowPeer> knownPeers = const [];

  /// האם המטען מכיל כרטיסיה, בלי לפענח אותה.
  ///
  /// ⚠️ קיים כי הפענוח המלא תלוי ב-`Settings` ואינו אפשרי בנקודת הכניסה,
  /// אבל הניווט למסך הקריאה צריך להיקבע עוד לפני `runApp`.
  static bool payloadHasTab(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map && decoded['tab'] is Map;
    } catch (_) {
      return false;
    }
  }

  /// האם הכרטיסיה שורדת מסע הלוך-ושוב של סריאליזציה.
  ///
  /// ⚠️ נבדק **לפני** שמסירים אותה מהחלון המקורי. כרטיסיה שאינה ניתנת
  /// לשחזור הייתה נעלמת מהמקור ולא נפתחת ביעד — כלומר אובדן מידע. עדיף
  /// לא להעביר מאשר לאבד.
  static bool canTransfer(OpenedTab tab) {
    try {
      OpenedTab.fromJson(Map<String, dynamic>.from(tab.toJson()));
      return true;
    } catch (e) {
      debugPrint('canTransfer failed for ${tab.runtimeType}: $e');
      return false;
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
