/// כלים לעיגון הערות אישיות למילים ספציפיות בתוך שורה.
///
/// השורה הגולמית מכילה HTML וניקוד/טעמים, בעוד שהטקסט שנבחר נשמר מנורמל
/// (בלי ניקוד, רווחים מכווצים). כדי לסמן את המילים במקומן צריך:
/// 1. להקרין את השורה הגולמית למחרוזת מנורמלת + מפת אינדקסים חזרה לגולמי
///    ([projectLine]).
/// 2. לאתר את הביטוי המנורמל בתוך ההקרנה, תוך שימוש בהקשר (prefix/suffix)
///    לבחירת המופע הנכון כשהטקסט חוזר ([locateAnchor]).
/// 3. להזריק תגיות עיטוף ל-HTML בטווחים שנמצאו ([wrapHtmlRanges]).
library;

import 'package:otzaria/personal_notes/utils/note_text_utils.dart';

/// תוצאת הקרנת שורה גולמית לטקסט מנורמל.
class LineProjection {
  /// הטקסט המנורמל: בלי תגיות HTML, בלי ניקוד/טעמים, רווחים מכווצים לרווח יחיד.
  final String normalized;

  /// מיפוי מאינדקס בטקסט המנורמל לאינדקס המתאים בשורה הגולמית.
  /// האורך הוא `normalized.length + 1`; הערך האחרון מצביע אל סוף האזור התורם.
  final List<int> rawIndex;

  const LineProjection(this.normalized, this.rawIndex);
}

// מקף עברי (U+05BE) נמצא בטווח הניקוד/טעמים אך אינו ניקוד — הוא מטופל כרווח
// (כמו ב-removeHebrewDiacritics), לכן הוא מוחרג מבדיקת הניקוד.
bool _isDiacritic(int code) =>
    code >= 0x0591 && code <= 0x05C7 && code != 0x05BE;

/// מקרין שורה גולמית (HTML+ניקוד) למחרוזת מנורמלת עם מפת אינדקסים חזרה.
LineProjection projectLine(String rawLine) {
  final buffer = StringBuffer();
  final rawIndex = <int>[];
  bool inTag = false;
  bool pendingWhitespace = false;
  int pendingWhitespaceRawStart = 0;

  void flushWhitespace() {
    if (pendingWhitespace) {
      rawIndex.add(pendingWhitespaceRawStart);
      buffer.write(' ');
      pendingWhitespace = false;
    }
  }

  for (int i = 0; i < rawLine.length; i++) {
    final ch = rawLine[i];
    final code = rawLine.codeUnitAt(i);

    if (inTag) {
      if (ch == '>') inTag = false;
      continue;
    }
    if (ch == '<') {
      inTag = true;
      continue;
    }

    // ניקוד וטעמים — מושמטים לחלוטין.
    if (_isDiacritic(code)) continue;

    // מקף עברי (מקף) ורווחים — מכווצים לרווח יחיד.
    final isWhitespace = code == 0x05BE || ch.trim().isEmpty;
    if (isWhitespace) {
      if (!pendingWhitespace) {
        pendingWhitespace = true;
        pendingWhitespaceRawStart = i;
      }
      continue;
    }

    flushWhitespace();
    rawIndex.add(i);
    buffer.write(ch);
  }

  // רווח בסוף נשמר במפה (כדי שאורך המפה יהיה עקבי) אך לא נכלל בטקסט —
  // למעשה אנו פשוט מתעלמים ממנו ומסיימים את המפה בסוף השורה.
  rawIndex.add(rawLine.length);
  return LineProjection(buffer.toString(), rawIndex);
}

