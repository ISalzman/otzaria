import 'dart:math';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/search/utils/regex_patterns.dart';

class _SnippetMatchRange {
  final int start;
  final int end;

  const _SnippetMatchRange(this.start, this.end);
}

class _ApproximateSnippetMatchCandidate {
  final _SnippetMatchRange range;
  final int distance;

  const _ApproximateSnippetMatchCandidate({
    required this.range,
    required this.distance,
  });
}

class SnippetBuilder {
  /// פונקציה לחישוב כמה תווים יכולים להיכנס בשורה אחת
  static int calculateCharsPerLine(double availableWidth, TextStyle textStyle) {
    final textPainter = TextPainter(
      text: TextSpan(text: 'א' * 100, style: textStyle),
      textDirection: TextDirection.rtl,
    );
    textPainter.layout(maxWidth: availableWidth);

    final singleCharWidth = textPainter.width / 100;
    final charsPerLine = (availableWidth / singleCharWidth).floor();

    textPainter.dispose();
    return charsPerLine;
  }

  /// פונקציה חכמה ליצירת קטע טקסט עם הדגשות - מבטיחה שכל ההתאמות יופיעו!
  static List<InlineSpan> createSnippetSpans({
    required String fullHtml,
    required String query,
    required TextStyle defaultStyle,
    required TextStyle highlightStyle,
    required double availableWidth,
    required Map<String, Map<String, bool>> searchOptions,
    required Map<int, List<String>> alternativeWords,
    Map<String, String> customSpacing = const {},
  }) {
    // 1. קבלת הטקסט הנקי מה-HTML
    var plainText =
        html_parser.parse(fullHtml).documentElement?.text.trim() ?? '';

    // 2. חילוץ מילות החיפוש כולל מילים חילופיות
    final originalWords = query
        .trim()
        .replaceAll(RegExp(r'[!?":*\(\)\[\]\{\}\^\$\|\\+.~`~]'), ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    // הוספת מילים חילופיות ווריאציות כתיב מלא/חסר למילות החיפוש
    // termsByWord: רשימת רשימות - עבור כל מילת חיפוש, כל הווריאציות שלה
    final termsByWord = <List<String>>[];
    for (int i = 0; i < originalWords.length; i++) {
      final word = originalWords[i];
      final wordKey = '${word}_$i';
      final wordTerms = <String>[];

      // בדיקת אפשרויות החיפוש למילה הזו
      final wordOptions = searchOptions[wordKey] ?? {};
      final hasFullPartialSpelling = wordOptions['כתיב מלא/חסר'] == true;

      if (hasFullPartialSpelling) {
        // אם יש כתיב מלא/חסר, נוסיף את כל הווריאציות
        try {
          final variations =
              SearchRegexPatterns.generateFullPartialSpellingVariations(word);
          wordTerms.addAll(variations);
        } catch (e) {
          // אם יש בעיה, נוסיף לפחות את המילה המקורית
          wordTerms.add(word);
        }
      } else {
        // אם אין כתיב מלא/חסר, נוסיף את המילה המקורית
        wordTerms.add(word);
      }

      // הוספת מילים חילופיות אם יש
      final alternatives = alternativeWords[i];
      if (alternatives != null && alternatives.isNotEmpty) {
        if (hasFullPartialSpelling) {
          // אם יש כתיב מלא/חסר, נוסיף גם את הווריאציות של המילים החילופיות
          for (final alt in alternatives) {
            try {
              final altVariations =
                  SearchRegexPatterns.generateFullPartialSpellingVariations(
                      alt);
              wordTerms.addAll(altVariations);
            } catch (e) {
              wordTerms.add(alt);
            }
          }
        } else {
          wordTerms.addAll(alternatives);
        }
      }

      termsByWord.add(wordTerms);
    }

    // רשימה שטוחה - לשימוש בחיפוש מקורב
    final searchTerms = termsByWord.expand((t) => t).toList();

    if (searchTerms.isEmpty || plainText.isEmpty) {
      return [TextSpan(text: plainText, style: defaultStyle)];
    }

    // 3. מציאת כל ההתאמות של כל המילים בטקסט המקורי
    // שימוש ב-phrase matching: מדגישים רק הופעות שבהן כל המילים מופיעות ברצף,
    // כך שהופעות בודדות-מרוחקות לא מקבלות הדגשה מוטעית
    final exactMatches = _collectPhraseWordMatches(plainText, termsByWord,
        customSpacing: customSpacing);
    final approxMatches =
        SearchQueryBuilder.hasTypoToleranceEnabled(searchOptions)
            ? _collectApproximateMatches(plainText, searchTerms,
                existingMatches: exactMatches)
            : const <_ApproximateSnippetMatchCandidate>[];

    final selectedApprox = exactMatches.isNotEmpty
        ? _selectApproximateMatchesNearExactMatches(approxMatches, exactMatches)
        : _selectApproximateMatchesForSnippet(
            approxMatches,
            plainTextLength: plainText.length,
          );

    final allMatches =
        _mergeOverlappingRanges([...exactMatches, ...selectedApprox]);

    if (allMatches.isEmpty) {
      return [
        TextSpan(
          text: plainText.substring(0, min(200, plainText.length)),
          style: defaultStyle,
        ),
      ];
    }

    // 4. מיון ההתאמות וקביעת הגבולות המוחלטים
    final int absoluteFirstMatch = allMatches.first.start;
    final int absoluteLastMatch = allMatches.last.end;
    final int totalMatchesSpan = absoluteLastMatch - absoluteFirstMatch;

    // 5. קביעת הקטע - עקרון ברזל: כל ההתאמות חייבות להיכלל!
    int snippetStart;
    int snippetEnd;

    // חישוב אורך הטקסט הנדרש לשלוש שורות בהתבסס על רוחב המסך בפועל
    final charsPerLine = calculateCharsPerLine(availableWidth, defaultStyle);
    final targetLength = (charsPerLine * 3).clamp(120, 400);

    // תמיד מתחילים מהגבולות המוחלטים של ההתאמות
    snippetStart = absoluteFirstMatch;
    snippetEnd = absoluteLastMatch;

    if (totalMatchesSpan < 50) {
      // אם המילים קרובות מאוד (כולל מילה אחת)
      // נוסיף הקשר מוגבל - מקסימום 60 תווים מכל צד
      const limitedPadding = 60;
      snippetStart =
          (absoluteFirstMatch - limitedPadding).clamp(0, plainText.length);
      snippetEnd =
          (absoluteLastMatch + limitedPadding).clamp(0, plainText.length);
    } else if (totalMatchesSpan < targetLength) {
      // אם ההתאמות קצרות מהיעד, נוסיף הקשר עד שנגיע ל-3 שורות
      int remainingSpace = targetLength - totalMatchesSpan;
      int paddingBefore = remainingSpace ~/ 2;
      int paddingAfter = remainingSpace - paddingBefore;

      snippetStart =
          (absoluteFirstMatch - paddingBefore).clamp(0, plainText.length);
      snippetEnd =
          (absoluteLastMatch + paddingAfter).clamp(0, plainText.length);
    } else {
      // אם ההתאמות ארוכות, נוסיף רק מעט הקשר
      const minPadding = 30;
      snippetStart =
          (absoluteFirstMatch - minPadding).clamp(0, plainText.length);
      snippetEnd = (absoluteLastMatch + minPadding).clamp(0, plainText.length);
    }

    // התאמה לגבולות מילים - אבל לא על חשבון ההתאמות!
    if (snippetStart > 0 && snippetStart < absoluteFirstMatch) {
      int? spaceIndex = plainText.lastIndexOf(' ', snippetStart);
      if (spaceIndex != -1 && spaceIndex >= snippetStart - 50) {
        snippetStart = spaceIndex + 1;
      } else {
        while (snippetStart > 0 && plainText[snippetStart - 1] != ' ') {
          snippetStart--;
        }
      }
    }

    if (snippetEnd < plainText.length && snippetEnd > absoluteLastMatch) {
      int? spaceIndex = plainText.indexOf(' ', snippetEnd);
      if (spaceIndex != -1 && spaceIndex <= snippetEnd + 50) {
        snippetEnd = spaceIndex;
      } else {
        while (snippetEnd < plainText.length && plainText[snippetEnd] != ' ') {
          snippetEnd++;
        }
      }
    }

    if (snippetStart > absoluteFirstMatch) {
      snippetStart = absoluteFirstMatch;
    }
    if (snippetEnd < absoluteLastMatch) {
      snippetEnd = absoluteLastMatch;
    }

    final snippetText = plainText.substring(snippetStart, snippetEnd);

    // 6. בדיקה נוספת - ספירת ההתאמות בקטע הסופי
    final snippetMatches = allMatches
        .where(
            (match) => match.start >= snippetStart && match.end <= snippetEnd)
        .map((match) => _SnippetMatchRange(
            match.start - snippetStart, match.end - snippetStart))
        .toList();

    final int finalMatchCount = snippetMatches.length;

    if (finalMatchCount < allMatches.length) {
      snippetStart = (absoluteFirstMatch - 100).clamp(0, plainText.length);
      snippetEnd = (absoluteLastMatch + 100).clamp(0, plainText.length);
      final expandedSnippet = plainText.substring(snippetStart, snippetEnd);

      final expandedMatches = allMatches
          .where(
              (match) => match.start >= snippetStart && match.end <= snippetEnd)
          .map((match) => _SnippetMatchRange(
              match.start - snippetStart, match.end - snippetStart))
          .toList();

      if (expandedMatches.length >= allMatches.length) {
        return _buildTextSpans(
            expandedSnippet, expandedMatches, defaultStyle, highlightStyle);
      }
    }

    return _buildTextSpans(
        snippetText, snippetMatches, defaultStyle, highlightStyle);
  }

  /// מציאת התאמות ביטוי (phrase matching) בשיטת token-based:
  /// מוצאים רק הופעות שבהן כל המילים מופיעות ברצף כשמספר הטוקנים
  /// ביניהם <= customSpacing. תואם את סמנטיקת slop מנוע החיפוש.
  /// אם לא נמצא ביטוי - מחזיר רשימה ריקה (אין הדגשה), לא מחזיר בodim בודדות.
  static List<_SnippetMatchRange> _collectPhraseWordMatches(
    String plainText,
    List<List<String>> termsByWord, {
    Map<String, String> customSpacing = const {},
  }) {
    if (termsByWord.isEmpty) return const [];

    // 1. איסוף מקומות התאמות לכל מילה, ממוין לפי start
    final matchesByWord = termsByWord.map((wordTerms) {
      final wordMatches = <_SnippetMatchRange>[];
      for (final term in wordTerms) {
        final regex = RegExp(_termToRegexPattern(term), caseSensitive: false);
        for (final m in regex.allMatches(plainText)) {
          wordMatches.add(_SnippetMatchRange(m.start, m.end));
        }
      }
      wordMatches.sort((a, b) => a.start.compareTo(b.start));
      return wordMatches;
    }).toList();

    // מילה אחת - נחזיר את כל ההופעות
    if (termsByWord.length == 1) {
      return _mergeOverlappingRanges(matchesByWord[0]);
    }

    // 2. בניית רשימת תחילות הטוקנים (מילים לא-רווח) לספירת טוקנים בין היתורים
    final tokenStarts = <int>[];
    for (final m in RegExp(r'\S+').allMatches(plainText)) {
      tokenStarts.add(m.start);
    }

    // 3. Phrase matching: עבור כל הופעה של המילה הראשונה, בודק אם שאר המילים מופיעות ברצף
    final result = <_SnippetMatchRange>[];

    for (final firstMatch in matchesByWord[0]) {
      final phraseMatches = [firstMatch];
      int prevEnd = firstMatch.end;
      bool phraseValid = true;

      for (int wordIdx = 1; wordIdx < matchesByWord.length; wordIdx++) {
        final spacingKey = '${wordIdx - 1}-$wordIdx';
        final maxTokensBetween =
            int.tryParse(customSpacing[spacingKey] ?? '') ?? 0;

        _SnippetMatchRange? best;
        for (final candidate in matchesByWord[wordIdx]) {
          if (candidate.start < prevEnd) continue;
          final tokensBetween =
              _countTokensInRange(tokenStarts, prevEnd, candidate.start);
          if (tokensBetween > maxTokensBetween) {
            break; // רשימה ממוינת, break תקין
          }
          best = candidate;
          break; // נוצלים את הקרובה ביותר
        }

        if (best == null) {
          phraseValid = false;
          break;
        }
        phraseMatches.add(best);
        prevEnd = best.end;
      }

      if (phraseValid) {
        result.addAll(phraseMatches);
      }
    }

    // אם לא נמצא ביטוי - מחזירים רשימה ריקה. דע caller יבחר להציג קטע ללא הדגשה.
    // זה הוגן מהדגשת הופעות בודדות לא-קשורות.
    return _mergeOverlappingRanges(result);
  }

  /// ספירת טוקנים בטווח [fromPos, toPos) עם binary search.
  static int _countTokensInRange(
      List<int> sortedStarts, int fromPos, int toPos) {
    if (sortedStarts.isEmpty || toPos <= fromPos) return 0;

    int lo = 0, hi = sortedStarts.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (sortedStarts[mid] < fromPos) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final left = lo;

    lo = 0;
    hi = sortedStarts.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (sortedStarts[mid] < toPos) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final right = lo;

    return right - left;
  }

  static List<_ApproximateSnippetMatchCandidate> _collectApproximateMatches(
    String plainText,
    List<String> searchTerms, {
    required List<_SnippetMatchRange> existingMatches,
  }) {
    final matches = <_ApproximateSnippetMatchCandidate>[];
    final normalizedTerms = searchTerms
        .map(_normalizeForApproximateComparison)
        .where((term) => term.length >= 2)
        .toSet();

    if (normalizedTerms.isEmpty) {
      return matches;
    }

    final tokenRegex = RegExp(r'[א-תA-Za-z0-9"״׳]+');
    for (final tokenMatch in tokenRegex.allMatches(plainText)) {
      if (_overlapsExistingMatch(
          tokenMatch.start, tokenMatch.end, existingMatches)) {
        continue;
      }

      final token = tokenMatch.group(0) ?? '';
      final normalizedToken = _normalizeForApproximateComparison(token);
      if (normalizedToken.length < 2) {
        continue;
      }

      final distance = normalizedTerms
          .map((term) => _editDistanceUpToOne(normalizedToken, term))
          .whereType<int>()
          .fold<int?>(null, (best, current) {
        if (best == null || current < best) {
          return current;
        }
        return best;
      });

      if (distance != null) {
        matches.add(
          _ApproximateSnippetMatchCandidate(
            range: _SnippetMatchRange(tokenMatch.start, tokenMatch.end),
            distance: distance,
          ),
        );
      }
    }

    return matches;
  }

  static List<_SnippetMatchRange> _selectApproximateMatchesForSnippet(
    List<_ApproximateSnippetMatchCandidate> candidates, {
    required int plainTextLength,
  }) {
    if (candidates.isEmpty) {
      return const [];
    }

    const clusterRadius = 90;
    final center = plainTextLength / 2;

    final sortedCandidates = [...candidates]..sort((left, right) {
        final distanceCompare = left.distance.compareTo(right.distance);
        if (distanceCompare != 0) {
          return distanceCompare;
        }

        final leftCenter = (left.range.start + left.range.end) / 2;
        final rightCenter = (right.range.start + right.range.end) / 2;
        final centerCompare =
            (leftCenter - center).abs().compareTo((rightCenter - center).abs());
        if (centerCompare != 0) {
          return centerCompare;
        }

        return left.range.start.compareTo(right.range.start);
      });

    final anchor = sortedCandidates.first;
    final anchorCenter = (anchor.range.start + anchor.range.end) / 2;

    final cluster = sortedCandidates
        .where((candidate) {
          final candidateCenter =
              (candidate.range.start + candidate.range.end) / 2;
          return (candidateCenter - anchorCenter).abs() <= clusterRadius;
        })
        .map((candidate) => candidate.range)
        .toList();

    return _mergeOverlappingRanges(cluster);
  }

  static List<_SnippetMatchRange> _selectApproximateMatchesNearExactMatches(
    List<_ApproximateSnippetMatchCandidate> candidates,
    List<_SnippetMatchRange> exactMatches,
  ) {
    if (candidates.isEmpty || exactMatches.isEmpty) {
      return const [];
    }

    const clusterRadius = 90;
    final nearbyRanges = candidates
        .where((candidate) {
          final candidateCenter =
              (candidate.range.start + candidate.range.end) / 2;
          return exactMatches.any((exactMatch) {
            final exactCenter = (exactMatch.start + exactMatch.end) / 2;
            return (candidateCenter - exactCenter).abs() <= clusterRadius;
          });
        })
        .map((candidate) => candidate.range)
        .toList();

    return _mergeOverlappingRanges(nearbyRanges);
  }

  static List<_SnippetMatchRange> _mergeOverlappingRanges(
    List<_SnippetMatchRange> ranges,
  ) {
    if (ranges.isEmpty) {
      return const [];
    }

    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_SnippetMatchRange>[sorted.first];

    for (final range in sorted.skip(1)) {
      final previous = merged.last;
      if (range.start <= previous.end) {
        merged[merged.length - 1] =
            _SnippetMatchRange(previous.start, max(previous.end, range.end));
      } else {
        merged.add(range);
      }
    }

    return merged;
  }

  static bool _overlapsExistingMatch(
    int start,
    int end,
    List<_SnippetMatchRange> existingMatches,
  ) {
    return existingMatches
        .any((match) => start < match.end && end > match.start);
  }

  static String _normalizeForApproximateComparison(String text) {
    return text
        .replaceAll(RegExp(r'[\u0591-\u05C7]'), '')
        .replaceAll(RegExp("[\"״׳' ]"), '')
        .trim()
        .toLowerCase();
  }

  static int? _editDistanceUpToOne(String left, String right) {
    if (left == right) {
      return 0;
    }

    final lengthDifference = (left.length - right.length).abs();
    if (lengthDifference > 1) {
      return null;
    }

    if (left.length == right.length &&
        _isSingleAdjacentTransposition(left, right)) {
      return 1;
    }

    final shorter = left.length <= right.length ? left : right;
    final longer = left.length <= right.length ? right : left;

    int shortIndex = 0;
    int longIndex = 0;
    int edits = 0;

    while (shortIndex < shorter.length && longIndex < longer.length) {
      if (shorter[shortIndex] == longer[longIndex]) {
        shortIndex++;
        longIndex++;
        continue;
      }

      edits++;
      if (edits > 1) {
        return null;
      }

      if (shorter.length == longer.length) {
        shortIndex++;
      }
      longIndex++;
    }

    if (shortIndex < shorter.length || longIndex < longer.length) {
      edits++;
    }

    return edits <= 1 ? edits : null;
  }

  static bool _isSingleAdjacentTransposition(String left, String right) {
    int mismatchIndex = -1;

    for (int i = 0; i < left.length; i++) {
      if (left[i] == right[i]) {
        continue;
      }

      if (mismatchIndex != -1) {
        return i == mismatchIndex + 1 &&
            left[mismatchIndex] == right[i] &&
            left[i] == right[mismatchIndex] &&
            left.substring(i + 1) == right.substring(i + 1);
      }

      mismatchIndex = i;
    }

    return false;
  }

  /// בניית תבנית רגקס שמאפשרת מרכאות אופציונליות בין תווים (כדי למצוא רשב"י כשמחפשים רשבי)
  static String _termToRegexPattern(String term) {
    const optionalQuotes = r'["״׳]?';
    return term.split('').map(RegExp.escape).join(optionalQuotes);
  }

  static List<InlineSpan> _buildTextSpans(
    String text,
    List<_SnippetMatchRange> matches,
    TextStyle defaultStyle,
    TextStyle highlightStyle,
  ) {
    final List<InlineSpan> spans = [];
    int currentPosition = 0;

    for (final match in matches) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, match.start),
          style: defaultStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ));
      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: defaultStyle,
      ));
    }

    return spans;
  }
}
