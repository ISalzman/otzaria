import 'dart:async';

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
  if (trimmed.isEmpty) {
    return const <ctx.ContextMenuEntry<Object>>[];
  }

  final entries = <ctx.ContextMenuEntry<Object>>[];
  final shouldCheckAcronyms = repository.isLikelyAcronym(trimmed);

  if (shouldCheckAcronyms && !repository.areAcronymsLoaded) {
    unawaited(repository.ensureAcronymsLoaded().catchError((_) {}));
  }

  if (!repository.areAramaicLoaded) {
    unawaited(repository.ensureAramaicLoaded().catchError((_) {}));
  }

  if (shouldCheckAcronyms && repository.areAcronymsLoaded) {
    final acronymEntries = repository.findAcronymMatches(trimmed);
    if (acronymEntries.isNotEmpty) {
      entries.add(_buildAcronymSubmenu(context, acronymEntries));
    }
  }

  if (repository.areAramaicLoaded) {
    final aramaicMatches = repository.findAramaicMatches(trimmed);
    if (aramaicMatches.isNotEmpty) {
      entries.add(
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
      );
    }
  }

  return entries;
}

ctx.ContextMenuEntry<Object> _buildAcronymSubmenu(
  BuildContext context,
  List<AcronymDictionaryEntry> acronymEntries,
) {
  final items = acronymEntries.length == 1
      ? acronymEntries.single.meanings
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
                title: acronymEntries.single.acronym,
                content: _buildAcronymDialogContent(meaning),
              ),
            ),
          )
          .toList()
      : acronymEntries
          .map<ctx.ContextMenuEntry<Object>>(
            (entry) => entry.meanings.length == 1
                ? ctx.MenuItem<Object>(
                    label: SizedBox(
                      width: 320,
                      child: Text(
                        '${entry.acronym} - ${_summarizePlainText(entry.meanings.single)}',
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onSelected: (_) => _showMeaningDialog(
                      context: context,
                      title: entry.acronym,
                      content:
                          _buildAcronymDialogContent(entry.meanings.single),
                    ),
                  )
                : ctx.MenuItem<Object>.submenu(
                    label: Text(
                      entry.acronym,
                      textDirection: TextDirection.rtl,
                    ),
                    items: entry.meanings
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
                              title: entry.acronym,
                              content: _buildAcronymDialogContent(meaning),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          )
          .toList();

  return ctx.MenuItem<Object>.submenu(
    label: const Text(
      'פתיחת ראשי תיבות',
      textDirection: TextDirection.rtl,
    ),
    icon: const Icon(FluentIcons.text_quote_24_regular),
    items: items,
  );
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
