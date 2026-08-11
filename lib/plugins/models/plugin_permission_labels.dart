import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_startup_contributions.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';

/// מידע תצוגה עבור הרשאת תוסף — שם עברי ותיאור קצר
class PluginPermissionInfo {
  /// שם קצר בעברית (מוצג כותרת)
  final String label;

  /// תיאור מה ההרשאה מאפשרת (מוצג כsubtitle)
  final String description;

  const PluginPermissionInfo({required this.label, required this.description});
}

/// מחזיר מידע תצוגה עבור הרשאה בשמה הטכני.
/// אם ההרשאה אינה מוכרת, מחזיר את שמה הטכני עם תיאור גנרי.
PluginPermissionInfo getPermissionInfo(
  String permissionKey, {
  PluginManifest? manifest,
}) {
  if (permissionKey == pluginRunOnStartupPermission && manifest != null) {
    final startup = manifest.startup;
    if (startup != null && !startup.isEmpty) {
      if (!startup.hasBackgroundActivationTrigger) {
        return const PluginPermissionInfo(
          label: 'הפעלה ברקע לפי אירוע',
          description:
              'לא הוגדר אירוע שמפעיל מנוע רקע, ולכן הרשאה זו אינה בשימוש '
              'בגרסה הנוכחית של התוסף.',
        );
      }
      final reasons = pluginBackgroundActivationReasons(manifest).join(', ');
      return PluginPermissionInfo(
        label: 'הפעלה ברקע לפי אירוע',
        description:
            'התוסף יפעיל מנוע WebView ברקע כאשר: $reasons. המנוע יכובה אחרי '
            '3 דקות ללא פעילות, אלא אם תאושר גם מניעת הכיבוי.',
      );
    }
  }
  return _permissionLabels[permissionKey] ??
      PluginPermissionInfo(
        label: permissionKey,
        description: 'גישה לפונקציונליות: $permissionKey',
      );
}

/// מחזיר תיאור ידידותי של האירועים שעשויים להפעיל את מנוע התוסף ברקע.
List<String> pluginBackgroundActivationReasons(PluginManifest manifest) {
  final startup = manifest.startup;
  if (startup == null || startup.isEmpty) return const ['עליית אוצריא'];

  final reasons = <String>{};
  if (startup.toolbarItems.any(_toolbarItemActivatesBackground)) {
    reasons.add('לחיצה על פקד בשורת העיון');
  }
  if (startup.contextMenuItems.any(_contextMenuItemActivatesBackground)) {
    reasons.add('לחיצה על פריט בתפריט הטקסט');
  }
  for (final topic in startup.activationEvents) {
    if (topic == PluginStartupContributions.startupActivationTopic) {
      reasons.add('עליית אוצריא');
      continue;
    }
    reasons.add(
      _permissionLabels['events.subscribe:$topic']?.label ?? 'האירוע $topic',
    );
  }
  return List.unmodifiable(reasons);
}

bool _toolbarItemActivatesBackground(Map<String, dynamic> item) =>
    PluginStartupContributions(
      toolbarItems: [
        item,
      ],
    ).hasBackgroundActivationTrigger;

bool _contextMenuItemActivatesBackground(Map<String, dynamic> item) =>
    PluginStartupContributions(
      contextMenuItems: [
        item,
      ],
    ).hasBackgroundActivationTrigger;

/// האם הרשאה מתחילה מאושרת במסך ההתקנה.
bool pluginPermissionDefaultGrant(
  String permission, {
  required bool isOfflineMode,
}) {
  if (permission == pluginRunOnStartupPermission ||
      permission == pluginStartupContributionsPermission ||
      permission == pluginBackgroundKeepAlivePermission) {
    return false;
  }
  return !(isOfflineMode && permission == pluginNetworkAccessPermission);
}

