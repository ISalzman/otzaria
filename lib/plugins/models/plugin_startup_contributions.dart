/// תרומות עלייה דקלרטיביות של תוסף (`contributes.startup` במניפסט).
///
/// נקראות ומופעלות ע"י Flutter בלי להרים מנוע JS. דורשות את ההרשאה
/// `app.startup_contributions`, וכל קטגוריה כפופה גם להרשאת התחום שלה
/// (`reader.toolbar` / `reader.context_menu` / `published_data.write`).
class PluginStartupContributions {
  /// נושא הפעלה מדומה ב-[activationEvents]: מרים את מופע הרקע של התוסף
  /// זמן קצר אחרי שעליית התוכנה הסתיימה (ולא כחלק ממנה).
  static const String startupActivationTopic = 'app.startup';

  /// פריטי שורת פקדים — באותה סכימה של `reader.addToolbarItem`.
  final List<Map<String, dynamic>> toolbarItems;

  /// פריטי תפריט הקשר — באותה סכימה של `reader.addContextMenuItem`.
  final List<Map<String, dynamic>> contextMenuItems;

  /// רשומות `publishedData` לזריעה: `{type, key, payload, scope?}`.
  /// המפתח נשמר עם קידומת `manifest:` — רשומות אלו בבעלות המניפסט.
  final List<Map<String, dynamic>> publishedData;

  /// תכניות חישוב שה-Host מריץ ללא מנוע JavaScript.
  final List<Map<String, dynamic>> programs;

  /// נושאי אירועים שמעירים את מופע הרקע של התוסף בעצלנות (בלי מנוע חי
  /// עד שאירוע כזה קורה בפועל), או [startupActivationTopic].
  final List<String> activationEvents;

  /// האם התוסף מבקש להשאיר מופע רקע עצל פעיל ללא כיבוי אוטומטי.
  /// הבקשה חלה רק אם המשתמש אישר את ההרשאה המתאימה.
  final bool keepAlive;

  const PluginStartupContributions({
    this.toolbarItems = const [],
    this.contextMenuItems = const [],
    this.publishedData = const [],
    this.programs = const [],
    this.activationEvents = const [],
    this.keepAlive = false,
  });

  bool get isEmpty =>
      toolbarItems.isEmpty &&
      contextMenuItems.isEmpty &&
      publishedData.isEmpty &&
      programs.isEmpty &&
      activationEvents.isEmpty;

  /// האם קיימת פעולה שבאמת עשויה להרים את מנוע הרקע.
  bool get hasBackgroundActivationTrigger =>
      activationEvents.isNotEmpty ||
      toolbarItems.any(_toolbarItemActivatesBackground) ||
      contextMenuItems.any(_contextMenuItemActivatesBackground);

  static bool _toolbarItemActivatesBackground(Map<String, dynamic> item) {
    if (item.containsKey('binding') ||
        item.containsKey('action') ||
        item.containsKey('childrenBinding')) {
      return false;
    }
    if (item['type'] == 'menu') {
      final children = item['children'];
      return children is List &&
          children.whereType<Map>().any(
            (child) => _toolbarItemActivatesBackground(
              Map<String, dynamic>.from(child),
            ),
          );
    }
    return item['openPlugin'] != true;
  }

  static bool _contextMenuItemActivatesBackground(
    Map<String, dynamic> item,
  ) {
    switch (item['type']) {
      case 'separator':
        return false;
      case 'submenu':
        final children = item['children'];
        return children is List &&
            children.whereType<Map>().any(
              (child) => _contextMenuItemActivatesBackground(
                Map<String, dynamic>.from(child),
              ),
            );
      case 'color-row':
        return true;
      default:
        return item['openPlugin'] != true;
    }
  }

  /// פרסינג סובלני: ערכים בטיפוס שגוי מדולגים ולא מפילים את טעינת המניפסט.
  /// הדיווח למפתח על טיפוס שגוי הוא באחריות ה-validator (אריזה/התקנה).
  factory PluginStartupContributions.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> mapList(String field) {
      final value = json[field];
      if (value is! List) return const [];
      return [
        for (final entry in value)
          if (entry is Map) Map<String, dynamic>.from(entry),
      ];
    }

    final events = json['activationEvents'];
    return PluginStartupContributions(
      toolbarItems: mapList('toolbarItems'),
      contextMenuItems: mapList('contextMenuItems'),
      publishedData: mapList('publishedData'),
      programs: mapList('programs'),
      activationEvents: events is List
          ? [
              for (final entry in events)
                if (entry is String) entry,
            ]
          : const [],
      keepAlive: json['keepAlive'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (toolbarItems.isNotEmpty) 'toolbarItems': toolbarItems,
    if (contextMenuItems.isNotEmpty) 'contextMenuItems': contextMenuItems,
    if (publishedData.isNotEmpty) 'publishedData': publishedData,
    if (programs.isNotEmpty) 'programs': programs,
    if (activationEvents.isNotEmpty) 'activationEvents': activationEvents,
    if (keepAlive) 'keepAlive': true,
  };
}
