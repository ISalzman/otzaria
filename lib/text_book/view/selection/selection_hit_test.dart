import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// המיקום של הטקסט המסומן בשורה מסוימת ביחס לטקסט המלא של הפסקה.
///
/// משמש כדי לאתר את טווח התווים הנבחר בתוך ה-RenderParagraph:
/// - [full] — כל השורה מסומנת (שורת ביניים בבחירה רב-שורתית).
/// - [prefix] — מסומן מתחילת השורה (שורת הסיום בבחירה רב-שורתית).
/// - [suffix] — מסומן עד סוף השורה (שורת ההתחלה בבחירה רב-שורתית).
/// - [substring] — מסומן קטע באמצע (בחירת שורה בודדת).
enum SelectionSegmentEdge { full, prefix, suffix, substring }

/// בודק אם נקודת הלחיצה [globalPosition] נופלת על הטקסט המסומן בפועל.
///
/// מאתר בתת-העץ של [root] את ה-RenderParagraph שמכיל את הנקודה, מחשב את טווח
/// התווים הנבחר בתוכו לפי [selectedSegment] ו-[edge], ובודק אם הנקודה בתוך תיבות
/// הבחירה. נעשה שימוש ב-`BoxHeightStyle.includeLineSpacingMiddle` כך שהרווח האנכי
/// שבין שורות-תצוגה של אותה שורת-מקור שנשברה (wrap) נחשב חלק מהבחירה.
///
/// [segmentStartHint] הוא רמז למיקום ההתחלה של הקטע המסומן בתוך טקסט הפסקה
/// (אופציונלי), ומשמש בעיקר במקרה [SelectionSegmentEdge.substring] כדי לבחור את
/// המופע הנכון כאשר אותו קטע חוזר כמה פעמים באותה פסקה — בוחרים את המופע הקרוב
/// ביותר לרמז. ללא רמז, מופע כפול נחשב דו-משמעי.
///
/// מחזיר:
/// - `true`  — הלחיצה על הטקסט המסומן.
/// - `false` — הלחיצה בתוך הפסקה אך מחוץ לטקסט המסומן (למשל חלק לא-מסומן בשורה).
/// - `null`  — לא ניתן להכריע (לא נמצאה פסקה מתאימה, הטקסט לא תאם וכו'). על
///   המתקשר לחזור לברירת מחדל סלחנית (לא לבטל את הבחירה).
bool? clickIsOnRenderedSelection({
  required RenderObject root,
  required Offset globalPosition,
  required String selectedSegment,
  required SelectionSegmentEdge edge,
  int? segmentStartHint,
}) {
  final paragraph = _findParagraphContaining(root, globalPosition);
  if (paragraph == null) return null;

  final pText = paragraph.text.toPlainText(includeSemanticsLabels: false);
  if (pText.isEmpty) return null;

  final int selStart;
  final int selEnd;
  switch (edge) {
    case SelectionSegmentEdge.full:
      selStart = 0;
      selEnd = pText.length;
    case SelectionSegmentEdge.prefix:
      selStart = 0;
      selEnd = selectedSegment.length.clamp(0, pText.length);
    case SelectionSegmentEdge.suffix:
      selStart = (pText.length - selectedSegment.length).clamp(0, pText.length);
      selEnd = pText.length;
    case SelectionSegmentEdge.substring:
      if (selectedSegment.isEmpty) return null;
      // אוספים את כל המופעים של הקטע בפסקה.
      final occurrences = <int>[];
      for (var from = 0;;) {
        final i = pText.indexOf(selectedSegment, from);
        if (i < 0) break;
        occurrences.add(i);
        from = i + 1;
      }
      if (occurrences.isEmpty) return null; // לא הצלחנו למפות — נחזור לסלחני
      final int chosen;
      if (occurrences.length == 1) {
        chosen = occurrences.first;
      } else if (segmentStartHint != null) {
        // מופע כפול — בוחרים את המופע הקרוב ביותר לרמז המיקום של הבחירה בפועל,
        // כך שלחיצה על המופע הלא-מסומן תיחשב מחוץ לבחירה (ותבטל).
        chosen = occurrences.reduce((a, b) =>
            (a - segmentStartHint).abs() <= (b - segmentStartHint).abs()
                ? a
                : b);
      } else {
        return null; // מופע כפול וללא רמז — דו-משמעי, נחזור לסלחני
      }
      selStart = chosen;
      selEnd = (chosen + selectedSegment.length).clamp(0, pText.length);
  }
  if (selStart >= selEnd) return null;

  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: selStart, extentOffset: selEnd),
    boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
  );
  if (boxes.isEmpty) return null;

  final local = paragraph.globalToLocal(globalPosition);
  for (final box in boxes) {
    if (box.toRect().contains(local)) return true;
  }
  return false;
}

/// מאתר את ה-RenderParagraph העמוק ביותר בתת-העץ של [root] שתיבתו מכילה את
/// [globalPosition]. מחזיר `null` אם אין כזה.
RenderParagraph? _findParagraphContaining(
  RenderObject root,
  Offset globalPosition,
) {
  RenderParagraph? found;
  void visit(RenderObject object) {
    if (found != null) return;
    if (object is RenderParagraph && object.attached && object.hasSize) {
      final local = object.globalToLocal(globalPosition);
      if ((Offset.zero & object.size).contains(local)) {
        found = object;
        return;
      }
    }
    object.visitChildren(visit);
  }

  visit(root);
  return found;
}
