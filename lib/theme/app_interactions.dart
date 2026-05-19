// lib/theme/app_interactions.dart
//
// ════════════════════════════════════════════════════════════════════════════
//  AppInteractions — אפקטי hover/pressed/focused עבור [InkWell] עצמאיים
// ════════════════════════════════════════════════════════════════════════════
//
//  הרקע:
//  [AppThemeData] מגדיר `overlayColor` רק עבור IconButton / FilledButton /
//  TextButton / OutlinedButton. רכיבי [InkWell] שמשמשים כ"שורות לחיצות"
//  (Sidebar/TopNav/Library rows/Grid items) **אינם** מקבלים את ה-hover
//  הזה מהתמה — וברירת המחדל של Flutter היא overlay אפור.
//
//  לפני התיקון, כל אתר כזה הגדיר אצלו `overlayColor`/`hoverColor` ידני.
//  לאחר שהקוד הזה נמחק במחיקת "ניקוי hover", נוצרה רגרסיה ויזואלית.
//
//  [AppInteractions] מספק שני סטים מוכנים של ערכים שתואמים את התמה:
//  - [primaryOverlay]       — מתאים ל-nav pills (8% hover, 12% pressed/focused).
//  - [subtlePrimaryOverlay] — מתאים לרשימות ארוכות / grid items (6% / 10%).
//
//  **שימוש:**
//  ```dart
//  final cs = Theme.of(context).colorScheme;
//  InkWell(
//    borderRadius: BorderRadius.circular(...),
//    overlayColor: AppInteractions.primaryOverlay(cs),
//    onTap: ...,
//    child: ...,
//  );
//  ```

import 'package:flutter/material.dart';

class AppInteractions {
  AppInteractions._();

  /// Overlay בצבע primary: hover 8%, pressed/focused 12%.
  ///
  /// תואם למוסכמת ה-overlay של רכיבי הכפתורים שמוגדרת ב-[AppThemeData]
  /// (`_iconButtonTheme`, `_textButtonTheme`, `_outlinedButtonTheme`).
  /// השימוש המומלץ הוא בפריטי ניווט (sidebar/top-nav) ו-pills בודדים.
  static WidgetStateProperty<Color?> primaryOverlay(ColorScheme cs) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return cs.primary.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return cs.primary.withValues(alpha: 0.12);
      }
      return null;
    });
  }

  /// Overlay עדין בצבע primary: hover 6%, pressed/focused 10%.
  ///
  /// מתאים לרשימות ארוכות (Library tree) או רכיבי grid צפופים — שם
  /// ריבוי שורות עם overlay של 8% עלול להיראות "רועש". האפקט עדין יותר,
  /// אבל עדיין משאיר תחושה של אינטראקטיביות.
  static WidgetStateProperty<Color?> subtlePrimaryOverlay(ColorScheme cs) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return cs.primary.withValues(alpha: 0.06);
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return cs.primary.withValues(alpha: 0.10);
      }
      return null;
    });
  }

  /// Overlay בולט בצבע primaryContainer: hover 30%, pressed/focused 40%.
  ///
  /// מתאים לתוצאות חיפוש (`SearchResultTile`) ולפריטים שרוצים שיתבלטו ברור
  /// כשמרחפים מעליהם — שם תהליך הסריקה של המשתמש מתעכב על כל פריט
  /// ודרושה הדגשה מובהקת ולא רק רמז עדין.
  static WidgetStateProperty<Color?> primaryContainerOverlay(ColorScheme cs) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return cs.primaryContainer.withValues(alpha: 0.30);
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return cs.primaryContainer.withValues(alpha: 0.40);
      }
      return null;
    });
  }

  /// Overlay ניטרלי בגוון surfaceContainerHighest: hover 35%, pressed/focused 50%.
  ///
  /// מתאים לכרטיסים שאינטראקטיביים אבל לא רוצים את הצבע ה"חם" של primary —
  /// למשל כרטיסי תוצאת כלים (Tool Result Card) או הערות אישיות, שבהם
  /// ה-hover אמור רק לרמוז שאפשר ללחוץ, בלי לצבוע את כל הכרטיס בגוון ראשי.
  static WidgetStateProperty<Color?> neutralSurfaceOverlay(ColorScheme cs) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return cs.surfaceContainerHighest.withValues(alpha: 0.35);
      }
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused)) {
        return cs.surfaceContainerHighest.withValues(alpha: 0.50);
      }
      return null;
    });
  }
}
