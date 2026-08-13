import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/search/view/search_result_source_tag.dart';

/// שורת הכותרת בכרטיס תוצאה של ספק חיצוני: שם הספר, מספר המופעים בו, תגית
/// המקור וכפתור העתקת הגזיר.
///
/// הפריסה מיישרת את התגית ואת הכפתור לקצה השורה (הכותרת היא [Expanded]),
/// כדי שיישבו על אותו קו שבו הם יושבים בכרטיס של המנוע המובנה. שאר הרכיבים
/// אינם גמישים, ולכן כל אחד מהם מוגבל ברוחבו: שם המדור מגיע מהתוסף ואורכו
/// אינו ידוע מראש, וכיתוב המופעים מתקצר למספר בלבד בשורה צרה.
class ExternalResultTitleRow extends StatelessWidget {
  /// מתחת לרוחב הזה נשאר ממספר המופעים המספר בלבד.
  static const narrowWidth = 420.0;

  /// חלק הרוחב שתגית המקור לא תחרוג ממנו.
  static const _tagWidthFraction = 0.3;

  final String title;
  final int hitCount;
  final String sourceTag;

  /// גזיר הטקסט להעתקה; null כשעוד לא התקבל גזיר — ואז אין כפתור העתקה.
  final String? copyText;

  const ExternalResultTitleRow({
    super.key,
    required this.title,
    required this.hitCount,
    required this.sourceTag,
    this.copyText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < narrowWidth;
        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hitCount > 0) ...[
              const SizedBox(width: 8),
              _buildHitCountPill(context, compact: compact),
            ],
            if (sourceTag.isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _tagWidthFraction,
                ),
                child: SearchResultSourceTag(label: sourceTag),
              ),
            ],
            if (copyText != null) ...[
              const SizedBox(width: 4),
              _buildCopyButton(context, copyText!),
            ],
          ],
        );
      },
    );
  }

  /// מספר המופעים בספר, לצד שמו: מספר עירום בקצה הכרטיס לא אמר מה הוא סופר.
  /// בשורה צרה נשאר המספר בלבד, עם הכיתוב המלא בהצבעה.
  Widget _buildHitCountPill(BuildContext context, {required bool compact}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = hitCount == 1 ? 'תוצאה אחת בספר' : '$hitCount תוצאות בספר';
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          compact ? '$hitCount' : label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  /// העתקת גזיר הטקסט, כמו בכרטיס תוצאה של המנוע המובנה — הגזיר כבר בידינו,
  /// ואין סיבה שדווקא כאן יידרש לפתוח את הספר כדי להעתיק ממנו.
  Widget _buildCopyButton(BuildContext context, String snippet) {
    return IconButton(
      icon: Icon(
        FluentIcons.copy_24_regular,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'העתק טקסט',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: snippet));
        UiSnack.show(UiSnack.textCopied);
      },
    );
  }
}
