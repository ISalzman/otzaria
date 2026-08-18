import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/smart_text/raised_markers.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/smart_text_widget.dart';

/// שכבת הסימונים המורמים מציירת בכל פריים. קטע ריאלי בספר נושא עשרות סימונים,
/// והציור חייב להישאר זול — אחרת הגלילה נתקעת. האיתור עצמו (toPlainText לכל
/// פסקה + חיפוש לכל סימון) יקר, ולכן הוא ממוזג לפי הפריסה; הבדיקה מודדת ציור
/// חוזר בלי שינוי פריסה — בדיוק מה שקורה בגלילה — ומשווה לאותו קטע בלי שכבה,
/// כדי שהמידה תהיה התקורה שלנו ולא כוח המכונה.
///
/// לפני המיזוג המדידה הזאת הראתה 41ms לפריים (מול תקציב פריים של 16ms), וזו
/// הייתה הסיבה לתקיעות שדווחה.
void main() {
  String heavyText({required bool withMarkers}) {
    final buffer = StringBuffer();
    for (var i = 0; i < 60; i++) {
      final marker = withMarkers
          ? '<sup>${String.fromCharCode(0x05D0 + i % 22)}</sup>'
          : '';
      buffer.write(
        'ויאמר אלהים אל משה ואל אהרן לאמר דברו אל בני ישראל '
        'ואמרתם אליהם כה אמר השם$marker ',
      );
    }
    return buffer.toString();
  }

  Future<double> measureRepaints(
    WidgetTester tester,
    String text,
    RenderObject Function() targetOf,
  ) async {
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 30; i++) {
      targetOf().markNeedsPaint();
      await tester.pump();
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds / 30 / 1000;
  }

  testWidgets('ציור חוזר של קטע עם 60 סימונים נשאר זול', (tester) async {
    final buffer = StringBuffer(heavyText(withMarkers: true));

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 700,
              height: 4000,
              child: SmartTextWidget(
                text: buffer.toString(),
                settings: const RenderSettings(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = tester.renderObject<RenderRaisedMarkerOverlay>(
      find.byType(RaisedMarkerOverlay),
    );
    expect(overlay.debugPlacements().length, greaterThan(50));

    final withOverlay = await measureRepaints(
      tester,
      buffer.toString(),
      () => overlay,
    );

    // אותו קטע בלי סימונים — קו הבסיס של ציור הטקסט עצמו.
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 700,
              height: 4000,
              child: SmartTextWidget(
                text: heavyText(withMarkers: false),
                settings: const RenderSettings(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RaisedMarkerOverlay), findsNothing);
    final baseline = await measureRepaints(
      tester,
      heavyText(withMarkers: false),
      () => tester.renderObject(find.byType(RichText).first),
    );

    final overhead = withOverlay - baseline;
    debugPrint(
      'עם שכבה: ${withOverlay.toStringAsFixed(2)}ms · '
      'בסיס: ${baseline.toStringAsFixed(2)}ms · '
      'תקורה: ${overhead.toStringAsFixed(2)}ms',
    );
    expect(
      overhead,
      lessThan(4.0),
      reason: 'תקורת ציור של $overhead ms לפריים חונקת את הגלילה '
          '(תקציב פריים ~16ms). לפני המיזוג לפי פריסה זה היה ~40ms.',
    );
  });
}
