import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/windowing/window_bus.dart';

/// מסנכרן בין חלונות את המאגרים שהמשתמש מצפה שיהיו משותפים:
/// היסטוריה, סימניות, הערות ושולחנות עבודה.
///
/// ## למה שידור ולא מאגר משותף
///
/// `hive_ce` נועל את קובצי ה-`.lock` בלעדית, והנעילה היא פר-handle — שני
/// חלונות באותו תהליך נכשלים בדיוק כמו שני תהליכים. לכן לכל חלון יש
/// קובצי Hive משלו, ואי אפשר "פשוט לפתוח את אותו קובץ".
///
/// המודל כאן הוא **שידור שינויים**: חלון שכתב מודיע לאחרים מה השתנה, וכל
/// אחד מהם טוען מחדש את המאגר שלו. זה נכון כי כל השינויים הרלוונטיים הם
/// פעולות של המשתמש בקצב אנושי — הוספת סימנייה, פתיחת ספר — ולא זרם
/// נתונים.
///
/// ⚠️ **מה זה לא פותר.** שני חלונות שכותבים את אותה רשומה באותו רגע
/// יגברו זה על זה לפי סדר הגעה. זה מקובל לסימניות והיסטוריה, ולא היה
/// מקובל למשל למונה שמוגדל — אין כאן מיזוג, רק "האחרון מנצח".
class SharedStateSync {
  SharedStateSync._();

  static final SharedStateSync instance = SharedStateSync._();

  /// סוג הבקשה באפיק.
  static const String requestType = 'stateChanged';

  /// המאגרים שמסתנכרנים. השם הוא שם ה-box ב-Hive.
  static const Set<String> syncedStores = {
    'history',
    'bookmarks',
    'workspaces',
    'notes',
  };

  final Map<String, List<VoidCallback>> _listeners = {};

  /// נרשם לקבלת הודעה כאשר [store] השתנה **בחלון אחר**.
  ///
  /// מחזיר פונקציית ביטול. הקורא אחראי לקרוא לה — מאזין שנשאר אחרי
  /// שה-bloc שלו נסגר יטען מחדש מאגר שאיש כבר לא קורא.
  VoidCallback listen(String store, VoidCallback onChanged) {
    final list = _listeners.putIfAbsent(store, () => []);
    list.add(onChanged);
    return () => list.remove(onChanged);
  }

  /// מודיע לשאר החלונות ש-[store] השתנה כאן.
  ///
  /// ⚠️ fire-and-forget במכוון. אם חלון אחר לא ענה — הוא נסגר, או עסוק —
  /// זו אינה סיבה להיכשל בפעולה שהמשתמש ביצע כאן. הסימנייה שלו כבר
  /// נשמרה; מה שלא קרה הוא רק רענון התצוגה אצל השכן.
  void broadcast(String store) {
    if (!syncedStores.contains(store)) {
      assert(false, 'מאגר לא מוכר לסנכרון: $store');
      return;
    }
    for (var slot = 1; slot <= WindowBus.slotCount; slot++) {
      if (slot == WindowBus.instance.slot) continue;
      unawaited(
        WindowBus.instance
            .request(slot, {'type': requestType, 'store': store})
            .catchError((Object e) {
              debugPrint('broadcast to slot $slot failed: $e');
              return null;
            }),
      );
    }
  }

  /// מטופל על ידי [WindowBus] כשמגיעה הודעת שינוי מחלון אחר.
  bool handleRemoteChange(Object? store) {
    if (store is! String || !syncedStores.contains(store)) return false;
    final list = _listeners[store];
    if (list == null) return true;
    // עותק: מאזין רשאי לבטל את עצמו מתוך הקולבק.
    for (final listener in List<VoidCallback>.of(list)) {
      try {
        listener();
      } catch (e) {
        debugPrint('sync listener for $store threw: $e');
      }
    }
    return true;
  }

  @visibleForTesting
  void clearListeners() => _listeners.clear();
}