/// מנרמל טקסט שנבחר לצורך חיפוש: הסרת ניקוד, כיווץ רווחים וקיצוץ.
String normalizeAnchorText(String text) {
  final withoutNikud = removeHebrewDiacritics(text);
  return withoutNikud.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// טווח עוגן בשורה הגולמית (offset של תווים).
class NoteAnchorRange {
  final int start;
  final int end;

  const NoteAnchorRange(this.start, this.end);
}

/// תוצאה מלאה של חישוב עוגן בעת היצירה — כולל הקשר לשמירה.
class ComputedAnchor {
  final int start;
  final int end;
  final String prefix;
  final String suffix;

  const ComputedAnchor({
    required this.start,
    required this.end,
    required this.prefix,
    required this.suffix,
  });
}

const int _kContextLength = 24;

/// מאתר את כל המופעים של [needle] בתוך [haystack] (חיפוש פשוט, ללא חפיפה).
List<int> _allOccurrences(String haystack, String needle) {
  final result = <int>[];
  if (needle.isEmpty) return result;
  int from = 0;
  while (true) {
    final idx = haystack.indexOf(needle, from);
    if (idx < 0) break;
    result.add(idx);
    from = idx + needle.length;
  }
  return result;
}

/// מודד את אורך ההתאמה בין סיומת [context] לבין הטקסט שלפני מופע (prefix),
/// או בין תחילת [context] לטקסט שאחרי מופע (suffix).
int _contextScore(String have, String want, {required bool matchTail}) {
  if (want.isEmpty || have.isEmpty) return 0;
  final maxLen = have.length < want.length ? have.length : want.length;
  int score = 0;
  for (int k = 1; k <= maxLen; k++) {
    final a = matchTail ? have[have.length - k] : have[k - 1];
    final b = matchTail ? want[want.length - k] : want[k - 1];
    if (a == b) {
      score++;
    } else {
      break;
    }
  }
  return score;
}

/// בוחר את המופע המתאים ביותר מבין [occurrences] לפי הקשר ורמז מיקום.
int _pickBestOccurrence(
  String normalized,
  List<int> occurrences,
  int needleLen,
  String? prefix,
  String? suffix,
  int? normalizedHint,
) {
  if (occurrences.length == 1) return occurrences.first;

  int bestIdx = occurrences.first;
  int bestScore = -1;
  for (final idx in occurrences) {
    final before = normalized.substring(0, idx);
    final after = normalized.substring(idx + needleLen);
    int score = 0;
    if (prefix != null && prefix.isNotEmpty) {
      score += _contextScore(before, prefix, matchTail: true);
    }
    if (suffix != null && suffix.isNotEmpty) {
      score += _contextScore(after, suffix, matchTail: false);
    }
    // שובר שוויון: קרבה לרמז המיקום (ככל שקרוב יותר — עדיף).
    if (score == bestScore && normalizedHint != null) {
      if ((idx - normalizedHint).abs() < (bestIdx - normalizedHint).abs()) {
        bestIdx = idx;
      }
    } else if (score > bestScore) {
      bestScore = score;
      bestIdx = idx;
    }
  }
  return bestIdx;
}

/// ממפה אינדקס בטקסט המנורמל לאינדקס המתאים ברמז הגולמי הקרוב ביותר.
int? _rawToNormalizedIndex(LineProjection p, int rawHint) {
  if (rawHint <= 0) return 0;
  for (int i = 0; i < p.normalized.length; i++) {
    if (p.rawIndex[i] >= rawHint) return i;
  }
  return p.normalized.length;
}

/// מאתר את טווח הביטוי בשורה הגולמית.
///
/// [anchorText] הוא הטקסט המנורמל שנבחר. [prefix]/[suffix] הם הקשר מנורמל
/// לבחירת המופע הנכון. [hintStart] הוא offset גולמי משוער (fast-path).
NoteAnchorRange? locateAnchor({
  required String rawLine,
  required String anchorText,
  String? prefix,
  String? suffix,
  int? hintStart,
}) {
  final needle = normalizeAnchorText(anchorText);
  if (needle.isEmpty) return null;

  final p = projectLine(rawLine);
  final occurrences = _allOccurrences(p.normalized, needle);
  if (occurrences.isEmpty) return null;

  final normalizedHint =
      hintStart != null ? _rawToNormalizedIndex(p, hintStart) : null;
  final matchStart = _pickBestOccurrence(
    p.normalized,
    occurrences,
    needle.length,
    prefix,
    suffix,
    normalizedHint,
  );
  final matchEnd = matchStart + needle.length;

  final rawStart = p.rawIndex[matchStart];
  final rawEnd = p.rawIndex[matchEnd];
  if (rawStart < 0 || rawEnd > rawLine.length || rawStart >= rawEnd) {
    return null;
  }
  return NoteAnchorRange(rawStart, rawEnd);
}

/// מחשב עוגן (טווח + הקשר) עבור טקסט שנבחר, לשמירה בעת יצירת ההערה.
///
/// [selectionColumnHint] הוא עמודת ההתחלה המשוערת של הבחירה (במרחב המרונדר,
/// בלי ניקוד) — כשהביטוי חוזר באותה שורה, נבחר המופע הקרוב ביותר לעמודה זו
/// במקום המופע הראשון. בלי רמז — נבחר המופע הראשון.
ComputedAnchor? computeAnchorForSelection({
  required String rawLine,
  required String selectedText,
  int? selectionColumnHint,
}) {
  final needle = normalizeAnchorText(selectedText);
  if (needle.isEmpty) return null;

  final p = projectLine(rawLine);
  final occurrences = _allOccurrences(p.normalized, needle);
  if (occurrences.isEmpty) return null;

  int matchStart = occurrences.first;
  if (selectionColumnHint != null && occurrences.length > 1) {
    int bestDist = (occurrences.first - selectionColumnHint).abs();
    for (final idx in occurrences.skip(1)) {
      final dist = (idx - selectionColumnHint).abs();
      if (dist < bestDist) {
        bestDist = dist;
        matchStart = idx;
      }
    }
  }
  final matchEnd = matchStart + needle.length;

  final prefixStart =
      (matchStart - _kContextLength) < 0 ? 0 : matchStart - _kContextLength;
  final suffixEnd = (matchEnd + _kContextLength) > p.normalized.length
      ? p.normalized.length
      : matchEnd + _kContextLength;

  return ComputedAnchor(
    start: p.rawIndex[matchStart],
    end: p.rawIndex[matchEnd],
    prefix: p.normalized.substring(prefixStart, matchStart),
    suffix: p.normalized.substring(matchEnd, suffixEnd),
  );
}

/// טווח עיטוף ב-HTML.
class HtmlWrapRange {
  final int start;
  final int end;
  final String openTag;
  final String closeTag;

  const HtmlWrapRange({
    required this.start,
    required this.end,
    required this.openTag,
    required this.closeTag,
  });
}

/// עוטף טווחי תווים ב-HTML בתגיות שסופקו, בפעולה אחת.
///
/// הטווחים ממוינים לפי תחילתם; טווחים חופפים מדולגים (הראשון מנצח).
String wrapHtmlRanges(String text, List<HtmlWrapRange> ranges) {
  if (ranges.isEmpty || text.isEmpty) return text;

  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));

  final buffer = StringBuffer();
  int currentPos = 0;

  for (final range in sorted) {
    if (range.start < 0 ||
        range.end > text.length ||
        range.start >= range.end) {
      continue;
    }
    if (range.start < currentPos) {
      continue; // חפיפה — מדלגים.
    }
    if (range.start > currentPos) {
      buffer.write(text.substring(currentPos, range.start));
    }
    buffer.write(range.openTag);
    buffer.write(text.substring(range.start, range.end));
    buffer.write(range.closeTag);
    currentPos = range.end;
  }

  if (currentPos < text.length) {
    buffer.write(text.substring(currentPos));
  }

  return buffer.toString();
}
