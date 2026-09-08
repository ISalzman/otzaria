import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// גבול הציור של אזור התוכן.
///
/// ⚠️ מפתח יחיד ולא מפה: יש בדיוק אזור תוכן אחד בכל חלון, וכל חלון הוא
/// isolate נפרד — כלומר אין התנגשות בין חלונות.
///
/// ⚠️ ה-[RepaintBoundary] שמחזיק אותו אינו רק לצילום. אזור התוכן הוא
/// תת-העץ הכבד בתוכנה, וגבול ציור סביבו מבודד את הצטיירותו מסרגל
/// הכרטיסיות שמעליו — כלומר הוא משלם על עצמו גם כשאין גרירה.
///
/// ⚠️ **אינו** מקור הצילום בגרירת כרטיסיה — ראו [TabContentBoundaries].
/// מה שנשאר לו כאן הוא **המידה**: גודלו הוא גודל אזור התוכן, וממנו נגזר
/// גודל התצוגה גם לכרטיסיה שאין לה מה לצלם.
final GlobalKey windowContentBoundaryKey = GlobalKey();

/// גבול הציור של כל כרטיסיה בנפרד, לצילומה בגרירה.
///
/// ## למה פר-כרטיסיה ולא אזור התוכן
///
/// אזור התוכן מצייר את הכרטיסיה **הפעילה**, וגרירה במכוון אינה בוחרת
/// כרטיסיה. צילומו בגרירת כרטיסיה אחרת החזיר תוכן זר — המשתמש גרר כרטיסיה
/// אחת וראה מתחתיה ספר אחר.
///
/// ⚠️ **אין צורך שהכרטיסיה תהיה על המסך.** זו הנקודה שהתיקון הקודם פספס
/// והסיק ממנה שאין דרך: הכרטיסיות יושבות ב-`PageView` שכל ילדיו מסמנים
/// `wantKeepAlive`, ולכן כרטיסיה שהוצגה בעבר נשארת בעץ בדלי ה-keep-alive
/// עם שכבת הציור האחרונה שלה. `toImage` בונה מחדש מאותה שכבה, כלומר הוא
/// מחזיר את **מה שהמשתמש ראה שם לאחרונה** — בדיוק מה שצריך במוק.
///
/// לכרטיסיה שלא נפתחה מעולם (משוחזרת מהפעלה קודמת) אין תת-עץ בכלל, ואין
/// מה לצלם. שם המוק נופל ל-[composeTabContentPlaceholder].
///
/// ⚠️ מפתחות **מפורשים** ולא ה-[RepaintBoundary]-ים ש-`PageView` מוסיף
/// לילדיו מעצמו: לאלה אין מפתח, ובלי מפתח אין דרך להגיע מהרצועה — שהיא
/// תת-עץ אחר לגמרי — לגבול של כרטיסיה מסוימת.
class TabContentBoundaries {
  TabContentBoundaries._();

  /// ⚠️ יחיד לכל isolate, כמו [windowContentBoundaryKey] ומאותה סיבה.
  static final TabContentBoundaries instance = TabContentBoundaries._();

  /// ⚠️ מפה לפי **זהות**. הכרטיסיות אינן מגדירות `==`, ולכן ברירת המחדל
  /// כבר זהות — אבל מפה מפורשת היא מה שמונע מהגדרה עתידית של `==` לפי
  /// ערך למחוק בשקט את ההפרדה בין שתי כרטיסיות של אותו ספר.
  final Map<Object, GlobalKey> _keys = Map.identity();

  /// המפתח של [tab], ונוצר בפעם הראשונה שמבקשים אותו.
  GlobalKey keyFor(Object tab) => _keys.putIfAbsent(tab, GlobalKey.new);

  /// המפתח של [tab] אם כבר נרשם — בלי ליצור אחד חדש.
  ///
  /// ⚠️ הפרדה מ-[keyFor] ולא פרמטר: הצילום אינו רשאי לרשום מפתחות. חלונית
  /// של כרטיסיה מפוצלת נגררת גם היא דרך הרצועה ואינה יושבת ב-`PageView`,
  /// ורישום מכאן היה מדליף מפתח שלעולם לא ייכנס לעץ ולא ייגרע ממנו.
  GlobalKey? maybeKeyFor(Object tab) => _keys[tab];

  /// גורע כל מפתח שאינו של אחת מ-[tabs]. נקרא מבניית אזור התוכן.
  ///
  /// ⚠️ בלעדיו המפה גדלה עם כל כרטיסיה שנפתחה ונסגרה, ומחזיקה הפניה חזקה
  /// לכרטיסיה שכבר `dispose`-ה.
  void retainOnly(Iterable<Object> tabs) {
    if (_keys.isEmpty) return;
    final live = Set<Object>.identity()..addAll(tabs);
    _keys.removeWhere((tab, _) => !live.contains(tab));
  }

  @visibleForTesting
  void debugClear() => _keys.clear();
}

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

/// שיעור הרוחב שהכותרת נפרסת עליו במוק של כרטיסיה שאין לה צילום.
const double _kPlaceholderTitleWidthFraction = 0.8;

/// מספר השורות המרבי לכותרת שם הספר במוק כזה.
const int _kPlaceholderTitleMaxLines = 3;

