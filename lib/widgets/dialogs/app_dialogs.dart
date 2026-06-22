// lib/widgets/dialogs/app_dialogs.dart
// דיאלוגים גנריים של האפליקציה — M3-styled.
//
// [AppDialog] — דיאלוג יחיד עם שלושה בנאים ממוינים:
//  • [AppDialog.singleAction] — כפתור אישור בלבד
//  • [AppDialog.twoActions]   — ביטול (tonal) + אישור (primary)
//  • [AppDialog.warning]      — ביטול (primary) + אישור (TextButton error)
//
// כל הוריאנטים כוללים ניווט מקלדת (חיצים, Enter, Escape) והדגשת פוקוס חזותית.

import 'package:flutter/material.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/misc/keyboard_dialog_navigation.dart';

// ── AppDialog ─────────────────────────────────────────────────────────────────

enum _DialogVariant { singleAction, twoActions, warning }

/// דיאלוג גנרי M3 עם ניווט מקלדת מלא והדגשת פוקוס. השתמש בבנאים הממוינים:
/// - [AppDialog.singleAction] — כפתור אישור בלבד
/// - [AppDialog.twoActions] — ביטול + אישור
/// - [AppDialog.warning] — ביטול (primary/בטוח) + אישור (error/מסוכן)
class AppDialog extends StatefulWidget {
  final dynamic title;
  final String? content;
  final Widget? customContent;
  final String confirmText;
  final String cancelText;
  final String? subtitle;
  final TextDirection? textDirection;
  final bool handleEnterKey;
  final _DialogVariant _variant;

  // מאפשר לעצור סגירת הדיאלוג — למשל כשוולידציה נכשלת. null = סגור תמיד.
  final bool Function()? onConfirm;

  const AppDialog.singleAction({
    super.key,
    required this.title,
    this.content,
    this.customContent,
    this.confirmText = 'אישור',
    this.textDirection,
    this.onConfirm,
  })  : assert(
          content != null || customContent != null,
          'content או customContent חייבים להיות מוגדרים',
        ),
        _variant = _DialogVariant.singleAction,
        cancelText = '',
        subtitle = null,
        handleEnterKey = true;

  const AppDialog.twoActions({
    super.key,
    required this.title,
    required this.content,
    this.customContent,
    this.cancelText = 'ביטול',
    this.confirmText = 'אישור',
    this.textDirection,
    this.handleEnterKey = true,
  })  : _variant = _DialogVariant.twoActions,
        subtitle = null,
        onConfirm = null;

  const AppDialog.warning({
    super.key,
    required this.title,
    required this.content,
    this.customContent,
    this.cancelText = 'ביטול',
    this.confirmText = 'המשך',
    this.subtitle,
    this.textDirection,
  })  : _variant = _DialogVariant.warning,
        handleEnterKey = true,
        onConfirm = null;

