import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';

/// הפעלה עצלה של מופע רקע לתוסף עם תרומות עלייה (`contributes.startup`).
///
/// במקום WebView שחי מהעלייה (המנגנון הישן של `app.run_on_startup`), המנוע
/// של התוסף קם רק כשבאמת צריך אותו: לחיצה על פקד שנרשם דקלרטיבית, אירוע
/// שהתוסף הצהיר עליו ב-activationEvents, או טריגר `app.startup` דחוי.
/// אירועים שהגיעו לפני שהמופע סיים boot נשמרים בתור ונמסרים בסיומו.
class PluginLazyActivationService {
  static final PluginLazyActivationService instance =
      PluginLazyActivationService._();
  PluginLazyActivationService._();

  @visibleForTesting
  PluginLazyActivationService.forTesting();

  static const int _maxPendingPerPlugin = 20;

  /// השהיית טריגר `app.startup` — כדי שהרמת המנוע לא תתחרה בעליית התוכנה.
  static const Duration startupActivationDelay = Duration(seconds: 8);

  /// מופע רקע שהוער עצל ולא הראה פעילות (RPC או אירוע נכנס) במשך זמן זה —
  /// מכובה ומשחרר את תהליכי ה-WebView2. הטריגר הבא יעיר אותו מחדש.
  static const Duration idleTeardownDelay = Duration(minutes: 3);

  @visibleForTesting
  Duration? startupDelayOverride;

  @visibleForTesting
  Duration? idleDelayOverride;

  /// עוקף את מסירת האירועים דרך ה-Dispatcher — לבדיקות בלבד.
  @visibleForTesting
  Future<void> Function(
    String pluginId,
    String topic,
    Map<String, dynamic> payload,
  )?
  deliverOverride;

  /// נרשם ע"י PluginBackgroundHost — מרים מופע רקע לפי דרישה. זריקה מתוכו
  /// (תוסף לא זמין / אין WebView2) מנקה את התור של אותו תוסף.
  Future<void> Function(String pluginId)? backgroundActivator;

  /// נרשם ע"י PluginBackgroundHost — מכבה מופע רקע שהוער עצל וכעת באפס
  /// פעילות. ההרס עצמו (dispose של ה-WebView) באחריות ה-host.
  void Function(String pluginId)? backgroundDeactivator;

  /// תוספים שמותר להעיר בעצלנות (הרשאת startup contributions הוענקה).
  final Set<String> _activatable = {};

  /// נושאי שידור שמעירים כל תוסף (מסונכרן כולל בדיקת הרשאת subscribe).
  final Map<String, Set<String>> _broadcastTopics = {};

  final Map<String, List<({String topic, Map<String, dynamic> payload})>>
  _pending = {};
  final Set<String> _activating = {};

  /// טריגר `app.startup` מופעל פעם אחת לכל סשן — נשמר גם אחרי removePlugin
  /// כדי שסנכרון חוזר (LoadPlugins) לא יפעיל את התוסף שוב.
  final Set<String> _startupFired = {};

  /// תוספים שהמופע שלהם הוער עצל ולכן כפוף לכיבוי אחרי חוסר פעילות
  /// (מופעי run_on_startup הישנים, שנטענים בעלייה, אינם כאן).
  final Set<String> _idleTracked = {};
  final Map<String, Timer> _idleTimers = {};

  /// מונה RPC שעדיין רצים פר תוסף — כל עוד חיובי, פקיעת שעון הכיבוי רק
  /// מחדשת אותו, כדי לא לקטוע פעולה ארוכה (download/extractZip).
  final Map<String, int> _busyCounts = {};

  void syncPlugin(
    String pluginId, {
    required Set<String> broadcastTopics,
    required bool scheduleStartup,
  }) {
    _activatable.add(pluginId);
    _broadcastTopics[pluginId] = Set.unmodifiable(broadcastTopics);
    if (scheduleStartup && _startupFired.add(pluginId)) {
      Timer(startupDelayOverride ?? startupActivationDelay, () {
        if (_activatable.contains(pluginId)) _activate(pluginId);
      });
    }
  }

