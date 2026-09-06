import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// גבול הציור של אזור התוכן, לצילומו בגרירת כרטיסיה.
///
/// ⚠️ מפתח יחיד ולא מפה: יש בדיוק אזור תוכן אחד בכל חלון, וכל חלון הוא
/// isolate נפרד — כלומר אין התנגשות בין חלונות.
///
/// ⚠️ ה-[RepaintBoundary] שמחזיק אותו אינו רק לצילום. אזור התוכן הוא
/// תת-העץ הכבד בתוכנה, וגבול ציור סביבו מבודד את הצטיירותו מסרגל
/// הכרטיסיות שמעליו — כלומר הוא משלם על עצמו גם כשאין גרירה.
final GlobalKey windowContentBoundaryKey = GlobalKey();

/// רוחב התצוגה המוקטנת בגרירה **בתוך** החלון, ביחידות לוגיות.
///
/// ⚠️ מוקטנת ולא בגודל אמיתי, ובמכוון: סידור כרטיסיות ימינה ושמאלה הוא
/// מחווה בתוך הרצועה, ותצוגה בגודל חלון הייתה מכסה את התוכנה כולה בזמן
/// שהמשתמש מנסה לראות לאן הכרטיסיה נכנסת. בגרירה **החוצה** התצוגה כן
/// בגודל אמיתי — שם היא מוק של החלון שעומד להיפתח.
const double kMiniPreviewWidth = 240;

/// גובה מרבי לתצוגה המוקטנת. חלון רחב-ונמוך אינו נמתח מעל זה.
const double kMiniPreviewMaxHeight = 170;

/// תקרת פיקסלים לצילום שנשלח לצד הנייטיבי.
///
/// ⚠️ זו הסיבה שגודל הצילום נפרד מגודל התצוגה. חלון 1400×800 במסך 150%
/// הוא 2,100×1,200 — 2.5 מיליון פיקסלים, כלומר 10MB של RGBA שעוברים
/// בערוץ ההודעות בתחילת **כל** גרירה, ולפניהם קריאת פיקסלים מה-GPU.
/// זה נמדד בעשרות מילישניות בדיוק ברגע שהמשתמש מתחיל לגרור.
///
/// 1.2 מיליון פיקסלים (~4.8MB) הם פשרה: תמונת רפאים שנמתחת בחזרה נראית
/// מטושטשת מעט, ואיש אינו קורא בה טקסט — אבל היא מגיעה בזמן.
const int _kMaxCapturePixels = 1200 * 1000;

/// יחס הפיקסלים לצילום, כך שהתוצאה לא תעבור את [_kMaxCapturePixels].
///
/// לא עולה על [devicePixelRatio]: צילום מעל הרזולוציה האמיתית רק מבזבז.
double previewCaptureRatio(Size logicalSize, double devicePixelRatio) {
  final area = logicalSize.width * logicalSize.height;
  if (area <= 0) return devicePixelRatio;
  final maxRatio = math.sqrt(_kMaxCapturePixels / area);
  return math.min(devicePixelRatio, maxRatio);
}

/// מצלם את תת-העץ שמתחת ל-[key]. מחזיר null אם אין מה לצלם.
///
/// ⚠️ `toImage` האסינכרוני ולא `toImageSync`. השני החזיר תמונה **ריקה**
/// תחת Impeller — ברירת המחדל ב-Flutter 3.47 — והמשתמש ראה כרטיסיה שקופה.
Future<ui.Image?> captureBoundary(GlobalKey key, double pixelRatio) async {
  try {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    return await object.toImage(pixelRatio: pixelRatio);
  } catch (e) {
    debugPrint('צילום לגרירה נכשל: $e');
    return null;
  }
}

/// תצוגת הגרירה המורכבת: מוק של החלון שייפתח.
@immutable
class TabWindowPreview {
  const TabWindowPreview({
    required this.image,
    required this.targetWidth,
    required this.targetHeight,
  });

  /// התמונה עצמה, בגודל הצילום.
  final ui.Image image;

  /// הגודל שבו התצוגה צריכה להופיע, בפיקסלים פיזיים — כלומר גודל החלון.
  final int targetWidth;
  final int targetHeight;
}

/// מרכיב מוק של החלון: ראש הכרטיסיה מעל, והתוכן מתחתיו.
///
/// ## למה מרכיבים ולא מצלמים את החלון כולו
///
/// צילום החלון היה מראה את **כל** הכרטיסיות הפתוחות, בעוד שהחלון שייפתח
/// יכיל אחת. ההרכבה מכאן מציגה את מה שיהיה שם: הכרטיסיה הנגררת לבדה,
/// בראש רצועה ריקה, ומעליה התוכן שלה.
///
/// ⚠️ התוצאה **אטומה**: רקע הרצועה נצבע לרוחב לפני הכרטיסיה, ולכן הפינות
/// המעוגלות שלה יושבות עליו ולא על שקיפות. זה גם מה שמתיר לצד הנייטיבי
/// למתוח אותה ב-`StretchBlt`, שאינו יודע אלפא.
///
/// הבעלות על [tabHead] ועל [content] **אינה** עוברת — המרכיב משחרר רק את
/// מה שהוא יצר.
Future<TabWindowPreview?> composeTabWindowPreview({
  required ui.Image tabHead,
  required ui.Image content,
  required Color stripColor,
  required double devicePixelRatio,
  required double captureRatio,
  required bool rtl,
}) async {
  try {
    final width = content.width;
    final stripHeight = tabHead.height;
    final height = stripHeight + content.height;
    if (width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // רצועת הכרטיסיות: רקע לכל הרוחב, והכרטיסיה בקצה שלה.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), stripHeight.toDouble()),
      Paint()..color = stripColor,
    );
    // ⚠️ בעברית הכרטיסיה הראשונה בקצה **הימני**. ציור בשמאל היה נראה כמו
    // חלון של תוכנה אחרת.
    final tabLeft = rtl ? (width - tabHead.width).toDouble() : 0.0;
    canvas.drawImage(tabHead, Offset(tabLeft, 0), Paint());

    canvas.drawImage(content, Offset(0, stripHeight.toDouble()), Paint());

    final picture = recorder.endRecording();
    final composed = await picture.toImage(width, height);
    picture.dispose();

    // גודל היעד הוא הגודל **הפיזי** של החלון, ולא של הצילום: הצילום
    // הוקטן כדי לעבור בערוץ, והצד הנייטיבי מותח אותו בחזרה.
    final scale = devicePixelRatio / captureRatio;
    return TabWindowPreview(
      image: composed,
      targetWidth: (width * scale).round(),
      targetHeight: (height * scale).round(),
    );
  } catch (e) {
    debugPrint('הרכבת תצוגת הגרירה נכשלה: $e');
    return null;
  }
}
