import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' as ctx;
import 'package:otzaria/tools/dictionary/repository/dictionary_lookup_repository.dart';
import 'package:otzaria/tools/dictionary/widgets/aramaic_dictionary_entry_view.dart';
import 'package:otzaria/widgets/custom_ui_components.dart';

/// בונה פריטי תפריט הקשר למילונים על סמך הטקסט המסומן.
List<ctx.ContextMenuEntry<Object>> buildDictionaryContextMenuEntries({
  required BuildContext context,
  required String? selectedText,
  required DictionaryLookupRepository repository,
}) {
  final trimmed = selectedText?.trim() ?? '';
  if (trimmed.isEmpty || !repository.isLoaded) {
    return const <ctx.ContextMenuEntry<Object>>[];
  }

  if (repository.isLikelyAcronym(trimmed)) {
    final acronymEntry = repository.findAcronym(trimmed);
    if (acronymEntry == null) {
      return const <ctx.ContextMenuEntry<Object>>[];
    }

    return <ctx.ContextMenuEntry<Object>>[
      ctx.MenuItem<Object>.submenu(
        label: const Text(
          'פתיחת ראשי תיבות',
          textDirection: TextDirection.rtl,
        ),
        icon: const Icon(FluentIcons.text_quote_24_regular),
        items: acronymEntry.meanings
            .map<ctx.ContextMenuEntry<Object>>(
              (meaning) => ctx.MenuItem<Object>(
                label: SizedBox(
                  width: 320,
                  child: Text(
                    _summarizePlainText(meaning),
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onSelected: (_) => _showMeaningDialog(
                  context: context,
                  title: acronymEntry.acronym,
                  content: _buildAcronymDialogContent(meaning),
                ),
              ),
            )
            .toList(),
      ),
    ];
  }

  final aramaicMatches = repository.findAramaicMatches(trimmed);
  if (aramaicMatches.isEmpty) {
    return const <ctx.ContextMenuEntry<Object>>[];
  }

  return <ctx.ContextMenuEntry<Object>>[
    ctx.MenuItem<Object>.submenu(
      label: const Text(
        'מילון ארמי-עברי',
        textDirection: TextDirection.rtl,
      ),
      icon: const Icon(FluentIcons.translate_24_regular),
      items: aramaicMatches
          .map<ctx.ContextMenuEntry<Object>>(
            (entry) => ctx.MenuItem<Object>(
              label: SizedBox(
                width: 320,
                child: Text(
                  '${entry.aramaic} - ${_summarizeAramaicDefinition(entry.hebrew)}',
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onSelected: (_) => _showMeaningDialog(
                context: context,
                title: entry.aramaic,
                content: _buildAramaicDialogContent(entry),
              ),
            ),
          )
          .toList(),
    ),
  ];
}

String _summarizeAramaicDefinition(String definition) {
  final presentation = AramaicDictionaryEntryPresentation.parse(definition);
  final summary = presentation.meanings
      .map((meaning) {
        final parts = <String>[
          if (meaning.expression != null && meaning.expression!.isNotEmpty)
            meaning.expression!,
          if (meaning.mainText.isNotEmpty) meaning.mainText,
          if (meaning.expansion != null && meaning.expansion!.isNotEmpty)
            meaning.expansion!,
        ];

        return parts.join(' ');
      })
      .where((part) => part.isNotEmpty)
      .join('; ');

  return _summarizePlainText(summary);
}

String _summarizePlainText(String text, {int maxLength = 90}) {
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLength) {
    return compact;
  }

  return '${compact.substring(0, maxLength - 1).trim()}…';
}

Widget _buildAcronymDialogContent(String meaning) {
  return SizedBox(
    width: 460,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Text(
          meaning,
          textDirection: TextDirection.rtl,
        ),
      ),
    ),
  );
}

Widget _buildAramaicDialogContent(AramaicDictionaryEntry entry) {
  return SizedBox(
    width: 520,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.aramaic,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            AramaicDictionaryEntryView(
              definition: entry.hebrew,
            ),
          ],
        ),
      ),
    ),
  );
}

void _showMeaningDialog({
  required BuildContext context,
  required String title,
  required Widget content,
}) {
  showSingleActionDialog(
    context: context,
    title: title,
    customContent: content,
    confirmText: 'סגור',
  );
}
