import 'package:otzaria/text_display/models/text_display_layer.dart';
import 'package:otzaria/text_display/models/text_display_policy.dart';
import 'package:otzaria/text_display/models/text_display_profile.dart';
import 'package:otzaria/text_display/models/text_display_slot.dart';

/// גשר מהדגלים הבוליאניים הישנים (`removeNikud`, `nikudExemptByTanach`…) אל
/// שכבות התצוגה. משמש בנאים ובדיקות שעדיין מדברים בשפת הדגלים.
MarkVisibility visibilityOf(bool remove) =>
    remove ? MarkVisibility.hide : MarkVisibility.show;

bool? removeFlagOf(MarkVisibility? visibility) => switch (visibility) {
  null => null,
  MarkVisibility.hide => true,
  MarkVisibility.show => false,
};

/// מדיניות סינתטית שמשחזרת את טבלת האמת הישנה: הגוף לפי הדגל שלו, והמפרשים
/// מוסתרים כשהגוף מוסתר או כשהספר פטור רק בזכות היותו תנ"ך.
TextDisplayPolicy legacyDisplayPolicy({
  required bool removeNikud,
  required bool removePunctuation,
  required bool nikudExemptByTanach,
  required bool punctuationExemptByTanach,
}) {
  return TextDisplayPolicy(
    general: TextDisplayLayer({
      TextDisplaySlot.root: TextDisplayPatch(
        nikud: visibilityOf(removeNikud),
        punctuation: visibilityOf(removePunctuation),
      ),
      // טלאי מפורש למפרשים רק כשיש פטור — אחרת הם יורשים מהגוף, כולל את
      // ההחלפות היזומות בסרגל.
      TextDisplaySlot.commentaryDisplay: TextDisplayPatch(
        nikud: nikudExemptByTanach ? MarkVisibility.hide : null,
        punctuation: punctuationExemptByTanach ? MarkVisibility.hide : null,
      ),
    }),
    tanach: TextDisplayLayer.empty,
  );
}

/// שכבת עקיפות מהעקיפות הזמניות הישנות של כרטיסיית המפרשים.
TextDisplayLayer legacyDisplayOverrides({
  required TextView view,
  bool? commentaryRemoveNikud,
  bool? commentaryRemovePunctuation,
}) {
  if (commentaryRemoveNikud == null && commentaryRemovePunctuation == null) {
    return TextDisplayLayer.empty;
  }
  return TextDisplayLayer({
    TextDisplaySlot(
      target: TextTarget.commentary,
      view: view,
      channel: TextChannel.display,
    ): TextDisplayPatch(
      nikud: commentaryRemoveNikud == null
          ? null
          : visibilityOf(commentaryRemoveNikud),
      punctuation: commentaryRemovePunctuation == null
          ? null
          : visibilityOf(commentaryRemovePunctuation),
    ),
  });
}

/// שכבת ספר מהשדות הישנים של קובץ ההגדרות הפר-ספרי.
TextDisplayLayer legacyBookDisplayLayer({
  bool? removeNikud,
  bool? removePunctuation,
}) {
  if (removeNikud == null && removePunctuation == null) {
    return TextDisplayLayer.empty;
  }
  return TextDisplayLayer({
    TextDisplaySlot.root: TextDisplayPatch(
      nikud: removeNikud == null ? null : visibilityOf(removeNikud),
      punctuation: removePunctuation == null
          ? null
          : visibilityOf(removePunctuation),
    ),
  });
}
