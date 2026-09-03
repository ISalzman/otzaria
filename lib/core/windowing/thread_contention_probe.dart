import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/windowing/window_bus.dart';

/// מודד את תחרות ה-thread בין חלונות — **בדיקה 10 של P-2**.
///
/// ## למה זו הבדיקה החשובה ביותר שנשארה פתוחה
///
/// ההכרעה במודל A נשענה על thread ייעודי לכל מנוע: נמדד 102ms השהיה מול
/// 2,092ms ב-thread משותף, פי 20. **המימוש לא הצליח לספק את התנאי** —
/// יצירת מנוע על thread ייעודי קורסת ברגע שהחלון הראשון רץ — ולכן התוכנה
/// רצה בתצורת הבקרה, זו של 2,092ms.
///
/// בדיקה 10 הוגדרה כקריטריון עצירה, והמימוש הפך אותה ללא-רלוונטית לפני
/// שהיא הורצה. הבדיקה עצמה אינה משהו שסוויטת בדיקות יכולה לענות עליו: היא
/// דורשת **שני חלונות חיים** ומדידה בזמן ריצה. הקוד הזה הופך אותה מספייק
/// שצריך לכתוב למשהו שרץ בפקודה אחת.
///
/// ## מה נמדד, ולמה לא "זמן פריים"
///
/// מפת הדרכים כתבה "p95 זמן פריים בחלון סרק". חלון Flutter בסרק **אינו
/// מייצר פריימים** — אין אנימציה, ולכן אין timings לאסוף, ו-p95 יהיה
/// מוגדר על קבוצה ריקה. מה שהספייק המקורי מדד בפועל הוא **פער בין
/// תקתוקי טיימר**, וזה גם המספר שאיתו 102ms ו-2,092ms ניתנים להשוואה.
///
/// לכן: טיימר של 16ms, ומודדים את הפער בפועל בין תקתוקים. שני שלבים —
/// בסיס, ואז בזמן שהחלון האחר עסוק — והיחס ביניהם הוא התשובה.
///
/// ## איך מריצים
///
/// ```
/// set OTZARIA_MEASURE_CONTENTION=1
/// build\windows\x64\runner\Debug\otzaria.exe
/// ```
///
/// ואז לפתוח חלון שני ("העבר לחלון חדש"). המדידה רצה **בחלון המשני**,
/// שולחת לחלון הראשון בקשה לשרוף CPU, ומדפיסה טבלה. אפשר גם לשלב עם
/// `OTZARIA_DEBUG_OPEN_WINDOW_MS` כדי לקבל את הכול בלי נגיעה בעכבר.
class ThreadContentionProbe {
  ThreadContentionProbe._();

  /// סוג הבקשה באפיק: "שרוף CPU סינכרוני למשך N מילישניות".
  ///
  /// ⚠️ מטופל **רק** כשמשתנה הסביבה דלוק. בקשה שמקפיאה חלון אחר היא
  /// בדיוק מה שאסור שיהיה נגיש בבנייה רגילה.
  static const String requestBurn = 'contentionBurn';

  /// האם המדידה מופעלת.
  static bool get isEnabled =>
      Platform.environment['OTZARIA_MEASURE_CONTENTION'] == '1';

  /// קצב הטיימר. 16ms הוא פריים ב-60Hz — הקצב שבו הפער נעשה מורגש.
  static const Duration _tick = Duration(milliseconds: 16);

  /// אורך כל שלב. שתי שניות הן מה שהספייק שרף, וזה גם מה שנדרש כדי
  /// שהתפלגות של ~125 מדידות תהיה בעלת משמעות.
  static const Duration _phase = Duration(seconds: 2);

  /// הסף שמפת הדרכים קבעה כקריטריון עצירה.
  static const double _failRatio = 2.0;

