/// קובע האם יש לשמור את הטקסט הנבחר כבחירה האחרונה.
///
/// בחירה ריקה יכולה להופיע רגעית אחרי לחיצה ימנית שפותחת תפריט הקשר,
/// ולכן אין לדרוס בגללה את הטקסט האחרון שהמשתמש סימן.
bool shouldPersistSelectedText(String? selectedText) {
  return selectedText != null && selectedText.trim().isNotEmpty;
}

/// מחזיר את הטקסט שצריך להישאר שמור עבור פעולות ההקשר.
///
/// כאשר [latestSelectedText] ריק או null, שומרים את [previousSelectedText]
/// כדי שלחיצה ימנית לא תמחק את הבחירה האחרונה.
String? resolvePersistedSelectedText({
  required String? previousSelectedText,
  required String? latestSelectedText,
}) {
  return shouldPersistSelectedText(latestSelectedText)
      ? latestSelectedText
      : previousSelectedText;
}
