import 'package:flutter/material.dart';
import 'package:otzaria/tools/dictionary/repository/dictionary_lookup_repository.dart';

/// מציג פירוש של מילה במילון הארמי-עברי בצורה מונגשת ומובנית.
class AramaicDictionaryEntryView extends StatelessWidget {
  const AramaicDictionaryEntryView({
    super.key,
    required this.definition,
    this.maxMeanings,
    this.compact = false,
  });

  final String definition;
  final int? maxMeanings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final parsedEntry = AramaicDictionaryEntryPresentation.parse(definition);
    final meanings = maxMeanings == null
        ? parsedEntry.meanings
        : parsedEntry.meanings.take(maxMeanings!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < meanings.length; index++) ...[
          if (index > 0) SizedBox(height: compact ? 8 : 12),
          _MeaningView(
            meaning: meanings[index],
            index: index,
            compact: compact,
          ),
        ],
      ],
    );
  }
}

class _MeaningView extends StatelessWidget {
  const _MeaningView({
    required this.meaning,
    required this.index,
    required this.compact,
  });

  final ParsedAramaicMeaning meaning;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 22 : 26,
            height: compact ? 22 : 26,
            alignment: Alignment.center,
            margin: const EdgeInsetsDirectional.only(top: 2, end: 10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${index + 1}',
              textDirection: TextDirection.rtl,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meaning.expression != null) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      meaning.expression!,
                      textDirection: TextDirection.rtl,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                ],
                if (meaning.mainText.isNotEmpty)
                  Text(
                    meaning.mainText,
                    textDirection: TextDirection.rtl,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                if (meaning.expansion != null) ...[
                  SizedBox(height: compact ? 2 : 4),
                  Text(
                    meaning.expansion!,
                    textDirection: TextDirection.rtl,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
