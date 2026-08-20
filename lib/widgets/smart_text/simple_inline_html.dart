import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:otzaria/theme/app_fonts.dart';
import 'package:otzaria/widgets/smart_text/raised_markers.dart';

/// יחסי הגדלים של fwfh ל-`<small>`/`<sup>` ול-`<big>`.
///
/// שלושת מסלולי הרינדור — המסלול המהיר כאן, HtmlWidget, והקריאה הרציפה —
/// חייבים להתלכד עליהם: כל טקסט בסוגריים נעטף ב-`<small>`, ולכן פער ביחס
/// משנה את גודל הסוגריים לפי המסלול שבו השורה במקרה עברה.
const double kHtmlSmallerFontScale = 5 / 6;
const double kHtmlLargerFontScale = 6 / 5;

/// ממיר HTML פשוט (טקסט + תגי עיצוב בסיסיים בלבד) ל-[TextSpan] ישירות,
/// כדי לעקוף את עלות הפרסור ובניית העץ של HtmlWidget עבור רוב שורות הספרים.
///
/// כל markup שאינו ברשימה הלבנה (תגים עם attributes, קישורים, spans, כותרות,
/// entities) מחזיר null — והקורא נופל חזרה ל-HtmlWidget המלא. יוצא הדופן
/// היחיד: שני תגי הסימונים המורמים (ראו raised_markers.dart), שמזוהים
/// במדויק — כך שורות עם סימונים נשארות במסלול המהיר, והתמיכה בהם היא חלק
/// מצנרת הטקסט הבסיסית ולא נפילה ל-HtmlWidget.
class SimpleInlineHtml {
  SimpleInlineHtml._();

  static final RegExp _tagRegex = RegExp(r'<[^>]*>');
  static final RegExp _simpleTagRegex = RegExp(r'^<(/?)([a-zA-Z]+)\s*/?>$');
  static final RegExp _entityRegex = RegExp(
    r'&[a-zA-Z]{2,10};|&#x?[0-9a-fA-F]{1,6};',
  );
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// תגי הפתיחה של סימונים מורמים, כפי שנפלטים מ-`_fixFootnoteMarkers`
  /// (מחרוזות קבועות, ולכן השוואה מדויקת). כל span אחר עדיין מפיל ל-HtmlWidget.
  static const String _footnoteMarkerOpen =
      '<span class="$kFootnoteMarkerClass">';
  static const String _raisedSupOpen = '<span class="$kRaisedSupClass">';
  static const String _spanClose = '</span>';

