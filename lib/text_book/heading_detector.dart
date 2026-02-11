import 'package:otzaria/models/heading.dart';

/// מנוע לזיהוי כותרות מטקסט מודגש
class HeadingDetector {
  /// מזהה כותרות מטקסט HTML עם תגיות מודגשות
  ///
  /// [htmlContent] - תוכן HTML של הספר
  /// [maxWords] - מספר מילים מקסימלי לכותרת (ברירת מחדל: 20)
  /// [headingLevel] - רמת הכותרת שתוקצה (ברירת מחדל: 6)
  /// [allowUnboldedEdges] - אפשר מילה ראשונה/אחרונה לא מודגשת (ברירת מחדל: true)
  ///
  /// מחזיר רשימת כותרות שזוהו
  List<Heading> detectFromBoldText(
    String htmlContent, {
    int maxWords = 20,
    int headingLevel = 6,
    bool allowUnboldedEdges = true,
  }) {
    final headings = <Heading>[];

    // דפוסים לזיהוי טקסט מודגש
    final patterns = [
      RegExp(r'<b>(.*?)</b>', caseSensitive: false, dotAll: true),
      RegExp(r'<strong>(.*?)</strong>', caseSensitive: false, dotAll: true),
      RegExp(r'<em>(.*?)</em>', caseSensitive: false, dotAll: true),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(htmlContent)) {
        final text = match.group(1) ?? '';

        // נקה את הטקסט מתגיות HTML נוספות
        final cleanText = _cleanHtmlTags(text);

        // ספור מילים
        final wordCount = _countHebrewWords(cleanText);

        // אם מספר המילים בטווח המתאים, הוסף ככותרת
        if (wordCount > 0 && wordCount <= maxWords) {
          headings.add(Heading(
            text: cleanText.trim(),
            level: headingLevel,
            position: match.start,
            source: HeadingSource.automatic,
            createdAt: DateTime.now(),
          ));
        }
      }
    }

    // אם מותר, חפש גם כותרות עם מילה ראשונה/אחרונה לא מודגשת
    if (allowUnboldedEdges) {
      headings.addAll(_detectWithUnboldedEdges(
        htmlContent,
        maxWords: maxWords,
        headingLevel: headingLevel,
      ));
    }

