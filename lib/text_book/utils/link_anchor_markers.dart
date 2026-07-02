import 'package:otzaria/models/links.dart';

/// סמני עוגן-מילה (טבלת link_anchor שבמסד): הזרקת אות סימון קטנה, למשל (א),
/// בנקודה המדויקת בשורת המקור שבה יושבת הערת המפרש.
///
/// `anchorStart` שמור במסד באופסט של *תווים גלויים* — תגי HTML לא נספרים,
/// entity (`&...;`) נספר כתו אחד — אותה מוסכמה של `line.charCount`. ההזרקה
/// חייבת לכן להיעשות על שורת המקור *כפי שנשמרה*, לפני כל עיבוד שמוסיף תוכן
/// גלוי (סימוני הערות אישיות וכד').

/// מספר וריאנטי הטיפוגרפיה של הסמנים (ראו SmartTextWidget.customStylesBuilder).
const int kLinkAnchorStyleCount = 6;

/// אות הסימון של קישור מעוגן: התווית ששמורה במסד, ואם אין — הרכיב האחרון של
/// ה-heRef של ההערה (מספר ההערה בגימטריה, כפי שמודפס). מחזיר null כשאין אות
/// לתצוגה — קישור כזה לא מקבל סמן.
String? anchorMarkerLetter(Link link) {
  final label = link.anchorLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  final tail = link.heRef.split(',').last.trim();
  final letters = tail.replaceAll(RegExp(r'["׳״]'), '');
  if (letters.isEmpty || letters.length > 4) return null;
  if (!RegExp(r'^[א-ת]+$').hasMatch(letters)) return null;
  return tail;
}

/// הקצאת וריאנט טיפוגרפי קבוע לכל מפרש שיש לו עוגני-מילה: לפי סדר אלפביתי של
/// כותרות המפרשים — דטרמיניסטי לאורך כל הספר, כך שכל מפרש שומר על עיצובו.
Map<String, int> anchorStyleIndexByCommentator(Iterable<Link> links) {
  final titles = links
      .where((link) => link.anchorStart != null)
      .map((link) => link.path2)
      .toSet()
      .toList()
    ..sort();
  return {
    for (var i = 0; i < titles.length; i++)
      titles[i]: i % kLinkAnchorStyleCount,
  };
}

/// מזריק את סמני העוגן לשורת ה-HTML הגולמית. הליכה אחת על השורה ממירה את
/// אופסט התווים-הגלויים לנקודת ההזרקה: לפני התו הגלוי הבא אחרי מיקום העוגן
/// (כך שהסמן לא ייכנס לתוך תג פתוח).
///
/// שני סוגי עוגנים:
///  - עוגן-נקודה (anchorEnd == null): סמן אות מורם, למשל (א).
///  - עוגן-טווח (anchorEnd != null, ציטוטים מ-charLevelData): עטיפת הטווח
///    ב-span עם קו תחתון, באותו וריאנט סגנון של המפרש.
String injectLinkAnchorMarkers({
  required String rawLine,
  required List<Link> anchorLinks,
  required Map<String, int> styleIndexByCommentator,
}) {
  // order בתוך אותו אופסט: סגירת טווח (0) לפני סמני אות (1) לפני פתיחת טווח (2),
  // כדי שטווחים צמודים לא יקוננו זה בזה.
  final markers = <({int at, int order, String html})>[];
  for (final link in anchorLinks) {
    final start = link.anchorStart;
    if (start == null || start < 0) continue;
    final styleIndex = styleIndexByCommentator[link.path2] ?? 0;
    final end = link.anchorEnd;
    if (end != null && end > start) {
      markers.add((
        at: start,
        order: 2,
        html: '<span class="link-anchor-range link-anchor-$styleIndex">',
      ));
      markers.add((at: end, order: 0, html: '</span>'));
    } else {
      final letter = anchorMarkerLetter(link);
      if (letter == null) continue;
      markers.add((
        at: start,
        order: 1,
        html:
            '<sup class="link-anchor link-anchor-$styleIndex">($letter)</sup>',
      ));
    }
  }
  return _injectAtVisibleOffsets(rawLine, markers);
}

/// עוטף טווח תווים-גלויים [start, end) של שורת HTML בתגי פתיחה/סגירה.
/// משמש להדגשת הציטוט (linkedAnchor) בתוך קטע המפרש בפאנל.
String wrapVisibleRange({
  required String html,
  required int start,
  required int end,
  required String openTag,
  required String closeTag,
}) {
  if (start < 0 || end <= start) return html;
  return _injectAtVisibleOffsets(html, [
    (at: start, order: 2, html: openTag),
    (at: end, order: 0, html: closeTag),
  ]);
}

String _injectAtVisibleOffsets(
  String rawLine,
  List<({int at, int order, String html})> markers,
) {
  if (markers.isEmpty) return rawLine;
  markers.sort((a, b) {
    final byAt = a.at.compareTo(b.at);
    return byAt != 0 ? byAt : a.order.compareTo(b.order);
  });

  final out = StringBuffer();
  var visible = 0;
  var next = 0;
  var i = 0;
  final len = rawLine.length;

  void flushMarkersAt(int visibleCount) {
    while (next < markers.length && markers[next].at <= visibleCount) {
      out.write(markers[next].html);
      next++;
    }
  }

  while (i < len) {
    final c = rawLine[i];
    if (c == '<') {
      // אירועים שהגיע זמנם נכנסים לפני התג — כך פתיחת/סגירת טווח לא חוצה
      // תגים סמוכים (<b>, itags) והקינון נשאר תקין.
      flushMarkersAt(visible);
      final close = rawLine.indexOf('>', i);
      if (close < 0) {
        out.write(rawLine.substring(i));
        i = len;
        break;
      }
      out.write(rawLine.substring(i, close + 1));
      i = close + 1;
    } else {
      // תו גלוי (או entity שנספר כתו אחד) — סמנים שמקומם כאן נכנסים לפניו.
      flushMarkersAt(visible);
      if (c == '&') {
        final end = (i + 10 < len) ? i + 10 : len;
        var j = i + 1;
        var terminated = false;
        while (j < end) {
          if (rawLine[j] == ';') {
            terminated = true;
            break;
          }
          j++;
        }
        final entityEnd = terminated ? j + 1 : i + 1;
        out.write(rawLine.substring(i, entityEnd));
        i = entityEnd;
      } else {
        out.write(c);
        i++;
      }
      visible++;
    }
  }
  // סמנים שנותרו (בסוף השורה או מעבר לאורכה) מוזרקים בסוף.
  while (next < markers.length) {
    out.write(markers[next].html);
    next++;
  }
  return out.toString();
}
