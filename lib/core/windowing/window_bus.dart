import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// אפיק הודעות בין חלונות אוצריא.
///
/// כל חלון הוא isolate נפרד עם מנוע Flutter משלו, **באותו תהליך** (מודל A).
/// ל-isolates נפרדים אין זיכרון משותף ואין ביניהם `SendPort` מובנה, אבל
/// [IsolateNameServer] של המנוע הוא רישום **גלובלי לתהליך** — משותף לכל
/// המנועים. זהו המנגנון היחיד שמאפשר לחלונות לדבר בלי לצאת לנייטיב.
///
/// ⚠️ למה משבצות ולא רישום דינמי: אין "ספרייה" מרכזית שאפשר לשאול מי קיים,
/// וגם אין חלון שמובטח שיהיה חי (המשתמש יכול לסגור את הראשון). לכן כל חלון
/// **תופס משבצת** משמות ידועים מראש, והחיפוש הוא סריקה של כולן. התקרה של
/// ארבעה חלונות היא מה שהופך את זה למעשי.
class WindowBus {
  WindowBus._();

  static final WindowBus instance = WindowBus._();

  /// מספר המשבצות. חייב להתאים ל-`kMaxWindows` ב-`windows/runner`.
  static const int slotCount = 4;

  static String _slotName(int slot) => 'otzaria.window.$slot';

  ReceivePort? _port;
  int? _slot;

  /// המשבצת שהחלון הזה תפס, או null אם טרם נרשם.
  int? get slot => _slot;

  /// מטפל בבקשות נכנסות. נקבע פעם אחת על ידי החלון.
  ///
  /// מקבל את גוף הבקשה ומחזיר תשובה שתישלח חזרה לשולח. חריגה בתוכו
  /// מוחזרת כשגיאה ולא מפילה את החלון.
  Future<Object?> Function(Map<String, dynamic> request)? onRequest;

  /// תופס משבצת פנויה ומתחיל להאזין.
  ///
  /// מחזיר את מספר המשבצת, או null אם כולן תפוסות — מצב שאמור להיות בלתי
  /// אפשרי כי ה-runner אוכף את אותה תקרה, אבל עדיף להיכשל בשקט מאשר לדרוס
  /// רישום של חלון אחר.
  int? register() {
    if (_slot != null) return _slot;
    final port = ReceivePort();
    for (var candidate = 1; candidate <= slotCount; candidate++) {
      final name = _slotName(candidate);
      // ⚠️ `registerPortWithName` נכשל אם השם תפוס — זו בדיוק בדיקת
      // התפיסה האטומית, ואין צורך ב-lookup מקדים שהיה יוצר מרוץ.
      if (IsolateNameServer.registerPortWithName(port.sendPort, name)) {
        _slot = candidate;
        _port = port;
        port.listen(_handleMessage);
        return candidate;
      }
    }
    port.close();
    return null;
  }

  /// משחרר את המשבצת. חובה בסגירת חלון, אחרת המשבצת נשארת "תפוסה" בלי
  /// מאזין וחלון חדש לא יוכל לתפוס אותה.
  void unregister() {
    final slot = _slot;
    if (slot != null) {
      IsolateNameServer.removePortNameMapping(_slotName(slot));
    }
    _port?.close();
    _port = null;
    _slot = null;
  }

  void _handleMessage(dynamic message) {
    if (message is! Map) return;
    final reply = message['reply'];
    final body = message['body'];
    if (reply is! SendPort || body is! Map) return;
    final request = Map<String, dynamic>.from(body);

    Future<void>(() async {
      try {
        final handler = onRequest;
        final result = handler == null ? null : await handler(request);
        reply.send({'ok': true, 'result': result});
      } catch (e) {
        reply.send({'ok': false, 'error': '$e'});
      }
    });
  }

  /// שולח בקשה לחלון במשבצת [slot] וממתין לתשובה.
  ///
  /// מחזיר null אם אין חלון במשבצת, אם הוא לא ענה בתוך [timeout], או אם
  /// הוא החזיר שגיאה. **timeout הוא חובה ולא נוחות**: חלון עסוק או חלון
  /// שנסגר באמצע היו משאירים את הקורא תלוי לנצח.
  Future<Object?> request(
    int slot,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final target = IsolateNameServer.lookupPortByName(_slotName(slot));
    if (target == null) return null;

    final reply = ReceivePort();
    try {
      target.send({'reply': reply.sendPort, 'body': body});
      final response = await reply.first.timeout(timeout);
      if (response is Map && response['ok'] == true) {
        return response['result'];
      }
      if (response is Map) {
        debugPrint('WindowBus slot $slot returned error: ${response['error']}');
      }
      return null;
    } on TimeoutException {
      debugPrint('WindowBus slot $slot timed out');
      return null;
    } catch (e) {
      debugPrint('WindowBus slot $slot request failed: $e');
      return null;
    } finally {
      reply.close();
    }
  }

  /// סורק את כל המשבצות ומחזיר את החלונות האחרים שעונים.
  ///
  /// ⚠️ נשאלים בפועל ולא רק נבדק אם השם רשום: משבצת יכולה להישאר רשומה
  /// אחרי שחלון נסגר בלי לשחרר אותה (קריסה, סגירה כפויה), ואז הרישום
  /// קיים אבל אין מאזין. השאלה עצמה היא הבדיקה.
  Future<List<WindowPeer>> peers({
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    final futures = <Future<WindowPeer?>>[];
    for (var candidate = 1; candidate <= slotCount; candidate++) {
      if (candidate == _slot) continue;
      futures.add(
        request(candidate, const {'type': 'describe'}, timeout: timeout).then(
          (result) {
            if (result is! Map) return null;
            return WindowPeer(
              slot: candidate,
              title: (result['title'] as String?) ?? 'חלון $candidate',
              tabCount: (result['tabCount'] as int?) ?? 0,
            );
          },
        ),
      );
    }
    final results = await Future.wait(futures);
    return results.whereType<WindowPeer>().toList();
  }
}

/// חלון אחר שעונה על האפיק.
@immutable
class WindowPeer {
  const WindowPeer({
    required this.slot,
    required this.title,
    required this.tabCount,
  });

  final int slot;

  /// כותרת לתצוגה בתפריט — בדרך כלל שם הכרטיסיה הפעילה באותו חלון.
  final String title;

  final int tabCount;

  @override
  bool operator ==(Object other) =>
      other is WindowPeer &&
      other.slot == slot &&
      other.title == title &&
      other.tabCount == tabCount;

  @override
  int get hashCode => Object.hash(slot, title, tabCount);
}
