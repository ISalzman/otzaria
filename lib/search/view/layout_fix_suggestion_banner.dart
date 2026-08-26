import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/search/utils/hebrew_layout_suggestion.dart';
import 'package:otzaria/theme/app_tokens.dart';

/// באנר "האם התכוונת ל..." לשאילתה שהוקלדה בעברית במצב מקלדת אנגלי
/// (issue #975). מוצג רק כשההמרה לפי מיקום המקשים מניבה טקסט עברי, ואינו
/// משנה דבר בעצמו — לחיצה על ההצעה היא שמפעילה את [onAccept] עם הטקסט
/// המומר, והקורא מריץ חיפוש חדש. שאילתת המשתמש לעולם לא מוחלפת אוטומטית.
class LayoutFixSuggestionBanner extends StatelessWidget {
  /// השאילתה שבוצעה בפועל (state.searchQuery).
  final String query;

  /// נקרא עם הטקסט המומר כשהמשתמש לוחץ על ההצעה.
  final ValueChanged<String> onAccept;

  const LayoutFixSuggestionBanner({
    super.key,
    required this.query,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final suggestion = suggestHebrewKeyboardFix(query);
    if (suggestion == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.35),
      child: InkWell(
        onTap: () => onAccept(suggestion),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            children: [
              Icon(
                FluentIcons.keyboard_24_regular,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                    children: [
                      const TextSpan(text: 'האם התכוונת לחפש: '),
                      TextSpan(
                        text: suggestion,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: cs.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTokens.spaceSM),
              Text(
                'לחיצה תריץ את החיפוש המוצע',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