    // הסר כפילויות (אותו טקסט באותו מיקום)
    return _removeDuplicates(headings);
  }

  /// מזהה כותרות מטקסט Markdown
  ///
  /// [markdownContent] - תוכן Markdown של הספר
  /// [maxWords] - מספר מילים מקסימלי לכותרת
  /// [headingLevel] - רמת הכותרת שתוקצה
  List<Heading> detectFromMarkdown(
    String markdownContent, {
    int maxWords = 20,
    int headingLevel = 6,
  }) {
    final headings = <Heading>[];

    // דפוסים לזיהוי טקסט מודגש ב-Markdown
    final patterns = [
      RegExp(r'\*\*(.*?)\*\*', dotAll: true), // **bold**
      RegExp(r'__(.*?)__', dotAll: true), // __bold__
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(markdownContent)) {
        final text = match.group(1) ?? '';
        final wordCount = _countHebrewWords(text);

        if (wordCount > 0 && wordCount <= maxWords) {
          headings.add(Heading(
            text: text.trim(),
            level: headingLevel,
            position: match.start,
            source: HeadingSource.automatic,
            createdAt: DateTime.now(),
          ));
        }
      }
    }

    return _removeDuplicates(headings);
  }

  /// מזהה כותרות עם מילה ראשונה או אחרונה לא מודגשת
  ///
  /// דוגמאות:
  /// - "מילה <b>כותרת מודגשת</b>"
  /// - "<b>כותרת מודגשת</b> מילה"
  /// - "מילה <b>כותרת מודגשת</b> מילה"
  List<Heading> _detectWithUnboldedEdges(
    String htmlContent, {
    required int maxWords,
    required int headingLevel,
  }) {
    final headings = <Heading>[];

    // דפוס לזיהוי: מילה (אופציונלי) + טקסט מודגש + מילה (אופציונלי)
    // מילה = רצף של תווים שאינם רווח או תגית
    final patterns = [
      // מילה לפני + bold
      RegExp(
        r'(\S+)\s*<b>(.*?)</b>',
        caseSensitive: false,
        dotAll: true,
      ),
      // bold + מילה אחרי
      RegExp(
        r'<b>(.*?)</b>\s*(\S+)',
        caseSensitive: false,
        dotAll: true,
      ),
      // מילה לפני + bold + מילה אחרי
      RegExp(
        r'(\S+)\s*<b>(.*?)</b>\s*(\S+)',
        caseSensitive: false,
        dotAll: true,
      ),
      // אותו דבר עם strong
      RegExp(
        r'(\S+)\s*<strong>(.*?)</strong>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<strong>(.*?)</strong>\s*(\S+)',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'(\S+)\s*<strong>(.*?)</strong>\s*(\S+)',
        caseSensitive: false,
        dotAll: true,
      ),
      // אותו דבר עם em
      RegExp(
        r'(\S+)\s*<em>(.*?)</em>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'<em>(.*?)</em>\s*(\S+)',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        r'(\S+)\s*<em>(.*?)</em>\s*(\S+)',
        caseSensitive: false,
        dotAll: true,
      ),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(htmlContent)) {
        // בנה את הטקסט המלא מכל הקבוצות
        final parts = <String>[];
        for (int i = 1; i <= match.groupCount; i++) {
          final part = match.group(i);
          if (part != null && part.isNotEmpty) {
            parts.add(part);
          }
        }

        if (parts.isEmpty) continue;

        // נקה תגיות HTML
        final cleanParts = parts.map((p) => _cleanHtmlTags(p)).toList();
        final fullText = cleanParts.join(' ').trim();

        // ספור מילים
        final wordCount = _countHebrewWords(fullText);

        // בדוק שזה בטווח המתאים
        if (wordCount > 0 && wordCount <= maxWords) {
          // ודא שהחלק המודגש הוא לפחות מילה אחת
          final boldPart =
              cleanParts.length > 1 ? cleanParts[1] : cleanParts[0];
          final boldWordCount = _countHebrewWords(boldPart);

          if (boldWordCount > 0) {
            headings.add(Heading(
              text: fullText,
              level: headingLevel,
              position: match.start,
              source: HeadingSource.automatic,
              createdAt: DateTime.now(),
            ));
          }
        }
      }
    }

    return headings;
  }

  /// סופר מילים בטקסט עברי
  ///
  /// מטפל בניקוד, סימני פיסוק ורווחים
  int _countHebrewWords(String text) {
    // הסר ניקוד (U+0591 עד U+05C7)
    // הסר סימני פיסוק
    final cleaned = text
        .replaceAll(RegExp(r'[\u0591-\u05C7]'), '') // ניקוד
        .replaceAll(
            RegExp(r'[^\w\s\u0590-\u05FF]', unicode: true), ' '); // סימני פיסוק

    // פצל לפי רווחים
    final words = cleaned.split(RegExp(r'\s+'));

    // ספור רק מילים לא ריקות
    return words.where((w) => w.trim().isNotEmpty).length;
  }

  /// מנקה תגיות HTML מטקסט
  String _cleanHtmlTags(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // הסר כל תגיות HTML
        .replaceAll(RegExp(r'\s+'), ' ') // נרמל רווחים
        .trim();
  }

  /// מסיר כותרות כפולות (אותו טקסט באותו מיקום בערך)
  List<Heading> _removeDuplicates(List<Heading> headings) {
    final seen = <String, int>{};
    final unique = <Heading>[];

    for (final heading in headings) {
      final key = '${heading.text}_${heading.position ~/ 100}'; // קירוב מיקום
      if (!seen.containsKey(key)) {
        seen[key] = heading.position;
        unique.add(heading);
      }
    }

    // מיין לפי מיקום
    unique.sort((a, b) => a.position.compareTo(b.position));
    return unique;
  }

  /// בודק אם טקסט הוא כותרת פוטנציאלית
  ///
  /// מחזיר true אם הטקסט מתאים להיות כותרת
  bool isPotentialHeading(String text, {int maxWords = 20}) {
    final wordCount = _countHebrewWords(text);
    return wordCount > 0 && wordCount <= maxWords;
  }
}