  /// מנסה להמיר את [html]. מחזיר null אם נדרש HtmlWidget.
  static TextSpan? tryParse(String html, TextStyle baseStyle) {
    if (html.contains('&') && _entityRegex.hasMatch(html)) return null;

    // המקרה הנפוץ ביותר: שורה בלי שום תג.
    if (!html.contains('<')) {
      final collapsed = html.replaceAll(_whitespaceRegex, ' ').trim();
      return TextSpan(text: collapsed);
    }

    var bold = 0, italic = 0, underline = 0, big = 0, small = 0;
    var footnoteMarkers = 0, raisedSups = 0;
    // איזה סוג סימון כל `</span>` סוגר (true = מרקר הערה, false = raised-sup).
    // אלה שני תגי ה-span היחידים שהמסלול מקבל, ולכן מחסנית בוליאנית מספיקה.
    final markerStack = <bool>[];
    final segments = <_Segment>[];

    TextStyle? styleForCurrent() {
      if (bold == 0 &&
          italic == 0 &&
          underline == 0 &&
          big == 0 &&
          small == 0 &&
          footnoteMarkers == 0 &&
          raisedSups == 0) {
        return null;
      }
      double? fontSize;
      if (big > 0 || small > 0 || footnoteMarkers > 0 || raisedSups > 0) {
        final base = baseStyle.fontSize ?? 14.0;
        fontSize =
            base *
            math.pow(kHtmlLargerFontScale, big) *
            // raised-sup מוקטן באותו יחס כמו <small>/<sup> — פריטי הגדלים
            // בין המסלולים (ראו התיעוד של kHtmlSmallerFontScale).
            math.pow(kHtmlSmallerFontScale, small + raisedSups) *
            math.pow(kFootnoteMarkerScale, footnoteMarkers);
      }
      final insideMarker = footnoteMarkers > 0 || raisedSups > 0;
      return TextStyle(
        fontWeight: bold > 0 ? FontWeight.bold : null,
        // בולד אמיתי לגופן משתנה — הבסיס יורש דרך Text.rich לספאנים לא-מודגשים.
        fontVariations: bold > 0
            ? AppFonts.boldFontVariations(baseStyle.fontFamily)
            : null,
        fontStyle: (italic > 0 || footnoteMarkers > 0)
            ? FontStyle.italic
            : null,
        decoration: underline > 0 ? TextDecoration.underline : null,
        fontSize: fontSize,
        // גליפי סימון שקופים: תופסים את מקומם בשורה (סדר, בחירה, העתקה),
        // ו-RaisedMarkerOverlay מצייר אותם מורמים — ראו raised_markers.dart.
        color: insideMarker ? const Color(0x00000000) : null,
      );
    }

    void addText(String raw) {
      if (raw.isEmpty) return;
      // HtmlWidget מכווץ רצפי רווחים לרווח יחיד — משמרים התנהגות זהה.
      segments.add(
        _Segment(raw.replaceAll(_whitespaceRegex, ' '), styleForCurrent()),
      );
    }

    var index = 0;
    for (final match in _tagRegex.allMatches(html)) {
      addText(html.substring(index, match.start));
      index = match.end;

      final rawTag = match[0]!;
      // סימונים מורמים — השוואת מחרוזת מדויקת, בלי פרסור attributes.
      if (rawTag == _footnoteMarkerOpen || rawTag == _raisedSupOpen) {
        final isFootnote = rawTag == _footnoteMarkerOpen;
        markerStack.add(isFootnote);
        if (isFootnote) {
          footnoteMarkers++;
        } else {
          raisedSups++;
        }
        continue;
      }
      if (rawTag == _spanClose) {
        // `</span>` יתום — לא נפתח על-ידי סימון שלנו; span זר כבר היה מפיל
        // את השורה בתג הפתיחה שלו, אז זה markup שבור: נופלים ל-HtmlWidget.
        if (markerStack.isEmpty) return null;
        if (markerStack.removeLast()) {
          footnoteMarkers = math.max(0, footnoteMarkers - 1);
        } else {
          raisedSups = math.max(0, raisedSups - 1);
        }
        continue;
      }

      final tagMatch = _simpleTagRegex.firstMatch(rawTag);
      if (tagMatch == null) return null;
      final isClosing = tagMatch[1] == '/';
      final delta = isClosing ? -1 : 1;

      switch (tagMatch[2]!.toLowerCase()) {
        case 'b':
        case 'strong':
          bold = math.max(0, bold + delta);
        case 'i':
        case 'em':
          italic = math.max(0, italic + delta);
        case 'u':
          underline = math.max(0, underline + delta);
        case 'big':
          big = math.max(0, big + delta);
        case 'small':
          small = math.max(0, small + delta);
        case 'br':
          if (!isClosing) segments.add(_Segment.lineBreak());
        default:
          return null;
      }
    }
    addText(html.substring(index));

    _normalizeWhitespace(segments);

    return TextSpan(
      children: [
        for (final segment in segments)
          TextSpan(text: segment.text, style: segment.style),
      ],
    );
  }

  /// מדמה את כללי הרווחים של HTML: רווחים צמודים ל-<br> ולקצוות הפסקה נבלעים.
  static void _normalizeWhitespace(List<_Segment> segments) {
    for (var i = 0; i < segments.length; i++) {
      if (!segments[i].isBreak) continue;
      if (i > 0 && !segments[i - 1].isBreak) {
        segments[i - 1].text = segments[i - 1].text.trimRight();
      }
      if (i + 1 < segments.length && !segments[i + 1].isBreak) {
        segments[i + 1].text = segments[i + 1].text.trimLeft();
      }
    }

    while (segments.isNotEmpty) {
      final first = segments.first;
      first.text = first.isBreak ? '' : first.text.trimLeft();
      if (first.text.isNotEmpty) break;
      segments.removeAt(0);
    }
    while (segments.isNotEmpty) {
      final last = segments.last;
      last.text = last.isBreak ? '' : last.text.trimRight();
      if (last.text.isNotEmpty) break;
      segments.removeLast();
    }
    segments.removeWhere((segment) => segment.text.isEmpty);
  }
}

class _Segment {
  String text;
  final TextStyle? style;
  final bool isBreak;

  _Segment(this.text, this.style) : isBreak = false;
  _Segment.lineBreak() : text = '\n', style = null, isBreak = true;
}
