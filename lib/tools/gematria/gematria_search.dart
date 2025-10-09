import 'dart:io';
import 'dart:convert';

class SearchResult {
  final String file;
  final int line;
  final String text;
  const SearchResult({required this.file, required this.line, required this.text});
}

class GimatriaSearch {
  static const Map<String, int> _values = {
    'א': 1, 'ב': 2, 'ג': 3, 'ד': 4, 'ה': 5, 'ו': 6, 'ז': 7, 'ח': 8, 'ט': 9,
    'י': 10, 'כ': 20, 'ך': 20, 'ל': 30, 'מ': 40, 'ם': 40, 'נ': 50, 'ן': 50,
    'ס': 60, 'ע': 70, 'פ': 80, 'ף': 80, 'צ': 90, 'ץ': 90,
    'ק': 100, 'ר': 200, 'ש': 300, 'ת': 400
  };

  static int gimatria(String text) {
    var sum = 0;
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      final v = _values[ch];
      if (v != null) sum += v;
    }
    return sum;
  }

  /// Search plain .txt files under [folder] (recursive) for phrases whose
  /// gimatria equals [targetGimatria].
  /// [maxPhraseWords] bounds phrase length to avoid explosion.
  static Future<List<SearchResult>> searchInFiles(String folder, int targetGimatria,
      {int maxPhraseWords = 8, int fileLimit = 1000, bool debug = false}) async {
    final List<SearchResult> found = [];
    final dir = Directory(folder);
    if (!await dir.exists()) return found;

    final files = dir
        .list(recursive: true, followLinks: false)
        .where((e) => e is File && e.path.toLowerCase().endsWith('.txt'))
        .cast<File>();

    await for (final file in files) {
      try {
        // קריאה בטקסט UTF-8 (עם חלופה לקבצים לא תקינים)
        final String content = await file.readAsString(encoding: utf8);
        final lines = const LineSplitter().convert(content);

        if (debug) {
          // הדפס קובץ ונקודות בדיקה מהירות
          print('Scanning file: ${file.path} (lines: ${lines.length})');
        }

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final words = line.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
          if (words.isEmpty) continue;
          final wordValues = words.map((w) => gimatria(w)).toList();
          for (int start = 0; start < words.length; start++) {
            int acc = 0;
            for (int offset = 0; offset < maxPhraseWords && start + offset < words.length; offset++) {
              acc += wordValues[start + offset];
              if (acc == targetGimatria) {
                final phrase = words.sublist(start, start + offset + 1).join(' ');
                found.add(SearchResult(file: file.path, line: i + 1, text: phrase));
                if (found.length >= fileLimit) return found;
              } else if (acc > targetGimatria) {
                break;
              }
            }
          }
        }
      } catch (e) {
        if (debug) print('Skipped file ${file.path} due to read error: $e');
        continue;
      }
      if (found.length >= fileLimit) break;
    }
    return found;
  }
}
