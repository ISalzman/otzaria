import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// מחזיר את המילה שנמצאת תחת הסמן בנקודה גלובלית נתונה.
///
/// משתמש ב-hit-testing על ה-render tree כדי למצוא את ה-[RenderParagraph]
/// הרלוונטי, ואז שולף את גבולות המילה דרך [RenderParagraph.getWordBoundary].
///
/// מחזיר null אם לא נמצאה מילה (לחיצה על אזור ריק, תמונה, וכו').
String? wordAtGlobalPosition(Offset globalPosition) {
  final hitTestResult = BoxHitTestResult();
  for (final view in WidgetsBinding.instance.renderViews) {
    view.hitTest(hitTestResult, position: globalPosition);
  }

  for (final entry in hitTestResult.path) {
    final target = entry.target;
    if (target is! RenderParagraph) continue;
    try {
      final localPosition = target.globalToLocal(globalPosition);
      final textPosition = target.getPositionForOffset(localPosition);
      final wordRange = target.getWordBoundary(textPosition);
      if (wordRange.isCollapsed) continue;
      final plainText = target.text.toPlainText();
      if (wordRange.start < 0 || wordRange.end > plainText.length) continue;
      final word = plainText.substring(wordRange.start, wordRange.end).trim();
      if (word.isEmpty) continue;
      return word;
    } catch (_) {
      continue;
    }
  }
  return null;
}
