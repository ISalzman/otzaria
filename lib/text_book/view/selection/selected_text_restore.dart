import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/text_renderer_service.dart';

/// מעבד שורת מקור לאותו טקסט פשוט שהמשתמש רואה בפועל במסך.
///
/// תצוגת ה-HTML מכווצת רצפי רווחים לרווח אחד ומקצצת רווחים בקצוות,
/// ולכן יש לכווץ גם כאן — אחרת רווחים כפולים שמותיר `removePunctuation`
/// (כשהוא מסיר פיסוק שהיה מוקף ברווחים) ימנעו את התאמת הבחירה בשחזור.
String renderSelectionLine({
  required String rawText,
  required RenderSettings settings,
}) {
  final processed = TextRendererService.processText(rawText, settings);
  final stripped = TextRendererService.stripHtml(processed);
  return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// משחזר מעברי שורה בטקסט שנבחר מ-SelectionArea כאשר Flutter מחזיר טקסט שטוח.
///
/// תחילה מנסה התאמה מדויקת (הבחירה כתת-מחרוזת רציפה של השורות המרונדרות);
/// אם היא נכשלת — עובר לשחזור סלחני שורה-אחר-שורה שמזריק מעברי שורה גם כאשר
/// שורה בודדת באמצע אינה תואמת (רינדור שונה) או חסרה (נגללה מחוץ לתצוגה).
String restoreSelectedTextLineBreaks({
  required String selectedText,
  required List<String> visibleLines,
}) {
  if (selectedText.isEmpty ||
      visibleLines.isEmpty ||
      selectedText.contains('\n')) {
    return selectedText;
  }

  final exact = _restoreExact(selectedText, visibleLines);
  if (exact != null) {
    return exact;
  }
  return _restoreGreedy(selectedText, visibleLines);
}

/// התאמה מדויקת: הבחירה השטוחה חייבת להיות תת-מחרוזת רציפה של איחוד השורות.
/// מחזיר `null` כשאין התאמה, כדי לאפשר נפילה לשחזור הסלחני.
String? _restoreExact(String selectedText, List<String> visibleLines) {
  final visibleText = visibleLines.join('\n');
  final normalizedVisible = visibleText.replaceAll('\n', '');
  final normalizedSelected = selectedText.replaceAll('\n', '');

  if (normalizedSelected.isEmpty) {
    return selectedText;
  }

  final startNonNewline = normalizedVisible.indexOf(normalizedSelected);
  if (startNonNewline < 0) {
    return null;
  }

  final nonNewlineToVisible = <int>[];
  for (var i = 0; i < visibleText.length; i++) {
    if (visibleText[i] != '\n') {
      nonNewlineToVisible.add(i);
    }
  }

  final endNonNewline = startNonNewline + normalizedSelected.length - 1;
  if (endNonNewline >= nonNewlineToVisible.length) {
    return null;
  }

  final startVisible = nonNewlineToVisible[startNonNewline];
  final endVisible = nonNewlineToVisible[endNonNewline];
  return visibleText.substring(startVisible, endVisible + 1);
}

/// שחזור סלחני: מזריק `\n` לתוך הבחירה השטוחה בלבד — לעולם אינו משנה תווים.
/// אם ההזרקה מייצרת טקסט שאינו זהה לבחירה המקורית (מלבד ה-`\n`), חוזר לבחירה.
String _restoreGreedy(String selectedText, List<String> visibleLines) {
  final start = _findSelectionStart(selectedText, visibleLines);
  if (start == null) {
    return selectedText;
  }

  final (startLine, startOffset) = start;
  final result = StringBuffer();

  // צריכת החלק שנבחר מהשורה הראשונה (הבחירה עשויה להתחיל באמצע שורה).
  final firstLine = visibleLines[startLine];
  final firstContribution =
      (firstLine.length - startOffset).clamp(0, selectedText.length);
  result.write(selectedText.substring(0, firstContribution));
  var pos = firstContribution;

  var lineIndex = startLine + 1;
  while (pos < selectedText.length && lineIndex < visibleLines.length) {
    final line = visibleLines[lineIndex];
    lineIndex++;
    if (line.isEmpty) {
      continue;
    }
    final remaining = selectedText.substring(pos);
    if (remaining.startsWith(line)) {
      result.write('\n');
      result.write(line);
      pos += line.length;
    } else if (line.startsWith(remaining)) {
      // הבחירה מסתיימת באמצע השורה הנוכחית.
      result.write('\n');
      result.write(remaining);
      pos = selectedText.length;
    } else {
      final found = remaining.indexOf(line);
      if (found > 0) {
        // מקטע לא-תואם לפני השורה (שורה שנגללה/רונדרה שונה) — שורה נפרדת.
        result.write('\n');
        result.write(remaining.substring(0, found));
        result.write('\n');
        result.write(line);
        pos += found + line.length;
      }
      // אחרת: השורה אינה בבחירה כאן — מדלגים עליה בלי לצרוך תווים.
    }
  }

  if (pos < selectedText.length) {
    result.write(selectedText.substring(pos));
  }

  final restored = result.toString();
  if (restored.replaceAll('\n', '') != selectedText) {
    return selectedText;
  }
  return restored;
}

/// מאתר את השורה והעמודה שבהן מתחילה הבחירה בתוך השורות המרונדרות.
(int, int)? _findSelectionStart(
  String selectedText,
  List<String> visibleLines,
) {
  for (var lineIndex = 0; lineIndex < visibleLines.length; lineIndex++) {
    final line = visibleLines[lineIndex];
    if (line.isEmpty) {
      continue;
    }
    for (var offset = 0; offset < line.length; offset++) {
      if (selectedText.startsWith(line.substring(offset))) {
        return (lineIndex, offset);
      }
    }
    final inside = line.indexOf(selectedText);
    if (inside >= 0) {
      return (lineIndex, inside);
    }
  }
  return null;
}
