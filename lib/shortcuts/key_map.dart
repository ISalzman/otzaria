import 'package:flutter/services.dart';

/// מיפוי מרכזי בין שמות מקשים (מחרוזות) ל-[LogicalKeyboardKey].
///
/// משמש כמקור-האמת היחיד לכל ה-utils העוסקים בקיצורי מקשים:
/// - [ShortcutHelper.matchesShortcut] – ניתוח מחרוזת קיצור והשוואה לאירוע
/// - [ShortcutHelper.getKeyLabel]     – LogicalKeyboardKey → שם מחרוזת
/// - [ShortcutHelper.formatKeysToShortcut] – Set של LogicalKeyboardKey → מחרוזת
///
/// **הרחבה:** להוסיף מקש חדש יש לרשום אותו **כאן בלבד** –
/// כל שאר הקוד יקבל אוטומטית תמיכה בו (התאמה + תצוגה).
class KeyMap {
  KeyMap._();

  // ─── אותיות (א׳–ת׳ / a–z) ──────────────────────────────────────────────────
  // אותיות מטופלות בנפרד ב-ShortcutHelper לפי key.keyLabel, לא דרך המפה הזו.

  // ─── מקשי ספרות ──────────────────────────────────────────────────────────────
  static const Map<String, LogicalKeyboardKey> nameToKey = {
    '0': LogicalKeyboardKey.digit0,
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8,
    '9': LogicalKeyboardKey.digit9,

    // ─── סימנים ─────────────────────────────────────────────────────────────────
    'comma': LogicalKeyboardKey.comma,
    'period': LogicalKeyboardKey.period,
    'slash': LogicalKeyboardKey.slash,
    'backslash': LogicalKeyboardKey.backslash,
    'semicolon': LogicalKeyboardKey.semicolon,
    'quote': LogicalKeyboardKey.quote,
    'bracketleft': LogicalKeyboardKey.bracketLeft,
    'bracketright': LogicalKeyboardKey.bracketRight,
    'minus': LogicalKeyboardKey.minus,
    'equal': LogicalKeyboardKey.equal,
    'backquote': LogicalKeyboardKey.backquote,
    // מקש '+' כתו לוגי. נשמר בשם ולא בתו עצמו, כי '+' הוא המפריד בפורמט
    // הקיצורים ולכן 'ctrl++' אינו ניתן לניתוח חד-משמעי.
    'plus': LogicalKeyboardKey.add,

    // ─── לוח הספרות (numpad) ────────────────────────────────────────────────────
    'numpad0': LogicalKeyboardKey.numpad0,
    'numpad1': LogicalKeyboardKey.numpad1,
    'numpad2': LogicalKeyboardKey.numpad2,
    'numpad3': LogicalKeyboardKey.numpad3,
    'numpad4': LogicalKeyboardKey.numpad4,
    'numpad5': LogicalKeyboardKey.numpad5,
    'numpad6': LogicalKeyboardKey.numpad6,
    'numpad7': LogicalKeyboardKey.numpad7,
    'numpad8': LogicalKeyboardKey.numpad8,
    'numpad9': LogicalKeyboardKey.numpad9,
    'numpadadd': LogicalKeyboardKey.numpadAdd,
    'numpadsubtract': LogicalKeyboardKey.numpadSubtract,
    'numpadmultiply': LogicalKeyboardKey.numpadMultiply,
    'numpaddivide': LogicalKeyboardKey.numpadDivide,
    'numpaddecimal': LogicalKeyboardKey.numpadDecimal,
    'numpadenter': LogicalKeyboardKey.numpadEnter,

    // ─── מקשים מיוחדים ──────────────────────────────────────────────────────────
    'space': LogicalKeyboardKey.space,
    'tab': LogicalKeyboardKey.tab,
    'enter': LogicalKeyboardKey.enter,
    'backspace': LogicalKeyboardKey.backspace,
    'delete': LogicalKeyboardKey.delete,
    'escape': LogicalKeyboardKey.escape,
    'insert': LogicalKeyboardKey.insert,

    // ─── ניווט ──────────────────────────────────────────────────────────────────
    'arrowup': LogicalKeyboardKey.arrowUp,
    'arrowdown': LogicalKeyboardKey.arrowDown,
    'arrowleft': LogicalKeyboardKey.arrowLeft,
    'arrowright': LogicalKeyboardKey.arrowRight,
    'home': LogicalKeyboardKey.home,
    'end': LogicalKeyboardKey.end,
    'pageup': LogicalKeyboardKey.pageUp,
    'pagedown': LogicalKeyboardKey.pageDown,

    // ─── מקשי F ─────────────────────────────────────────────────────────────────
    'f1': LogicalKeyboardKey.f1,
    'f2': LogicalKeyboardKey.f2,
    'f3': LogicalKeyboardKey.f3,
    'f4': LogicalKeyboardKey.f4,
    'f5': LogicalKeyboardKey.f5,
    'f6': LogicalKeyboardKey.f6,
    'f7': LogicalKeyboardKey.f7,
    'f8': LogicalKeyboardKey.f8,
    'f9': LogicalKeyboardKey.f9,
    'f10': LogicalKeyboardKey.f10,
    'f11': LogicalKeyboardKey.f11,
    'f12': LogicalKeyboardKey.f12,
  };

