import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/core/windowing/window_role.dart';

/// קריאה וכתיבה של רשימות משותפות בין חלונות — היסטוריה, סימניות,
/// שולחנות עבודה והערות.
///
/// ## המודל: בעלים יחיד
///
/// `hive_ce` נועל את קובצי ה-`.lock` בלעדית, והנעילה היא פר-handle — שני
/// חלונות באותו תהליך נכשלים בדיוק כמו שני תהליכים. לכן אי אפשר לפתוח את
/// אותו box פעמיים, ו"שיתוף" חייב להיות ניתוב אל מי שכן פתח אותו.
///
/// **הבעלים הוא החלון הראשון**, כי קובצי ה-Hive שלו הם אלה שבשורש הנתונים
/// האמיתי. חלונות משניים קוראים וכותבים דרכו.
///
/// ## מה קורה כשהבעלים נסגר
///
/// חלון משני נופל למאגר המקומי שלו, שנזרע בפתיחה מהבעלים. התוצאה מפסיקה
/// להסתנכרן — אבל היא **אינה ריקה**, וזה ההבדל שחשוב: משתמש שסגר את
/// החלון הראשון יראה את ההיסטוריה כפי שהייתה, ולא מסך ריק שנראה כמו
/// אובדן נתונים.
class SharedListStore {
  SharedListStore._();

  static final SharedListStore instance = SharedListStore._();

  /// סוגי הבקשות באפיק.
  static const String requestRead = 'sharedListRead';
  static const String requestWrite = 'sharedListWrite';

  /// המאגרים שמנותבים לבעלים. שאר ה-boxes נשארים מקומיים לחלון.
  ///
  /// ⚠️ `tabs` **אינו** ברשימה במכוון: הכרטיסיות הפתוחות הן מצב פר-חלון,
  /// וניתובן לבעלים היה גורם לכל החלונות להציג את אותן כרטיסיות.
  static const Set<String> sharedBoxes = {
    'history',
    'bookmarks',
    'workspaces',
    'notes',
  };

  static bool isShared(String boxName) => sharedBoxes.contains(boxName);

  /// המשבצת של הבעלים, אם הוא עונה.
  int? _ownerSlot;

  /// מאתר את הבעלים ושומר את התוצאה.
  ///
  /// הבעלים מזהה את עצמו בתשובה ל-`describe`; אין הנחה שהוא במשבצת 1, כי
  /// סדר תפיסת המשבצות תלוי בסדר הפתיחה ולא בתפקיד.
  Future<int?> _findOwner() async {
    final cached = _ownerSlot;
    if (cached != null) return cached;
    final peers = await WindowBus.instance.peers();
    for (final peer in peers) {
      if (peer.isOwner) {
        _ownerSlot = peer.slot;
        return peer.slot;
      }
    }
    return null;
  }

  /// מאפס את זיהוי הבעלים. נקרא כשבקשה נכשלה — ייתכן שהוא נסגר.
  void _forgetOwner() => _ownerSlot = null;

  Box<dynamic> _localBox(String boxName) => Hive.box<dynamic>(boxName);

  /// קורא את הרשימה הגולמית.
  Future<List<dynamic>> read(String boxName, String key) async {
    if (!WindowRole.isSecondary || !isShared(boxName)) {
      return _readLocal(boxName, key);
    }
    final owner = await _findOwner();
    if (owner != null) {
      final result = await WindowBus.instance.request(owner, {
        'type': requestRead,
        'box': boxName,
        'key': key,
      });
      if (result is List) return result;
      _forgetOwner();
    }
    // הבעלים נסגר או לא ענה — המאגר המקומי, שנזרע בפתיחה, עדיף על ריק.
    debugPrint('SharedListStore: owner unavailable, reading local $boxName');
    return _readLocal(boxName, key);
  }

  List<dynamic> _readLocal(String boxName, String key) {
    try {
      return _localBox(boxName).get(key, defaultValue: <dynamic>[])
          as List<dynamic>;
    } catch (e) {
      debugPrint('SharedListStore: local read of $boxName/$key failed: $e');
      return const [];
    }
  }

  /// כותב את הרשימה הגולמית.
  ///
  /// ⚠️ בחלון משני הכתיבה הולכת לבעלים **וגם** למאגר המקומי. הכפילות
  /// מכוונת: המקומי הוא העותק שיישאר אם הבעלים ייסגר, ובלעדיו סגירת
  /// החלון הראשון הייתה מאבדת את מה שנכתב מהחלון המשני.
  Future<void> write(String boxName, String key, List<dynamic> value) async {
    if (!WindowRole.isSecondary || !isShared(boxName)) {
      await _writeLocal(boxName, key, value);
      return;
    }
    final owner = await _findOwner();
    if (owner != null) {
      final ok = await WindowBus.instance.request(owner, {
        'type': requestWrite,
        'box': boxName,
        'key': key,
        'value': value,
      });
      if (ok != true) {
        _forgetOwner();
        debugPrint('SharedListStore: write to owner failed for $boxName');
      }
    }
    await _writeLocal(boxName, key, value);
  }

  Future<void> _writeLocal(
    String boxName,
    String key,
    List<dynamic> value,
  ) async {
    try {
      await _localBox(boxName).put(key, value);
    } catch (e) {
      debugPrint('SharedListStore: local write of $boxName/$key failed: $e');
    }
  }

  /// מטפל בבקשה שהגיעה מחלון אחר. מוחזר null כשהבקשה אינה שלנו.
  Future<Object?> handleRequest(Map<String, dynamic> request) async {
    final boxName = request['box'];
    final key = request['key'];
    if (boxName is! String || key is! String) return null;
    switch (request['type']) {
      case requestRead:
        return _readLocal(boxName, key);
      case requestWrite:
        final value = request['value'];
        if (value is! List) return false;
        await _writeLocal(boxName, key, value);
        return true;
      default:
        return null;
    }
  }
}