  @override
  State<AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<AppDialog> with DialogNavigationMixin {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return buildKeyboardNavigator(
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
      handleEnterKey: widget.handleEnterKey,
      child: AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        title: widget.title is String
            ? Text(widget.title as String, textDirection: widget.textDirection)
            : widget.title as Widget,
        content: _buildContent(cs),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (widget.customContent != null) return widget.customContent!;
    if (widget._variant == _DialogVariant.warning && widget.subtitle != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.content!, textDirection: widget.textDirection),
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: TextStyle(color: cs.error, fontSize: 13),
            textDirection: widget.textDirection,
          ),
        ],
      );
    }
    return Text(widget.content!, textDirection: widget.textDirection);
  }

  List<Widget> _buildActions() => switch (widget._variant) {
        _DialogVariant.singleAction => [
            _withFocus(
              isFocused: true,
              child: ActionButton.recommended(
                text: widget.confirmText,
                onPressed: () {
                  if (widget.onConfirm != null && !widget.onConfirm!()) return;
                  Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        _DialogVariant.twoActions => [
            _withFocus(
              isFocused: focusedButtonIndex == 0,
              child: ActionButton.neutral(
                text: widget.cancelText,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            _withFocus(
              isFocused: focusedButtonIndex == 1,
              child: ActionButton.recommended(
                text: widget.confirmText,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        _DialogVariant.warning => [
            _withFocus(
              isFocused: focusedButtonIndex == 0,
              child: ActionButton.recommended(
                text: widget.cancelText,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            _withFocus(
              isFocused: focusedButtonIndex == 1,
              child: ActionButton.warning(
                text: widget.confirmText,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
      };

  // Border שקוף כשלא ממוקד — שומר על מרחב קבוע למניעת קפיצת layout.
  Widget _withFocus({required bool isFocused, required Widget child}) =>
      _KeyboardFocusBorder(
        isFocused: isFocused,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: DefaultTextStyle.of(context).style.copyWith(
                fontWeight:
                    isFocused ? FontWeight.bold : FontWeight.normal,
              ),
          child: child,
        ),
      );
}

// ── _KeyboardFocusBorder ──────────────────────────────────────────────────────

class _KeyboardFocusBorder extends StatelessWidget {
  final bool isFocused;
  final Widget child;

  const _KeyboardFocusBorder({required this.isFocused, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFocused ? cs.outline : Colors.transparent,
          width: 2.0,
        ),
      ),
      child: child,
    );
  }
}

// ── show* functions ───────────────────────────────────────────────────────────

Future<bool?> showSingleActionDialog({
  required BuildContext context,
  required String title,
  String? content,
  Widget? customContent,
  String confirmText = 'אישור',
  TextDirection? textDirection,
  bool barrierDismissible = true,
  bool Function()? onConfirm,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog.singleAction(
        title: title,
        content: content,
        customContent: customContent,
        confirmText: confirmText,
        textDirection: textDirection,
        onConfirm: onConfirm,
      ),
    );

Future<bool?> showTwoActionsDialog({
  required BuildContext context,
  required String title,
  required String content,
  Widget? customContent,
  String cancelText = 'ביטול',
  String confirmText = 'אישור',
  TextDirection? textDirection,
  bool barrierDismissible = true,
  bool handleEnterKey = true,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog.twoActions(
        title: title,
        content: content,
        customContent: customContent,
        cancelText: cancelText,
        confirmText: confirmText,
        textDirection: textDirection,
        handleEnterKey: handleEnterKey,
      ),
    );

Future<bool?> showWarningDialog({
  required BuildContext context,
  required String title,
  required String content,
  String? subtitle,
  String cancelText = 'ביטול',
  String confirmText = 'המשך',
  TextDirection? textDirection,
  bool barrierDismissible = true,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog.warning(
        title: title,
        content: content,
        subtitle: subtitle,
        cancelText: cancelText,
        confirmText: confirmText,
        textDirection: textDirection,
      ),
    );

Future<bool?> showDbCopyRequiredDialog({
  required BuildContext context,
  required String sizeText,
  bool barrierDismissible = false,
}) =>
    showTwoActionsDialog(
      context: context,
      title: 'נדרשת העתקה של קובץ הספרייה',
      content: '',
      barrierDismissible: barrierDismissible,
      cancelText: 'העתק (שמור מקור)',
      confirmText: 'העתק + נסה מחק מקור',
      customContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'לא ניתן לגשת ישירות לקובץ seforim.db (גודל: $sizeText) מכיוון שהוא נמצא באחסון חיצוני ב-Android.',
          ),
          const SizedBox(height: 12),
          const Text(
            'לחץ על כפתור למטה, נווט לאותה תיקייה ובחר את הקובץ seforim.db — האפליקציה תעתיק אותו לאחסון הפנימי.',
          ),
          const SizedBox(height: 6),
          const Text(
            '(אפשרות "נסה מחק מקור" — ניסיון למחוק לאחר העתקה. עשויה שלא להצליח בכל גרסאות Android.)',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
