import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/search/utils/hebrew_layout_suggestion.dart';
import 'package:otzaria/theme/app_tokens.dart';

/// באנר "האם התכוונת ל..." לטקסט שהוקלד בעברית במצב מקלדת אנגלי
/// (issue #975). מוצג רק כשההמרה לפי מיקום המקשים מניבה טקסט עברי, ואינו
/// משנה דבר בעצמו — לחיצה על ההצעה היא שמפעילה את [onAccept] עם הטקסט
/// המומר. הטקסט של המשתמש לעולם לא מוחלף אוטומטית.
///
/// חשוב להזין לכאן את הטקסט *הגולמי* מהשדה ולא שאילתה מנורמלת: פסיק
/// ונקודה הם המקשים של ת ו-ץ, ונרמול החיפוש מוחק אותם — ההצעה תצא חסרה.
class LayoutFixSuggestionBanner extends StatelessWidget {
  /// הטקסט שהוקלד, כמות שהוא.
  final String query;

  /// נקרא עם הטקסט המומר כשהמשתמש לוחץ על ההצעה.
  final ValueChanged<String> onAccept;

  /// הסבר קצר על תוצאת הלחיצה, מוצג בקצה השורה (אופציונלי).
  final String? hint;

  const LayoutFixSuggestionBanner({
    super.key,
    required this.query,
    required this.onAccept,
    this.hint,
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
              if (hint != null) ...[
                const SizedBox(width: AppTokens.spaceSM),
                Text(
                  hint!,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// הצעת תיקון-מקלדת חיה תוך כדי הקלדה: מאזינה ל-[controller] ומציגה את
/// הבאנר כשהטקסט הנוכחי נראה כהקלדה עברית במצב אנגלי. לחיצה מחליפה את
/// תוכן השדה בהצעה (הסמן בסופה) וקוראת ל-[onApplied] — שם המסך המארח
/// מרענן את החיפוש החי שלו. ההחלפה נעשית רק בלחיצה, לעולם לא אוטומטית.
class TypingLayoutFixSuggestion extends StatelessWidget {
  final TextEditingController controller;

  /// נקרא אחרי שההצעה כבר הוחלה על השדה, עם הטקסט המומר.
  final ValueChanged<String>? onApplied;

  final String? hint;

  const TypingLayoutFixSuggestion({
    super.key,
    required this.controller,
    this.onApplied,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => LayoutFixSuggestionBanner(
        query: controller.text,
        hint: hint,
        onAccept: (suggestion) {
          controller.value = TextEditingValue(
            text: suggestion,
            selection: TextSelection.collapsed(offset: suggestion.length),
          );
          onApplied?.call(suggestion);
        },
      ),
    );
  }
}
