import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

/// מתג "מילים שלמות בלבד" של החיפוש בתוך ספר, בשדה החיפוש עצמו.
/// משותף לחיפוש בספר טקסט ובספר PDF כדי שהאייקון והתווית לא יסטו.
Widget wholeWordSearchAction({
  required BuildContext context,
  required bool wholeWord,
  required VoidCallback onToggle,
}) {
  return OtzariaSearchAction.icon(
    iconData: wholeWord
        ? FluentIcons.text_whole_word_20_filled
        : FluentIcons.text_whole_word_20_regular,
    onPressed: onToggle,
    tooltip: wholeWord
        ? 'מחפש מילים שלמות בלבד'
        : 'מחפש גם חלק ממילה — לחץ למילים שלמות',
    color: wholeWord ? Theme.of(context).colorScheme.primary : null,
  );
}
