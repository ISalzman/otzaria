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
String restoreSelectedTextLineBreaks({
  required String selectedText,
  required List<String> visibleLines,
}) {
  if (selectedText.isEmpty ||
      visibleLines.isEmpty ||
      selectedText.contains('\n')) {
    return selectedText;
  }

  final visibleText = visibleLines.join('\n');
  final normalizedVisible = visibleText.replaceAll('\n', '');
  final normalizedSelected = selectedText.replaceAll('\n', '');

  if (normalizedSelected.isEmpty) {
    return selectedText;
  }

  final startNonNewline = normalizedVisible.indexOf(normalizedSelected);
  if (startNonNewline < 0) {
    return selectedText;
  }

  final nonNewlineToVisible = <int>[];
  for (var i = 0; i < visibleText.length; i++) {
    if (visibleText[i] != '\n') {
      nonNewlineToVisible.add(i);
    }
  }

  final endNonNewline = startNonNewline + normalizedSelected.length - 1;
  if (endNonNewline >= nonNewlineToVisible.length) {
    return selectedText;
  }

  final startVisible = nonNewlineToVisible[startNonNewline];
  final endVisible = nonNewlineToVisible[endNonNewline];
  return visibleText.substring(startVisible, endVisible + 1);
}
