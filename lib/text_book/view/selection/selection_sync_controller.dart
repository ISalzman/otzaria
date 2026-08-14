import 'package:flutter/foundation.dart';

/// מסנכרן בחירת טקסט בין כמה אזורי SelectionArea באותו מסך: רק אזור אחד
/// מחזיק בחירה בכל רגע, והשאר מנקים את שלהם כשהבעלות עוברת.
class SelectionSyncController extends ChangeNotifier {
  Object? _activeOwner;

  Object? get activeOwner => _activeOwner;

  void activate(Object owner) {
    if (identical(_activeOwner, owner)) {
      return;
    }

    _activeOwner = owner;
    notifyListeners();
  }

  void clear(Object owner) {
    if (!identical(_activeOwner, owner)) {
      return;
    }

    _activeOwner = null;
    notifyListeners();
  }
}

/// קובע האם אזור צריך לנקות את הבחירה שלו כשאזור אחר תפס בעלות.
///
/// הניקוי חייב להתבצע דרך `SelectableRegionState.clearSelection()`. ניקוי
/// על-ידי החלפת מפתח ה-SelectionArea הורס את עץ הצאצאים, ובמצב 'מפרשים מתחת'
/// (שבו רשימת המפרשים מקוננת בתוך אזור הטקסט הראשי) הוא מוחק את הבחירה
/// שהמשתמש זה עתה סימן במפרש — והעתקה יוצאת ריקה (issue #674).
bool shouldClearSelectionOnExternalChange({
  required Object? activeOwner,
  required Object selfOwner,
  required bool hasOwnSelection,
}) {
  if (activeOwner == null) return false;
  if (identical(activeOwner, selfOwner)) return false;
  return hasOwnSelection;
}
