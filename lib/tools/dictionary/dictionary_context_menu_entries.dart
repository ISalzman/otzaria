import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' as ctx;
import 'package:otzaria/tools/dictionary/repository/dictionary_lookup_repository.dart';

/// בונה פריטי תפריט הקשר למילונים על סמך הטקסט המסומן.
List<ctx.ContextMenuEntry<Object>> buildDictionaryContextMenuEntries({
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
                label: Text(
                  meaning,
                  textDirection: TextDirection.rtl,
                ),
                onSelected: (_) {},
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
              label: Text(
                '${entry.aramaic} - ${entry.hebrew}',
                textDirection: TextDirection.rtl,
              ),
              onSelected: (_) {},
            ),
          )
          .toList(),
    ),
  ];
}