  /// שורף CPU **סינכרוני** למשך [ms].
  ///
  /// ⚠️ סינכרוני במכוון, ובלי `await`: `Future.delayed` בלולאה היה משחרר
  /// את ה-thread בין איטרציות, כלומר מודד בדיוק את מה שלא שובר. מה
  /// שמקפיא חלון אחר הוא קוד Dart שאינו מוותר על ה-thread.
  static void burnCpu(int ms) {
    final until = DateTime.now().add(Duration(milliseconds: ms));
    var sink = 0;
    while (DateTime.now().isBefore(until)) {
      // חישוב שהמהדר אינו יכול להשמיט.
      for (var i = 0; i < 100000; i++) {
        sink = (sink + i) % 1000003;
      }
    }
    debugPrint('[contention] burned ${ms}ms (sink=$sink)');
  }

  /// מריץ את שני השלבים ומדפיס את התוצאה.
  ///
  /// מחזיר את היחס בין השלב העסוק לבסיס, או null אם לא היה למי לשלוח.
  static Future<double?> run() async {
    final peers = await WindowBus.instance.peers();
    if (peers.isEmpty) {
      stdout.writeln(
        '[contention] אין חלון אחר. פתח חלון שני והמדידה תרוץ ממנו.',
      );
      return null;
    }
    final target = peers.first.slot;

    stdout.writeln('[contention] שלב 1/2 — בסיס, אף חלון אינו עסוק');
    final baseline = await _measure();

    stdout.writeln('[contention] שלב 2/2 — חלון $target שורף CPU');
    // ⚠️ בלי המתנה לתשובה: הבקשה **חוסמת** את היעד, ולכן התשובה תגיע רק
    // אחרי שהשריפה נגמרה — כלומר המתנה לה הייתה מפספסת את כל המדידה.
    unawaited(
      WindowBus.instance.request(target, {
        'type': requestBurn,
        'ms': _phase.inMilliseconds,
      }, timeout: _phase * 3),
    );
    final contended = await _measure();

    final ratio = contended.p95 / baseline.p95;
    _report(baseline, contended, ratio);
    return ratio;
  }

  static Future<_Gaps> _measure() async {
    final gaps = <int>[];
    var last = DateTime.now();
    final timer = Timer.periodic(_tick, (_) {
      final now = DateTime.now();
      gaps.add(now.difference(last).inMicroseconds);
      last = now;
    });
    await Future<void>.delayed(_phase);
    timer.cancel();
    return _Gaps(gaps);
  }

  static void _report(_Gaps baseline, _Gaps contended, double ratio) {
    String ms(int micros) => (micros / 1000).toStringAsFixed(1).padLeft(8);
    final verdict = ratio > _failRatio
        ? 'נכשלה — ההרעה גדולה מפי ${_failRatio.toStringAsFixed(0)}'
        : 'עברה';

    stdout.writeln('''

┌─ P-2 בדיקה 10 — תחרות thread ─────────────────────────────
│  קצב הטיימר: ${_tick.inMilliseconds}ms · אורך שלב: ${_phase.inSeconds}s
│
│                  p50        p95        max      דגימות
│  בסיס       ${ms(baseline.p50)}   ${ms(baseline.p95)}   ${ms(baseline.max)}   ${baseline.count.toString().padLeft(7)}
│  חלון עסוק  ${ms(contended.p50)}   ${ms(contended.p95)}   ${ms(contended.max)}   ${contended.count.toString().padLeft(7)}
│
│  יחס p95: ×${ratio.toStringAsFixed(1)}
│  $verdict
└────────────────────────────────────────────────────────────
''');

    if (ratio > _failRatio) {
      stdout.writeln(
        '[contention] שתי הדרכים שלא נבדקו: יצירה על ה-thread הראשי ואז\n'
        '             העברת בעלות ל-thread ייעודי, או RunOnSeparateThread —\n'
        '             שעובד אך המנוע מכריז שיוסר. ראו docs/multi-window-handoff.md §5.',
      );
    }
  }
}

@immutable
class _Gaps {
  _Gaps(List<int> raw) : _sorted = List<int>.of(raw)..sort();

  final List<int> _sorted;

  int get count => _sorted.length;
  int get p50 => _at(0.50);
  int get p95 => _at(0.95);
  int get max => _sorted.isEmpty ? 0 : _sorted.last;

  int _at(double q) {
    if (_sorted.isEmpty) return 0;
    final index = ((_sorted.length - 1) * q).round();
    return _sorted[index];
  }
}