  /// מיפוי הפוך: [LogicalKeyboardKey] → שם מחרוזת.
  /// נבנה אוטומטית מ-[nameToKey] – אין צורך לעדכן ידנית.
  static final Map<LogicalKeyboardKey, String> keyToName = {
    for (final e in nameToKey.entries) e.value: e.key,
  };

  /// מחזיר את שם המחרוזת של [key], או `null` אם אינו ברשימה.
  static String? labelFor(LogicalKeyboardKey key) => keyToName[key];

  /// מחזיר את [LogicalKeyboardKey] המתאים לשם [name] (case-insensitive),
  /// או `null` אם השם אינו מוכר.
  static LogicalKeyboardKey? keyFor(String name) =>
      nameToKey[name.toLowerCase()];

  /// המקשים המקבילים למקש בשורה הראשית — לוח הספרות, ומקש '+' הלוגי
  /// שחלק מהפריסות מדווחות עליו במקום `equal`.
  ///
  /// המיפוי חד-כיווני בכוונה: קיצור שהוגדר על השורה הראשית נתפס גם מהמקשים
  /// המקבילים, אבל קיצור שהוקלט במפורש על לוח הספרות נשאר ייחודי לו.
  static const Map<String, List<LogicalKeyboardKey>> _equivalentKeys = {
    '0': [LogicalKeyboardKey.numpad0],
    '1': [LogicalKeyboardKey.numpad1],
    '2': [LogicalKeyboardKey.numpad2],
    '3': [LogicalKeyboardKey.numpad3],
    '4': [LogicalKeyboardKey.numpad4],
    '5': [LogicalKeyboardKey.numpad5],
    '6': [LogicalKeyboardKey.numpad6],
    '7': [LogicalKeyboardKey.numpad7],
    '8': [LogicalKeyboardKey.numpad8],
    '9': [LogicalKeyboardKey.numpad9],
    'plus': [LogicalKeyboardKey.numpadAdd, LogicalKeyboardKey.equal],
    'equal': [LogicalKeyboardKey.numpadAdd, LogicalKeyboardKey.add],
    'minus': [LogicalKeyboardKey.numpadSubtract],
    'period': [LogicalKeyboardKey.numpadDecimal],
    'slash': [LogicalKeyboardKey.numpadDivide],
    'enter': [LogicalKeyboardKey.numpadEnter],
  };

  /// מחזיר את המקשים המקבילים ל-[name] (ריק אם אין כאלה).
  static List<LogicalKeyboardKey> equivalentKeysFor(String name) =>
      _equivalentKeys[name.toLowerCase()] ?? const [];
}