  void removePlugin(String pluginId) {
    _activatable.remove(pluginId);
    _broadcastTopics.remove(pluginId);
    _pending.remove(pluginId);
    _activating.remove(pluginId);
    final wasTracked = _idleTracked.contains(pluginId);
    _stopIdleTracking(pluginId);
    _busyCounts.remove(pluginId);
    // תוסף שאיבד את הזכאות (שלילת הרשאה/השבתה) בזמן שמופע עצל שלו רץ —
    // המופע מכובה מיד, לא ממשיך עד סוף הסשן.
    if (wasTracked) backgroundDeactivator?.call(pluginId);
  }

  /// כיבוי מיידי לבקשת התוסף (`plugin.backgroundDone`) — בלי להמתין לשעון
  /// חוסר-הפעילות. חל רק על מופע שהוער עצל: מופעי העלייה הישנים ודף התוסף
  /// אינם במעקב ולכן אינם מושפעים. מחזיר האם הבקשה התקבלה.
  bool requestImmediateTeardown(String pluginId) {
    if (!_idleTracked.contains(pluginId)) return false;
    _idleTimers.remove(pluginId)?.cancel();
    // השהיה קצרה — שתשובת ה-RPC תספיק לחזור לתוסף לפני השמדת ה-WebView.
    Timer(const Duration(milliseconds: 300), () {
      if (!_idleTracked.contains(pluginId)) return;
      // עבודה חדשה החלה בינתיים (RPC פתוח או אירועים בתור) — לא קוטעים;
      // חוזרים לשעון הרגיל.
      if ((_busyCounts[pluginId] ?? 0) > 0 ||
          _pending[pluginId]?.isNotEmpty == true) {
        _restartIdleTimer(pluginId);
        return;
      }
      backgroundDeactivator?.call(pluginId);
    });
    return true;
  }

  /// האם המופע של [pluginId] בתהליך הרמה (הופעל אך טרם סיים boot).
  bool isBootPending(String pluginId) => _activating.contains(pluginId);

  /// אירוע ממוקד שהגיע בזמן שהמופע עוד עולה — נכנס לתור וימסר אחרי ה-boot.
  /// שליחה ישירה ב-evaluateJavascript לפני שה-SDK נטען הייתה נבלעת בשקט.
  bool queueIfBootPending(
    String pluginId,
    String topic,
    Map<String, dynamic> payload,
  ) {
    if (!isBootPending(pluginId)) return false;
    final list = _pending.putIfAbsent(pluginId, () => []);
    if (list.length >= _maxPendingPerPlugin) list.removeAt(0);
    list.add((topic: topic, payload: payload));
    return true;
  }

  /// מסמן שמופע הרקע של [pluginId] הוער עצל — נקרא ע"י ה-host בעת הפעלה
  /// לפי דרישה. שעון הכיבוי מתחיל לרוץ רק אחרי שה-boot הסתיים.
  void trackIdleTeardown(String pluginId) {
    _idleTracked.add(pluginId);
  }

  /// פעילות של המופע (RPC מהתוסף או אירוע שנמסר אליו) — מאפסת את השעון.
  void notifyActivity(String pluginId) {
    if (!_idleTracked.contains(pluginId)) return;
    _restartIdleTimer(pluginId);
  }

  /// תחילת RPC של התוסף — המופע "עסוק" ולא יכובה עד [endWork] התואם.
  void beginWork(String pluginId) {
    _busyCounts[pluginId] = (_busyCounts[pluginId] ?? 0) + 1;
    notifyActivity(pluginId);
  }