/// מסדר הרשאות רגישות לפני שאר הרשאות המניפסט.
List<String> orderedPluginPermissions(
  List<String> permissions, {
  required bool isOfflineMode,
}) {
  int rank(String permission) => switch (permission) {
    pluginRunOnStartupPermission => 0,
    pluginStartupContributionsPermission => 1,
    pluginBackgroundKeepAlivePermission => 2,
    pluginNetworkAccessPermission when isOfflineMode => 3,
    _ => 4,
  };
  final indexed = permissions.indexed.toList();
  indexed.sort((a, b) {
    final rankComparison = rank(a.$2).compareTo(rank(b.$2));
    return rankComparison != 0 ? rankComparison : a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

/// מיפוי מלא של כל ההרשאות התקפות לשם ותיאור בעברית
const Map<String, PluginPermissionInfo> _permissionLabels = {
  // ===== מידע על האפליקציה =====
  'app.info.read': PluginPermissionInfo(
    label: 'מידע אפליקציה',
    description: 'קריאת מידע כללי על האפליקציה: גרסה, פלטפורמה, ערכת נושא',
  ),
  'app.user_email.read': PluginPermissionInfo(
    label: 'כתובת מייל',
    description: 'גישה לכתובת המייל של המשתמש, לשימוש בדיווח שגיאות בלבד',
  ),
  'app.open_url': PluginPermissionInfo(
    label: 'פתיחת קישורים בדפדפן',
    description:
        'פתיחת כתובות אינטרנט (http/https) בדפדפן ברירת המחדל של מערכת ההפעלה',
  ),
  'app.run_on_startup': PluginPermissionInfo(
    label: 'טעינה אוטומטית ברקע',
    description:
        'תוסף מדור קודם ייטען עם עליית אוצריא ויישאר פעיל כל עוד התוכנה פתוחה.',
  ),
  'app.background_keep_alive': PluginPermissionInfo(
    label: 'מניעת כיבוי מנוע הרקע',
    description:
        'התוסף מבקש להשאיר את מנוע ה-WebView פעיל ללא הגבלת זמן. הדבר מגדיל '
        'את צריכת הזיכרון והמעבד; אשר רק לתוסף מהימן שחייב להאזין ברציפות.',
  ),
  'app.startup_contributions': PluginPermissionInfo(
    label: 'הוספת רכיבים לתוכנה',
    description:
        'מאפשר לתוסף להוסיף פקדים, פריטי תפריט ונתונים שמנוהלים בידי אוצריא. '
        'פעולות מובנות עשויות להתבצע בלי לפתוח את דף התוסף.',
  ),

  // ===== ספרייה =====
  'library.books.read': PluginPermissionInfo(
    label: 'רשימת ספרים',
    description: 'חיפוש וצפייה ברשימת כל הספרים בספרייה',
  ),
  'library.content.read': PluginPermissionInfo(
    label: 'תוכן ספרים',
    description: 'קריאת תוכן הספרים מהספרייה',
  ),

  // ===== חיפוש =====
  'search.fulltext.read': PluginPermissionInfo(
    label: 'חיפוש טקסט מלא',
    description: 'ביצוע חיפושי טקסט ברחבי כל הספרייה',
  ),

  // ===== קורא =====
  'reader.open': PluginPermissionInfo(
    label: 'פתיחת ספרים',
    description: 'פתיחת ספרים בקורא האפליקציה',
  ),

  // ===== ניווט =====
  'navigation.write': PluginPermissionInfo(
    label: 'ניווט במסכים',
    description: 'מעבר בין מסכים שונים באפליקציה',
  ),

  // ===== הערות אישיות =====
  'notes.read': PluginPermissionInfo(
    label: 'צפייה בהערות',
    description: 'קריאה וצפייה בהערות האישיות שלך',
  ),
  'notes.write': PluginPermissionInfo(
    label: 'עריכת הערות',
    description: 'יצירה, עריכה ומחיקה של הערות אישיות',
  ),

  // ===== לוח שנה =====
  'calendar.read': PluginPermissionInfo(
    label: 'לוח שנה עברי',
    description: 'גישה ללוח השנה העברי, זמנים הלכתיים ואירועים',
  ),

  // ===== הגדרות =====
  'settings.read': PluginPermissionInfo(
    label: 'הגדרות האפליקציה',
    description: 'קריאת הגדרות האפליקציה (רק הגדרות שאושרו לתוספים)',
  ),

  // ===== ממשק משתמש =====
  'ui.feedback': PluginPermissionInfo(
    label: 'הודעות ודיאלוגים',
    description: 'הצגת הודעות, דיאלוגים ועדכונים בממשק המשתמש',
  ),
  'ui.create_shortcut': PluginPermissionInfo(
    label: 'יצירת קיצור דרך',
    description: 'יצירת קיצור דרך בשולחן העבודה או בתפריט ההתחל (לאחר אישור)',
  ),

  // ===== אחסון תוסף =====
  'plugin.storage.read': PluginPermissionInfo(
    label: 'אחסון מקומי — קריאה',
    description: 'קריאת נתונים שהתוסף שמר בעבר על המכשיר',
  ),
  'plugin.storage.write': PluginPermissionInfo(
    label: 'אחסון מקומי — כתיבה',
    description: 'שמירת נתוני התוסף על המכשיר',
  ),

  // ===== פרסום נתונים =====
  'published_data.write': PluginPermissionInfo(
    label: 'שיתוף נתונים עם האפליקציה',
    description:
        'פרסום נתונים מהתוסף לחלקים אחרים באפליקציה (כגון אירועי לוח שנה)',
  ),

  // ===== רשת =====
  'network.access': PluginPermissionInfo(
    label: 'גישה לאינטרנט',
    description: 'שליחה וקבלה של מידע מרשת האינטרנט',
  ),
  'network.localhost': PluginPermissionInfo(
    label: 'גישה לשירותים מקומיים',
    description:
        'התחברות לשירותים שרצים על המחשב שלך (localhost), כגון מודל שפה מקומי (Ollama / LM Studio). אינה מאפשרת גישה לאינטרנט.',
  ),

  // ===== משוב ומיילים =====
  'feedback.send_email': PluginPermissionInfo(
    label: 'שליחת מייל',
    description: 'שליחת משוב ודיווחים לכתובת מייל שהתוסף מגדיר',
  ),

  // ===== היסטוריית קריאה =====
  'history.read': PluginPermissionInfo(
    label: 'היסטוריית קריאה — צפייה',
    description: 'צפייה בהיסטוריית הקריאה והחיפושים שלך',
  ),
  'history.write': PluginPermissionInfo(
    label: 'היסטוריית קריאה — עריכה',
    description: 'מחיקה ועריכה של היסטוריית הקריאה',
  ),

  // ===== מסד נתונים =====
  'database.read': PluginPermissionInfo(
    label: 'קריאת מסד נתונים',
    description: 'קריאת נתונים ממקורות SQLite שהאפליקציה מאשרת לתוסף',
  ),

  // ===== התראות =====
  'notifications.send': PluginPermissionInfo(
    label: 'הודעות מובנות',
    description: 'הצגת הודעות פופ-אפ בתוך האפליקציה',
  ),
  'notifications.system': PluginPermissionInfo(
    label: 'התראות מערכת',
    description: 'שליחת התראות למערכת ההפעלה (גם כשהאפליקציה סגורה)',
  ),

  // ===== אירועים =====
  'events.subscribe:navigation.changed': PluginPermissionInfo(
    label: 'אירועי ניווט',
    description: 'קבלת עדכון בכל פעם שמשתמש עובר בין מסכים',
  ),
  'events.subscribe:reader.current_book_changed': PluginPermissionInfo(
    label: 'אירועי פתיחת ספר',
    description: 'קבלת עדכון בכל פעם שנפתח ספר חדש בקורא',
  ),
  'events.subscribe:reader.current_ref_changed': PluginPermissionInfo(
    label: 'אירועי שינוי מיקום',
    description: 'קבלת עדכון בכל פעם שמיקום הקריאה משתנה (דף, פרק, סעיף)',
  ),
  'events.subscribe:theme.changed': PluginPermissionInfo(
    label: 'אירועי ערכת נושא',
    description: 'קבלת עדכון בכל פעם שמשתמש מחליף ערכת נושא',
  ),
  'events.subscribe:settings.changed': PluginPermissionInfo(
    label: 'אירועי הגדרות',
    description: 'קבלת עדכון בכל פעם שמשתמש משנה הגדרה',
  ),
  'events.subscribe:calendar.date_changed': PluginPermissionInfo(
    label: 'אירועי שינוי תאריך',
    description: 'קבלת עדכון בכל פעם שמשתמש מחליף תאריך בלוח השנה',
  ),
  'events.subscribe:workspace.changed': PluginPermissionInfo(
    label: 'אירועי סביבת עבודה',
    description: 'קבלת עדכון בכל פעם שמשתמש מחליף סביבת עבודה',
  ),
  'events.subscribe:plugin.permissions_changed': PluginPermissionInfo(
    label: 'אירועי שינוי הרשאות',
    description: 'קבלת עדכון בכל פעם שהרשאות התוסף משתנות',
  ),
  'events.subscribe:reader.sectionContentChanged': PluginPermissionInfo(
    label: 'אירועי שינוי תוכן בקורא',
    description: 'קבלת עדכון כאשר נוסח של סעיף או אופן ההצגה שלו משתנים בקורא',
  ),
  'events.subscribe:reader.selection_changed': PluginPermissionInfo(
    label: 'אירועי סימון טקסט',
    description: 'קבלת עדכון בכל פעם שהטקסט המסומן בקורא משתנה',
  ),
};
