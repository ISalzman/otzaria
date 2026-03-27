/// קובע האם יש לשמור את הטקסט הנבחר כבחירה האחרונה.
///
/// בחירה ריקה יכולה להופיע רגעית אחרי לחיצה ימנית שפותחת תפריט הקשר,
/// ולכן אין לדרוס בגללה את הטקסט האחרון שהמשתמש סימן.
bool shouldPersistSelectedText(String? selectedText) {
  return selectedText != null && selectedText.trim().isNotEmpty;
}
