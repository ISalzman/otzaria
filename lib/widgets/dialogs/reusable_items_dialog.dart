// lib/widgets/dialogs/reusable_items_dialog.dart
//
// [AppCustomContentDialog] — מיכל דיאלוג עם תוכן מותאם.
//
// מתאים לכל מסך מורכב שנפתח כדיאלוג: אירועי לוח שנה, הערות, היסטוריה וכד'.
//
// מאפיינים:
//  • Escape תמיד סוגר (דרך [DialogNavigationMixin])
//  • [actions] — שורת כפתורים אופציונלית בתחתית (ActionButton.recommended / .neutral)
//  • [onConfirm] + [handleEnterKey] — Enter אופציונלי להפעלת פעולה ראשית
//  • Enter פעיל רק כש-handleEnterKey=true **וגם** onConfirm מוגדר — מונע
//    סגירת דיאלוג בלתי מכוונת בלחיצת Enter בתוך שדות קלט
//  • רספונסיבי: 95% רוחב במובייל (< compact), 50% ב-desktop
//  • כפתור X לסגירה בפינה
//  • [scrollable] — ה-Scrollbar ממוקם אוטומטית בתוך ה-16px הקיים (לא מוסיף padding)

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/layout/panel_scrollable_content.dart';
import 'package:otzaria/widgets/misc/keyboard_dialog_navigation.dart';

// ── AppCustomContentDialog ─────────────────────────────────────────────────────

/// מיכל דיאלוג ראשי לתוכן מורכב — מסכים, רשימות, טפסים.
///
/// כל דיאלוג שמשתמש בו מקבל אוטומטית:
///  • Escape → סגירה
///  • Enter → [onConfirm] (רק אם [handleEnterKey]=true **וגם** [onConfirm] מוגדר)
class AppCustomContentDialog extends StatefulWidget {
  final String title;
  final Widget child;

  /// כפתורי פעולה שיוצגו בשורה בתחתית הדיאלוג.
  /// הכנס [ActionButton.recommended] / [ActionButton.neutral] כסטנדרט.
  final List<Widget>? actions;

  /// נקרא בלחיצת Enter (כשהפוקוס לא בשדה טקסט).
  /// כשמוגדר null, Enter מושבת לחלוטין ללא קשר ל-[handleEnterKey].
  final VoidCallback? onConfirm;

  /// האם Enter יכול להפעיל [onConfirm]. ברירת מחדל: false.
  /// Enter פעיל בפועל רק כש-true **וגם** [onConfirm] אינו null.
  final bool handleEnterKey;

  /// האם לעטוף את [child] ב-[SingleChildScrollView] אוטומטית.
  /// false כשה-child מנהל scroll פנימי בעצמו (ListView, CustomScrollView וכד').
  final bool scrollable;

  const AppCustomContentDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onConfirm,
    this.handleEnterKey = false,
    this.scrollable = true,
  });

  @override
  State<AppCustomContentDialog> createState() => _AppCustomContentDialogState();
}

class _AppCustomContentDialogState extends State<AppCustomContentDialog>
    with DialogNavigationMixin {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // במסך צר (mobile) 95% — מונע קריסת שורות. ב-desktop 50%.
    final isNarrow = size.width < LayoutBreakpoints.compact;
    final width = isNarrow ? size.width * 0.95 : size.width * 0.5;

    // Enter פעיל רק כשגם handleEnterKey=true וגם onConfirm מוגדר.
    // אחרת — לחיצת Enter בשדה טקסט עלולה לסגור את הדיאלוג בטעות.
    final effectiveHandleEnterKey =
        widget.handleEnterKey && widget.onConfirm != null;

    return buildKeyboardNavigator(
      onConfirm: widget.onConfirm ?? () {},
      onCancel: () => Navigator.of(context).pop(),
      handleEnterKey: effectiveHandleEnterKey,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: AppSurfaces.panelBackground(context),
        child: Container(
          width: width,
          height: size.height * 0.8,
          // padding אופקי מנוהל בנפרד: כותרת/כפתורים ב-Padding(horizontal:16),
          // אזור הגלילה מתפרס עד לגבול כדי שה-Scrollbar יישב בתוך ה-16px הקיים.
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(FluentIcons.dismiss_24_regular),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: widget.scrollable
                    // גובה הדיאלוג קבוע (80% מהמסך), כך שבחלון נמוך התוכן
                    // נחתך בלי סימן — פס גלילה קבוע הוא הרמז היחיד שיש המשך.
                    ? PanelScrollableContent(
                        thumbVisibility: true,
                        child: widget.child,
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: widget.child,
                      ),
              ),
              if (widget.actions != null && widget.actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.actions!,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
