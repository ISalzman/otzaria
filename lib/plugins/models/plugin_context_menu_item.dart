/// מודל המייצג פריט תפריט הקשר שנרשם על ידי פלאגין.
class PluginContextMenuItem {
  final String id;
  final String label;
  final String? icon;

  /// לחיצה על הפריט תפתח את דף התוסף, ואירוע הלחיצה יימסר לו לאחר הטעינה.
  final bool openPlugin;

  /// ערך חופשי שהתוסף מסר ברישום — מוחזר לו כלשונו ב-payload של אירוע הלחיצה.
  final Object? param;

  const PluginContextMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.openPlugin = false,
    this.param,
  });
}