/// גוף המוק לכרטיסיה שאין מה לצלם בה — אזור תוכן בגודל אמיתי, עם אייקון
/// סוג הכרטיסיה ושם הספר **המלא**.
///
/// ## למה תמונה ולא וידג'ט
///
/// לגוף המוק שני צרכנים: התצוגה המוקטנת שבתוך החלון, שיכולה להציג וידג'ט,
/// והתצוגה הנייטיבית שמחוץ לחלון, שיכולה לקבל **רק** פיקסלים. שני מימושים
/// לאותו מוק היו נפרדים בשקט ברגע שאחד מהם משתנה, ולכן שניהם מציגים את
/// התמונה הזו. אותו מנוע טקסט מצייר אותה בשני המקרים, ולכן היא נראית כמו
/// שאר התוכנה ולא כמו שרטוט.
///
/// ⚠️ הציור כולו ביחידות **לוגיות**, וההגדלה ל-[captureRatio] נעשית פעם
/// אחת על ה-`Canvas`. חישוב מידות בפיקסלים היה מכפיל את יחס הפיקסלים בכל
/// גודל גופן בנפרד — ומדלג עליו במקום אחד בדיוק.
///
/// [icon] הוא גליף בגופן אייקונים; הוא מצויר כטקסט, כי `Canvas` אינו יודע
/// לצייר וידג'ט [Icon].
Future<ui.Image?> composeTabContentPlaceholder({
  required String title,
  required IconData icon,
  required Color background,
  required Color foreground,
  required Size logicalSize,
  required double captureRatio,
  required bool rtl,
}) async {
  try {
    final width = (logicalSize.width * captureRatio).round();
    final height = (logicalSize.height * captureRatio).round();
    if (width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(captureRatio);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, logicalSize.width, logicalSize.height),
      Paint()..color = background,
    );

    // מידות שנגזרות מאזור התוכן, עם תקרה: אותו מוק משמש חלון קטן וחלון
    // ממוקסם במסך 4K, ואייקון בשיעור קבוע היה ענק באחד וזעיר באחר.
    final shortest = logicalSize.shortestSide;
    final iconSize = math.min(shortest * 0.22, 96.0);
    final titleSize = math.min(logicalSize.width * 0.045, 28.0);
    final gap = titleSize * 0.9;

    final iconParagraph = _paragraph(
      text: String.fromCharCode(icon.codePoint),
      fontFamily: _iconFontFamily(icon),
      fontSize: iconSize,
      // ⚠️ הגליף עצמו הוא הרמז החלש, לא הכותרת. אטימות מלאה הפכה אותו
      // לעיקר במוק שכל תפקידו לומר "זה החלון, התוכן עוד לא נטען".
      color: foreground.withValues(alpha: 0.28),
      // ⚠️ גליף אייקון אינו טקסט דו-כיווני. `rtl` היה מיישר אותו לימין
      // בתוך פסקה ברוחב מלא, במקום למרכז.
      textDirection: ui.TextDirection.ltr,
      maxWidth: logicalSize.width,
    );
    final titleParagraph = _paragraph(
      text: title,
      fontSize: titleSize,
      color: foreground.withValues(alpha: 0.75),
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      maxLines: _kPlaceholderTitleMaxLines,
      ellipsis: '…',
      height: 1.35,
      maxWidth: logicalSize.width * _kPlaceholderTitleWidthFraction,
    );

    // הבלוק כולו ממורכז אנכית, ולכן גובהו נדרש לפני שמציירים את חלקו
    // הראשון.
    //
    // ⚠️ מהודק לאפס. באזור תוכן רחב-ונמוך (חלון מוצמד לחצי מסך אופקי,
    // או חלון קטן) הבלוק גבוה מהאזור, והמרכוז יוצא שלילי — כלומר
    // האייקון מצויר מעל הקצה העליון ונחתך.
    final blockHeight = iconParagraph.height + gap + titleParagraph.height;
    var dy = math.max(0.0, (logicalSize.height - blockHeight) / 2);
    canvas.drawParagraph(iconParagraph, Offset(0, dy));
    dy += iconParagraph.height + gap;
    canvas.drawParagraph(
      titleParagraph,
      Offset(
        logicalSize.width * (1 - _kPlaceholderTitleWidthFraction) / 2,
        dy,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  } catch (e) {
    debugPrint('בניית מוק לכרטיסיה בלי צילום נכשלה: $e');
    return null;
  }
}

/// שם הגופן של [icon] כפי שמנוע הטקסט מכיר אותו.
///
/// ⚠️ גופן שמגיע מחבילה נרשם עם התחילית `packages/<חבילה>/`. בלעדיה
/// `ParagraphBuilder` נופל לגופן ברירת המחדל, והגליף יוצא ריבוע.
String? _iconFontFamily(IconData icon) {
  final package = icon.fontPackage;
  if (package == null) return icon.fontFamily;
  return 'packages/$package/${icon.fontFamily}';
}

/// פסקה ממורכזת, פרוסה לרוחב [maxWidth].
ui.Paragraph _paragraph({
  required String text,
  required double fontSize,
  required Color color,
  required ui.TextDirection textDirection,
  required double maxWidth,
  String? fontFamily,
  int? maxLines,
  String? ellipsis,
  double? height,
}) {
  final builder =
      ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          textDirection: textDirection,
          fontFamily: fontFamily,
          fontSize: fontSize,
          maxLines: maxLines,
          ellipsis: ellipsis,
          height: height,
        ),
      )..pushStyle(
        ui.TextStyle(
          color: color,
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: height,
        ),
      );
  builder.addText(text);
  final paragraph = builder.build();
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
  return paragraph;
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