  /// סיום RPC — משוחרר מונה העסוקים ושעון הכיבוי מתחיל מחדש.
  void endWork(String pluginId) {
    final count = (_busyCounts[pluginId] ?? 1) - 1;
    if (count <= 0) {
      _busyCounts.remove(pluginId);
    } else {
      _busyCounts[pluginId] = count;
    }
    notifyActivity(pluginId);
  }

  void _restartIdleTimer(String pluginId) {
    _idleTimers.remove(pluginId)?.cancel();
    _idleTimers[pluginId] = Timer(idleDelayOverride ?? idleTeardownDelay, () {
      _idleTimers.remove(pluginId);
      if (!_idleTracked.contains(pluginId)) return;
      // RPC עדיין רץ — לא קוטעים; ננסה שוב בפקיעה הבאה.
      if ((_busyCounts[pluginId] ?? 0) > 0) {
        _restartIdleTimer(pluginId);
        return;
      }
      backgroundDeactivator?.call(pluginId);
    });
  }

  void _stopIdleTracking(String pluginId) {
    _idleTracked.remove(pluginId);
    _idleTimers.remove(pluginId)?.cancel();
  }

  /// אירוע ממוקד (לחיצת פקד/תפריט) לתוסף בלי מנוע חי. מחזיר true אם התוסף
  /// ניתן להערה והאירוע נכנס לתור; false אומר לקורא שהאירוע אבד.
  bool queueTargetedEvent(
    String pluginId,
    String topic,
    Map<String, dynamic> payload,
  ) {
    if (!_activatable.contains(pluginId)) return false;
    final list = _pending.putIfAbsent(pluginId, () => []);
    if (list.length >= _maxPendingPerPlugin) list.removeAt(0);
    list.add((topic: topic, payload: payload));
    _activate(pluginId);
    return true;
  }

  /// אירוע שידור — מעיר כל תוסף שהצהיר על הנושא ב-activationEvents ואין לו
  /// כרגע מופע שמסוגל לקבל אותו.
  void onBroadcast(
    String topic,
    Map<String, dynamic> payload, {
    required bool Function(String pluginId) hasUsableInstance,
  }) {
    for (final entry in _broadcastTopics.entries) {
      if (!entry.value.contains(topic)) continue;
      if (hasUsableInstance(entry.key)) continue;
      queueTargetedEvent(entry.key, topic, payload);
    }
  }

  void _activate(String pluginId) {
    if (_activating.contains(pluginId)) return;
    final activator = backgroundActivator;
    if (activator == null) return;
    _activating.add(pluginId);
    unawaited(
      activator(pluginId).catchError((Object e) {
        _activating.remove(pluginId);
        _pending.remove(pluginId);
        debugPrint(
          'PluginLazyActivationService: activation failed '
          'for $pluginId: $e',
        );
      }),
    );
  }

  /// נקרא ע"י ה-runner של מופע הרקע אחרי שה-boot הסתיים — מוסר את
  /// האירועים הממתינים בסדרם.
  Future<void> onBackgroundInstanceReady(String pluginId) async {
    _activating.remove(pluginId);
    if (_idleTracked.contains(pluginId)) _restartIdleTimer(pluginId);
    final pending = _pending.remove(pluginId);
    if (pending == null) return;
    for (final event in pending) {
      final deliver = deliverOverride;
      if (deliver != null) {
        await deliver(pluginId, event.topic, event.payload);
      } else {
        await PluginRuntimeDispatcher.instance.dispatchEventToPlugin(
          pluginId,
          event.topic,
          event.payload,
          preferBackground: true,
        );
      }
    }
  }

  void onBackgroundInstanceClosed(String pluginId) {
    _activating.remove(pluginId);
    // המופע נסגר — עוצרים את השעון בלי לגעת ביכולת ההערה: הטריגר הבא
    // יעיר את התוסף מחדש ויירשם למעקב שוב דרך ה-host.
    _idleTracked.remove(pluginId);
    _idleTimers.remove(pluginId)?.cancel();
    _busyCounts.remove(pluginId);
  }
}
