import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/tab_drag_preview.dart';

/// מה שנגרר הוא **מוק של החלון שייפתח** — כרטיסיה והתוכן שלה — ולא ראש
/// הכרטיסיה לבדו. כאן נבדקות שתי ההחלטות שמאפשרות את זה: הקטנת הצילום
/// כדי שיעבור בערוץ, וההרכבה עצמה.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('previewCaptureRatio', () {
    // ⚠️ זו לא אופטימיזציה אלא תנאי לשימושיות. חלון 1400×800 במסך 150%
    // הוא 2.5 מיליון פיקסלים — 10MB של RGBA שעוברים בערוץ ההודעות בתחילת
    // **כל** גרירה, ולפניהם קריאת פיקסלים מה-GPU. זה נמדד בעשרות
    // מילישניות בדיוק ברגע שהמשתמש מתחיל לגרור.

    test('חלון קטן מצולם ברזולוציה המלאה', () {
      // 600×400 ב-DPR 1.5 הם 540 אלף פיקסלים — מתחת לתקרה, אין מה להקטין.
      expect(previewCaptureRatio(const Size(600, 400), 1.5), 1.5);
    });

    test('חלון גדול מוקטן עד לתקרה', () {
      final ratio = previewCaptureRatio(const Size(1400, 800), 1.5);
      expect(ratio, lessThan(1.5));
      final pixels = 1400 * ratio * 800 * ratio;
      expect(pixels, lessThanOrEqualTo(1200 * 1000 + 1));
    });

    test('אינו עולה על ה-DPR — צילום מעל הרזולוציה האמיתית רק מבזבז', () {
      expect(previewCaptureRatio(const Size(300, 200), 1.0), 1.0);
      expect(previewCaptureRatio(const Size(300, 200), 2.0), 2.0);
    });

    test('גודל אפס אינו מפיל חילוק', () {
      expect(previewCaptureRatio(Size.zero, 1.5), 1.5);
    });
  });

  group('composeTabWindowPreview', () {
    /// תמונה אטומה בצבע אחד, לזיהוי מי צויר איפה.
    Future<ui.Image> solid(int width, int height, int argb) {
      final pixels = Uint8List(width * height * 4);
      for (var i = 0; i < width * height; i++) {
        pixels[i * 4 + 0] = (argb >> 16) & 0xFF;
        pixels[i * 4 + 1] = (argb >> 8) & 0xFF;
        pixels[i * 4 + 2] = argb & 0xFF;
        pixels[i * 4 + 3] = (argb >> 24) & 0xFF;
      }
      final done = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        done.complete,
      );
      return done.future;
    }

    /// צבע הפיקסל ב-[x],[y] כ-`0xAARRGGBB`.
    Future<int> pixelAt(ui.Image image, int x, int y) async {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      final i = (y * image.width + x) * 4;
      return (bytes[i + 3] << 24) |
          (bytes[i] << 16) |
          (bytes[i + 1] << 8) |
          bytes[i + 2];
    }

    const strip = Color(0xFF112233);
    const tabColor = 0xFFFF0000;
    const contentColor = 0xFF00FF00;

    test('הכרטיסיה בקצה **הימני** בעברית', () async {
      // ⚠️ בעברית הכרטיסיה הראשונה בימין. ציור בשמאל היה נראה כמו חלון
      // של תוכנה אחרת.
      final tabHead = await solid(20, 10, tabColor);
      final content = await solid(100, 40, contentColor);

      final preview = await composeTabWindowPreview(
        tabHead: tabHead,
        content: content,
        stripColor: strip,
        devicePixelRatio: 1,
        captureRatio: 1,
        rtl: true,
      );

      expect(preview, isNotNull);
      final image = preview!.image;
      expect(image.width, 100, reason: 'הרוחב הוא רוחב התוכן');
      expect(image.height, 50, reason: 'רצועה 10 ותוכן 40');

      expect(await pixelAt(image, 95, 5), tabColor, reason: 'כרטיסיה בימין');
      expect(
        await pixelAt(image, 5, 5),
        strip.toARGB32(),
        reason: 'בשמאל רצועה ריקה, ולא הכרטיסיה',
      );
      expect(await pixelAt(image, 50, 30), contentColor);

      tabHead.dispose();
      content.dispose();
      image.dispose();
    });

    test('בשפה משמאל-לימין הכרטיסיה בקצה השמאלי', () async {
      final tabHead = await solid(20, 10, tabColor);
      final content = await solid(100, 40, contentColor);

      final preview = await composeTabWindowPreview(
        tabHead: tabHead,
        content: content,
        stripColor: strip,
        devicePixelRatio: 1,
        captureRatio: 1,
        rtl: false,
      );

      expect(await pixelAt(preview!.image, 5, 5), tabColor);
      expect(await pixelAt(preview.image, 95, 5), strip.toARGB32());

      tabHead.dispose();
      content.dispose();
      preview.image.dispose();
    });

    test('גודל היעד הוא גודל **החלון**, ולא גודל הצילום', () async {
      // ⚠️ ההפרדה הזו היא כל מה שמאפשר מוק בגודל חלון: הצילום קטן כדי
      // לעבור בערוץ, והצד הנייטיבי מותח אותו בחזרה. אילו היעד היה גודל
      // הצילום, התצוגה הייתה מופיעה מוקטנת ולא כמו החלון שייפתח.
      final tabHead = await solid(20, 10, tabColor);
      final content = await solid(100, 40, contentColor);

      final preview = await composeTabWindowPreview(
        tabHead: tabHead,
        content: content,
        stripColor: strip,
        devicePixelRatio: 1.5,
        captureRatio: 0.75,
        rtl: true,
      );

      // הצילום 100×50, ה-DPR כפול מיחס הצילום ⇒ היעד כפול.
      expect(preview!.image.width, 100);
      expect(preview.targetWidth, 200);
      expect(preview.targetHeight, 100);

      tabHead.dispose();
      content.dispose();
      preview.image.dispose();
    });
  });

  group('composeTabContentPlaceholder', () {
    // המוק לכרטיסיה שלא נפתחה מעולם: אין לה תת-עץ, ולכן אין מה לצלם.
    // ⚠️ בלי המוק הזה הגרירה נופלת לראש הכרטיסיה לבדו — וזה מה שהמשתמש
    // דחה: "אני לא מעוניין שיוצג רק ראש הכרטיסייה אלא שיוצג החלון".

    const background = Color(0xFFF2EBE0);
    const foreground = Color(0xFF000000);
    const icon = IconData(0xe000, fontFamily: 'MaterialIcons');

    Future<ui.Image> build({
      String title = 'בראשית',
      Size logicalSize = const Size(400, 300),
      double captureRatio = 1,
      bool rtl = true,
    }) async {
      final image = await composeTabContentPlaceholder(
        title: title,
        icon: icon,
        background: background,
        foreground: foreground,
        logicalSize: logicalSize,
        captureRatio: captureRatio,
        rtl: rtl,
      );
      expect(image, isNotNull);
      return image!;
    }

    test('בגודל אזור התוכן, מוכפל ביחס הצילום', () async {
      final image = await build(
        logicalSize: const Size(400, 300),
        captureRatio: 1.5,
      );
      expect(image.width, 600);
      expect(image.height, 450);
      image.dispose();
    });

    test('הרקע הוא רקע הקריאה, ולא שקיפות', () async {
      // ⚠️ אטימות אינה קוסמטיקה: `StretchBlt` שבצד הנייטיבי אינו יודע
      // אלפא, ומוק שקוף היה מגיע לשם כמלבן שחור.
      final image = await build();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      // הפינה — רחוק מהאייקון ומהכותרת שבמרכז.
      expect(bytes[0], (background.r * 255).round());
      expect(bytes[1], (background.g * 255).round());
      expect(bytes[2], (background.b * 255).round());
      expect(bytes[3], 255, reason: 'אטום');
      image.dispose();
    });

    test('גודל אפס אינו מייצר תמונה', () async {
      final image = await composeTabContentPlaceholder(
        title: 'בראשית',
        icon: icon,
        background: background,
        foreground: foreground,
        logicalSize: Size.zero,
        captureRatio: 1,
        rtl: true,
      );
      expect(image, isNull);
    });

    /// כל הפיקסלים של [image] כרשימת `0xAARRGGBB`.
    Future<List<int>> pixelsOf(ui.Image image) async {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      return [
        for (var i = 0; i < bytes.length; i += 4)
          (bytes[i + 3] << 24) |
              (bytes[i] << 16) |
              (bytes[i + 1] << 8) |
              bytes[i + 2],
      ];
    }

    test('⚠️ באמת מצייר משהו, ולא רק מלבן ברקע', () async {
      // ⚠️ בדיקות הגודל, האטימות והכותרת הארוכה עוברות כולן גם על
      // מימוש שמצייר **רק** את הרקע. זו הבדיקה שמפילה אותו.
      final image = await build(logicalSize: const Size(400, 300));
      final pixels = await pixelsOf(image);
      final background = pixels.first;

      expect(
        pixels.where((p) => p != background),
        isNotEmpty,
        reason: 'המוק יצא ריק — אין אייקון ואין כותרת',
      );
      image.dispose();
    });

    test('⚠️ הכותרת באמת מגיעה לפיקסלים', () async {
      // ⚠️ שני שמות שונים חייבים לתת תמונות שונות. בלי זה מימוש שמצייר
      // את האייקון ומתעלם מהכותרת עובר — והכותרת היא כל מה שאומר
      // למשתמש **איזה** ספר הוא גורר.
      final short = await build(title: 'א');
      final long = await build(title: 'שולחן ערוך אורח חיים');

      expect(await pixelsOf(short), isNot(await pixelsOf(long)));
      short.dispose();
      long.dispose();
    });

    test('כותרת ארוכה אינה גולשת ואינה מפילה את הציור', () async {
      // ⚠️ שם ספר ארוך הוא הרגיל ולא הקצה ("שולחן ערוך אורח חיים עם באר
      // הגולה ובאר היטב"). התקרה על מספר השורות היא מה שמונע ממנו לכסות
      // את המוק כולו.
      final image = await build(
        title:
            'שולחן ערוך אורח חיים עם באר הגולה ובאר היטב ומשנה ברורה '
            'ושער הציון והוספות מרובות מאוד מאוד',
        logicalSize: const Size(300, 200),
      );
      expect(image.width, 300);
      expect(image.height, 200);
      image.dispose();
    });
  });

  group('TabContentBoundaries', () {
    setUp(TabContentBoundaries.instance.debugClear);

    test('מפתח יציב לאותה כרטיסיה, ושונה בין כרטיסיות', () {
      final registry = TabContentBoundaries.instance;
      final first = Object();
      final second = Object();

      expect(registry.keyFor(first), same(registry.keyFor(first)));
      expect(registry.keyFor(second), isNot(same(registry.keyFor(first))));
    });

    test('maybeKeyFor אינו רושם מפתח חדש', () {
      // ⚠️ מסלול הצילום קורא ל-`maybeKeyFor`, והוא נקרא גם לחלונית של
      // כרטיסיה מפוצלת — שאינה יושבת ב-`PageView` בכלל. רישום משם היה
      // מדליף מפתח שלעולם לא ייכנס לעץ ולא ייגרע ממנו.
      final registry = TabContentBoundaries.instance;
      final tab = Object();

      expect(registry.maybeKeyFor(tab), isNull);
      registry.retainOnly(const []);
      expect(registry.maybeKeyFor(tab), isNull);
    });

    test('retainOnly גורע כרטיסיה שנסגרה', () {
      final registry = TabContentBoundaries.instance;
      final kept = Object();
      final closed = Object();
      final keptKey = registry.keyFor(kept);
      registry.keyFor(closed);

      registry.retainOnly([kept]);

      expect(registry.maybeKeyFor(kept), same(keptKey));
      expect(registry.maybeKeyFor(closed), isNull);
    });

    test('הזהות היא מה שמפריד, ולא השוויון', () {
      // שני ערכים שווים-ולא-זהים הם שתי כרטיסיות שונות של אותו ספר, וכל
      // אחת צריכה גבול משלה.
      final registry = TabContentBoundaries.instance;
      final first = [1, 2, 3];
      final second = [1, 2, 3];

      expect(registry.keyFor(first), isNot(same(registry.keyFor(second))));

      registry.retainOnly([first]);
      expect(registry.maybeKeyFor(first), isNotNull);
      expect(registry.maybeKeyFor(second), isNull);
    });
  });
}
