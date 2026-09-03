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
}
