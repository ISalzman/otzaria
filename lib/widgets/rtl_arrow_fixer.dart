import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// רכיב לתיקון התנהגות מקשי החיצים בשדות טקסט RTL
///
/// בעיה ידועה ב-Flutter Desktop: כאשר כיוון הטקסט הוא RTL,
/// מקשי החיצים פועלים הפוך - חץ שמאל מזיז ימינה וחץ ימין מזיז שמאלה.
/// רכיב זה מתקן את הבעיה על ידי לכידת אירועי המקשים והיפוך הכיוון.
class RtlArrowFixer extends StatelessWidget {
  final TextEditingController controller;
  final Widget child;

  const RtlArrowFixer({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // בודקים האם כיוון הטקסט הנוכחי הוא RTL
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    if (!isRtl) return child;

    return CallbackShortcuts(
      bindings: {
        // חץ שמאל (שאמור להזיז ויזואלית שמאלה = לוגית קדימה ב-RTL)
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          _moveCursor(1); // מזיזים קדימה (אינדקס + 1)
        },
        // חץ ימין (שאמור להזיז ויזואלית ימינה = לוגית אחורה ב-RTL)
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          _moveCursor(-1); // מזיזים אחורה (אינדקס - 1)
        },
      },
      child: child,
    );
  }

  void _moveCursor(int offsetChange) {
    final text = controller.text;
    final selection = controller.selection;

    // חישוב המיקום החדש
    final newOffset =
        (selection.baseOffset + offsetChange).clamp(0, text.length);

    // אם יש בחירה (Highlight), לחיצה מבטלת אותה ומזיזה לקצה
    // אם אין בחירה, פשוט מזיזים את הסמן
    var targetOffset = newOffset;

    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: targetOffset),
    );
  }
}
