import 'package:flutter/widgets.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// מטא-דאטה לתצוגה של כלי מובנה ב-Settings (טבלת ניהול הכלים).
///
/// אינו כולל את [pageBuilder] של ה-`BuiltInToolDescriptor` המלא — רק מזהה,
/// תווית, סדר, ואייקון לתצוגה.
class BuiltInToolMeta {
  final String toolId;
  final String label;
  final int order;

  /// אייקון Fluent (אם זה כלי שמשתמש באייקון מתוך החבילה).
  final IconData? icon;

  /// נתיב נכס תמונה (לכלים שמשתמשים בתמונה במקום באייקון, כמו "שמור וזכור").
  final String? imageIcon;

  const BuiltInToolMeta({
    required this.toolId,
    required this.label,
    required this.order,
    this.icon,
    this.imageIcon,
  });
}

/// קטלוג הכלים המובנים — מקור סמכותי יחיד עבור ToolsScreen ומסך ההגדרות.
///
/// סדר הפריטים תואם לסדר ב-[ToolsScreenState._buildAllBuiltInDescriptors];
/// כל שינוי כאן חייב להתעדכן גם שם (או להפך).
const List<BuiltInToolMeta> kBuiltInToolsCatalog = [
  BuiltInToolMeta(
    toolId: 'builtin.calendar',
    label: 'לוח שנה',
    order: 10,
    icon: FluentIcons.calendar_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.shamor_zachor',
    label: 'שמור וזכור',
    order: 20,
    imageIcon: 'assets/icon/שמור וזכור שחור ריק.png',
  ),
  BuiltInToolMeta(
    toolId: 'builtin.measurements',
    label: 'מדות ושיעורים',
    order: 30,
    icon: FluentIcons.ruler_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.notes',
    label: 'הערות אישיות',
    order: 40,
    icon: FluentIcons.note_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.gematria',
    label: 'גימטריה',
    order: 50,
    icon: FluentIcons.calculator_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.aramaic_dictionary',
    label: 'מילון ארמי-עברי',
    order: 60,
    icon: FluentIcons.translate_24_regular,
  ),
  BuiltInToolMeta(
    toolId: 'builtin.acronyms_dictionary',
    label: 'ראשי תיבות',
    order: 70,
    icon: FluentIcons.text_quote_24_regular,
  ),
];
