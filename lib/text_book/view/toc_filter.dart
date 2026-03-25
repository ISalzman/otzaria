import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

/// מחזירה עץ תוכן עניינים מסונן לפי טקסט החיפוש.
///
/// אם הטקסט מנורמל לריק (למשל רק ניקוד/רווחים), מוחזר עץ ריק.
List<TocEntry> filterTocEntriesForSearch(
  List<TocEntry> entries,
  String rawQuery,
) {
  final normalizedQuery = _normalizeQuery(rawQuery);
  if (normalizedQuery.isEmpty) return [];
  return _buildFilteredEntries(entries, normalizedQuery);
}

/// קובע אם צומת צריך להיות פתוח כברירת מחדל במצב חיפוש.
bool shouldExpandInSearch(bool? expandedFlag) => expandedFlag ?? true;

String _normalizeQuery(String rawQuery) {
  final sanitized = SearchQueryBuilder.sanitizeQuery(rawQuery).trim();
  return utils.removeVolwels(sanitized);
}

bool _isBookTitle(
  TocEntry entry,
  int depth,
  int index,
  bool isFirstEntry,
) {
  return (depth == 0 && index == 0) ||
      (entry.level <= 1 && index == 0 && isFirstEntry);
}

bool _matchesEntryOrDescendants(
  TocEntry entry,
  String query, {
  required int depth,
  required int index,
  required bool isFirstEntry,
}) {
  final isBookTitle = _isBookTitle(entry, depth, index, isFirstEntry);
  final entryText = utils.removeVolwels(entry.text);
  final selfMatches = !isBookTitle && entryText.contains(query);
  if (selfMatches) return true;

  for (int i = 0; i < entry.children.length; i++) {
    final child = entry.children[i];
    if (_matchesEntryOrDescendants(
      child,
      query,
      depth: depth + 1,
      index: i,
      isFirstEntry: false,
    )) {
      return true;
    }
  }

  return false;
}

List<TocEntry> _buildFilteredEntries(
  List<TocEntry> entries,
  String query, {
  int depth = 0,
  bool isFirstEntry = true,
  TocEntry? parent,
}) {
  final result = <TocEntry>[];

  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final isBookTitle = _isBookTitle(entry, depth, i, isFirstEntry);
    final entryText = utils.removeVolwels(entry.text);
    final selfMatches = !isBookTitle && entryText.contains(query);
    final hasMatchingDescendant = entry.children.asMap().entries.any((entry) {
      final childIndex = entry.key;
      final child = entry.value;
      return _matchesEntryOrDescendants(
        child,
        query,
        depth: depth + 1,
        index: childIndex,
        isFirstEntry: false,
      );
    });

    if (selfMatches || hasMatchingDescendant) {
      final cloned = TocEntry(
        text: entry.text,
        index: entry.index,
        level: entry.level,
        parent: parent,
      );
      cloned.children = _buildFilteredEntries(
        entry.children,
        query,
        depth: depth + 1,
        isFirstEntry: false,
        parent: cloned,
      );
      result.add(cloned);
    }
  }

  return result;
}
