/// תרומות עלייה דקלרטיביות של תוסף (`contributes.startup` במניפסט).
///
/// נקראות ומופעלות ע"י Flutter בעליית התוכנה בלי להרים מנוע JS — בניגוד
/// ל-`app.run_on_startup` שמריץ WebView נסתר. דורשות את ההרשאה
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

  /// נושאי אירועים שמעירים את מופע הרקע של התוסף בעצלנות (בלי מנוע חי
  /// עד שאירוע כזה קורה בפועל), או [startupActivationTopic].
  final List<String> activationEvents;

  const PluginStartupContributions({
    this.toolbarItems = const [],
    this.contextMenuItems = const [],
    this.publishedData = const [],
    this.activationEvents = const [],
  });

  bool get isEmpty =>
      toolbarItems.isEmpty &&
      contextMenuItems.isEmpty &&
      publishedData.isEmpty &&
      activationEvents.isEmpty;

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
      activationEvents: events is List
          ? [
              for (final entry in events)
                if (entry is String) entry,
            ]
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (toolbarItems.isNotEmpty) 'toolbarItems': toolbarItems,
    if (contextMenuItems.isNotEmpty) 'contextMenuItems': contextMenuItems,
    if (publishedData.isNotEmpty) 'publishedData': publishedData,
    if (activationEvents.isNotEmpty) 'activationEvents': activationEvents,
  };
}
