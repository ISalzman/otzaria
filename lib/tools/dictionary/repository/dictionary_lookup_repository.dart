import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

/// מייצג התאמה במילון ראשי התיבות.
class AcronymDictionaryEntry {
  const AcronymDictionaryEntry({
    required this.acronym,
    required this.meanings,
  });

  final String acronym;
  final List<String> meanings;
}

/// מייצג רשומה במילון ארמי-עברי.
class AramaicDictionaryEntry {
  const AramaicDictionaryEntry({
    required this.aramaic,
    required this.hebrew,
  });

  final String aramaic;
  final String hebrew;
}

/// Repository משותף לטעינה וחיפוש במילוני הכלים.
class DictionaryLookupRepository {
  DictionaryLookupRepository({
    Future<Map<String, List<String>>> Function()? loadAcronyms,
    Future<List<AramaicDictionaryEntry>> Function()? loadAramaicEntries,
  })  : _loadAcronyms = loadAcronyms ?? _defaultLoadAcronyms,
        _loadAramaicEntries = loadAramaicEntries ?? _defaultLoadAramaicEntries;

  static final DictionaryLookupRepository instance =
      DictionaryLookupRepository();

  final Future<Map<String, List<String>>> Function() _loadAcronyms;
  final Future<List<AramaicDictionaryEntry>> Function() _loadAramaicEntries;

  Future<void>? _loadFuture;
  bool _isLoaded = false;

  Map<String, List<String>> _acronymsByKey = <String, List<String>>{};
  Map<String, String> _originalAcronymByKey = <String, String>{};
  List<AramaicDictionaryEntry> _aramaicEntries = <AramaicDictionaryEntry>[];
  Set<String> _aramaicTerms = <String>{};

  bool get isLoaded => _isLoaded;

  /// טוען את שני המילונים פעם אחת ומשאיר אותם בזיכרון.
  Future<void> ensureLoaded() {
    return _loadFuture ??= _loadInternal();
  }

  /// מחזיר את כלל רשומות ראשי התיבות.
  Map<String, List<String>> getAllAcronyms() {
    return Map<String, List<String>>.unmodifiable(_acronymsByKey.map(
      (key, meanings) => MapEntry(_originalAcronymByKey[key] ?? key, meanings),
    ));
  }

  /// מחזיר את כל רשומות המילון הארמי-עברי.
  List<AramaicDictionaryEntry> getAllAramaicEntries() {
    return List<AramaicDictionaryEntry>.unmodifiable(_aramaicEntries);
  }

  /// בודק אם הטקסט נראה כמו ראשי תיבות.
  bool isLikelyAcronym(String raw) {
    final trimmed = raw.trim();
    return trimmed.contains('"') || trimmed.contains('״');
  }

  /// מחזיר את כל הפירושים לראשי תיבות אם קיימים.
  AcronymDictionaryEntry? findAcronym(String raw) {
    final normalized = _normalizeAcronym(raw);
    if (normalized.isEmpty) return null;

    final meanings = _acronymsByKey[normalized];
    if (meanings == null || meanings.isEmpty) return null;

    return AcronymDictionaryEntry(
      acronym: _originalAcronymByKey[normalized] ?? raw.trim(),
      meanings: meanings,
    );
  }

  /// מחזיר את כל הביטויים הארמיים המכילים את המילה שנבחרה,
  /// אבל רק אם קיימת התאמה מילונית מדויקת למילה עצמה.
  List<AramaicDictionaryEntry> findAramaicMatches(String raw) {
    final normalizedWord = _normalizeAramaic(raw);
    if (normalizedWord.isEmpty) return const <AramaicDictionaryEntry>[];
    if (!_aramaicTerms.contains(normalizedWord)) {
      return const <AramaicDictionaryEntry>[];
    }

    final exact = <AramaicDictionaryEntry>[];
    final containsAsWord = <AramaicDictionaryEntry>[];

    for (final entry in _aramaicEntries) {
      final normalizedEntry = _normalizeAramaic(entry.aramaic);
      if (normalizedEntry == normalizedWord) {
        exact.add(entry);
        continue;
      }

      final words = _splitAramaicWords(normalizedEntry);
      if (words.contains(normalizedWord)) {
        containsAsWord.add(entry);
      }
    }

    return <AramaicDictionaryEntry>[
      ...exact,
      ...containsAsWord,
    ];
  }

  Future<void> _loadInternal() async {
    final acronyms = await _loadAcronyms();
    final aramaicEntries = await _loadAramaicEntries();

    final normalizedAcronyms = <String, List<String>>{};
    final originalAcronyms = <String, String>{};

    acronyms.forEach((acronym, meanings) {
      final normalized = _normalizeAcronym(acronym);
      if (normalized.isEmpty || meanings.isEmpty) return;
      normalizedAcronyms[normalized] = List<String>.unmodifiable(meanings);
      originalAcronyms[normalized] = acronym;
    });

    final aramaicTerms = <String>{};
    for (final entry in aramaicEntries) {
      final normalizedEntry = _normalizeAramaic(entry.aramaic);
      if (normalizedEntry.isEmpty) {
        continue;
      }

      aramaicTerms.add(normalizedEntry);
      aramaicTerms.addAll(_splitAramaicWords(normalizedEntry));
    }

    _acronymsByKey = normalizedAcronyms;
    _originalAcronymByKey = originalAcronyms;
    _aramaicEntries = List<AramaicDictionaryEntry>.unmodifiable(aramaicEntries);
    _aramaicTerms = Set<String>.unmodifiable(aramaicTerms);
    _isLoaded = true;
  }

  static Future<Map<String, List<String>>> _defaultLoadAcronyms() async {
    final String jsonString =
        await rootBundle.loadString('assets/Acronyms.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((key, value) {
      if (value is List) {
        return MapEntry(key, value.cast<String>());
      }

      return MapEntry(key, <String>[]);
    });
  }

  static Future<List<AramaicDictionaryEntry>>
      _defaultLoadAramaicEntries() async {
    final String jsonString =
        await rootBundle.loadString('assets/dictionary.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final List<dynamic> entries = jsonData['מילון פשיטא'] ?? <dynamic>[];

    return entries
        .whereType<Map<String, dynamic>>()
        .map((entry) {
          if (entry.isEmpty) {
            return null;
          }

          final aramaic = entry.keys.first;

          return AramaicDictionaryEntry(
            aramaic: aramaic,
            hebrew: entry[aramaic].toString(),
          );
        })
        .whereType<AramaicDictionaryEntry>()
        .toList();
  }

  static String _normalizeAcronym(String raw) {
    final compact = _trimDecorations(raw)
        .replaceAll('״', '"')
        .replaceAll('׳', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');

    return _normalizeCommon(compact, keepQuotes: true);
  }

  static String _normalizeAramaic(String raw) {
    return _normalizeCommon(_trimDecorations(raw), keepQuotes: false);
  }

  static String _normalizeCommon(String raw, {required bool keepQuotes}) {
    var normalized = utils.removeVolwels(raw).trim();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    if (!keepQuotes) {
      normalized = normalized
          .replaceAll('"', '')
          .replaceAll('״', '')
          .replaceAll("'", '')
          .replaceAll('׳', '');
    }

    return normalized;
  }

  static String _trimDecorations(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp("^[^א-ת\"״׳']+"), '')
        .replaceAll(RegExp("[^א-ת\"״׳'\\s]+\$"), '');
  }

  static Set<String> _splitAramaicWords(String normalizedEntry) {
    return normalizedEntry
        .split(RegExp(r'[\s\-]+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toSet();
  }
}
