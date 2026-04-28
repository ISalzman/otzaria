const _bidiControlsPattern = r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]';

final _bidiControlsRegExp = RegExp(_bidiControlsPattern);
final _htmlTagsRegExp = RegExp(r'<[^>]+>');
final _supRegExp = RegExp(
  r'<sup\b[^>]*>(.*?)</sup>',
  dotAll: true,
  caseSensitive: false,
);
final _noteEntryRegExp = RegExp(
  r'<sup\b[^>]*>(.*?)</sup>(.*?)(?=<sup\b[^>]*>|$)',
  dotAll: true,
  caseSensitive: false,
);

/// מנרמל marker של הערת שוליים כדי להתעלם מתווי כיווניות בלתי נראים.
String normalizeNoteMarker(String marker) {
  return marker
      .replaceAll(_htmlTagsRegExp, '')
      .replaceAll(_bidiControlsRegExp, '')
      .trim();
}

/// מחלץ markers מתוך תגיות sup בטקסט הספר.
List<String> extractNoteMarkers(String htmlText) {
  return _supRegExp
      .allMatches(htmlText)
      .map((match) => normalizeNoteMarker(match.group(1)!))
      .where((marker) => marker.endsWith(')'))
      .toList();
}

/// מחזיר true אם הטקסט מכיל לפחות marker אחד של הערת שוליים.
bool hasNoteMarkers(String htmlText) {
  return extractNoteMarkers(htmlText).isNotEmpty;
}

/// מפרק notesContent למפה לפי marker מנורמל.
Map<String, String> parseNotesContent(String notesContent) {
  final result = <String, String>{};

  for (final match in _noteEntryRegExp.allMatches(notesContent)) {
    final marker = normalizeNoteMarker(match.group(1)!);
    final note = match.group(0)?.trim();
    if (marker.endsWith(')') && note != null && note.isNotEmpty) {
      result[marker] = note;
    }
  }

  return result;
}

/// מחזיר את ההערות השייכות לשורות הספר המבוקשות.
List<String> notesForIndexes({
  required List<String> content,
  required Iterable<int> indexes,
  required Map<String, String> notesByMarker,
}) {
  final currentText = indexes
      .where((index) => index >= 0 && index < content.length)
      .map((index) => content[index])
      .join('\n');

  return extractNoteMarkers(currentText)
      .map((marker) => notesByMarker[marker])
      .whereType<String>()
      .toList();
}
