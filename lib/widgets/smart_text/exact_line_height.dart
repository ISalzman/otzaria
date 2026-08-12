/// קיבוע גובה השורה לגובה שהטקסט הראשי מכתיב.
///
/// מנוע הטקסט קובע את גובה כל שורה לפי ה-ascent/descent הגדולים ביותר מבין
/// ריצות-הטקסט שבה. די לכן בריצה אחת שונה כדי למתוח את השורה כולה ולשבור את
/// אחידות המרווח — מילה ב-`<big>` (סימוני "גמ׳" ו"מתני׳" בתלמוד), או ספרת
/// superscript של סימון הערה, שאין לה גליף באף אחד מגופני האפליקציה ולכן
/// נפתרת לגופן מערכת שיחסי ה-ascent/descent שלו אחרים.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:otzaria/widgets/smart_text/simple_inline_html.dart';

/// [StrutStyle] שמקבע כל שורה לגובה `fontSize × height` של [baseStyle] — הגובה
/// של שורה שכל תוכנה בגופן הבסיס (המנוע מעגל אותו לפיקסל שלם, אותו עיגול בכל
/// השורות).
///
/// מחזיר null כשאסור לקבע: ווידג'ט inline (שגובהו אמיתי ולא מטריקה של גופן), או
/// ריצה שגדולה מ-`<big>` או מתיבת השורה עצמה — כותרת בתוך שורה, וגם `<big>`
/// במרווח שורות צפוף, באמת צריכות יותר מקום, וקיבוע היה מפיל אותן על השורה
/// שמעליה.
StrutStyle? exactLineHeightStrut(TextStyle baseStyle, InlineSpan content) {
  final fontSize = baseStyle.fontSize;
  final lineHeight = baseStyle.height;
  if (fontSize == null || lineHeight == null) return null;
  final maxRunFontSize = fontSize * math.min(kHtmlLargerFontScale, lineHeight);
  if (!_fitsLineBox(content, maxRunFontSize)) return null;

  return StrutStyle.fromTextStyle(
    baseStyle,
    // חלוקת ה-leading חייבת להיות מפורשת ולא בירושה: בחלוקה proportional
    // המנוע מחלק את הגובה המבוקש גם על ה-lineGap של הגופן אך אינו מוסיף אותו
    // לתיבת השורה, וה-strut יוצא נמוך מ-fontSize×height.
    leadingDistribution: TextLeadingDistribution.even,
    forceStrutHeight: true,
  );
}

/// רקורסיה ידנית ולא `visitChildren`: זה מדלג על ספאן שאין לו `text`, ולכן
/// ספאן-אב שנושא את הגופן הגדול היה חומק מהבדיקה.
bool _fitsLineBox(InlineSpan content, double maxRunFontSize) {
  if (content is! TextSpan) return false;
  final fontSize = content.style?.fontSize;
  if (fontSize != null && fontSize > maxRunFontSize + _epsilon) return false;
  for (final child in content.children ?? const <InlineSpan>[]) {
    if (!_fitsLineBox(child, maxRunFontSize)) return false;
  }
  return true;
}

const double _epsilon = 0.01;
