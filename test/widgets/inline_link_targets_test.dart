import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/misc/inline_link_targets.dart';

/// זיהוי קישור `<a>` בטקסט לפי נקודת הלחיצה — בסיס ל"פתח קישור בכרטיסייה
/// חדשה" בלחיצה ימנית, וללחיצת גלגל שפותחת את הקישור במקום לגלול.
void main() {
  const url = 'otzaria://inline-link?path=ברכות&index=3';

  Future<TapGestureRecognizer> pumpText(
    WidgetTester tester, {
    void Function(String url)? onMiddleClick,
  }) async {
    final recognizer = TapGestureRecognizer()..onTap = () {};
    addTearDown(recognizer.dispose);
    registerInlineLinkRecognizer(recognizer, url, onMiddleClick: onMiddleClick);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RichText(
              key: const Key('text'),
              text: TextSpan(
                style: const TextStyle(fontSize: 20),
                children: [
                  const TextSpan(text: 'ראה '),
                  TextSpan(text: 'ברכות ג', recognizer: recognizer),
                  const TextSpan(text: ' שם.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return recognizer;
  }

  /// מרכז הקטע [range] של הפסקה בקואורדינטות גלובליות.
  Offset centerOfRange(WidgetTester tester, TextRange range) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const Key('text')),
    );
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: range.start, extentOffset: range.end),
        )
        .first;
    return paragraph.localToGlobal(box.toRect().center);
  }

  testWidgets('מחזיר את ה-url בלחיצה על הקישור ו-null מחוצה לו', (
    tester,
  ) async {
    await pumpText(tester);
    final onLink = centerOfRange(tester, const TextRange(start: 4, end: 11));
    final offLink = centerOfRange(tester, const TextRange(start: 0, end: 3));

    expect(inlineLinkUrlAt(onLink), url);
    expect(inlineLinkUrlAt(offLink), isNull);
  });

  testWidgets('לחיצת גלגל על הקישור מפעילה את onMiddleClick עם ה-url', (
    tester,
  ) async {
    final clicked = <String>[];
    await pumpText(tester, onMiddleClick: clicked.add);
    final onLink = centerOfRange(tester, const TextRange(start: 4, end: 11));

    final gesture = await tester.startGesture(
      onLink,
      kind: PointerDeviceKind.mouse,
      buttons: kTertiaryButton,
    );
    await gesture.up();
    await tester.pump();

    expect(clicked, [url]);
  });

  testWidgets('recognizer שלא נרשם אינו מזוהה כקישור', (tester) async {
    final recognizer = TapGestureRecognizer()..onTap = () {};
    addTearDown(recognizer.dispose);
    expect(
      inlineLinkUrlOf(TextSpan(text: 'x', recognizer: recognizer)),
      isNull,
    );
    expect(inlineLinkUrlOf(const TextSpan(text: 'x')), isNull);
  });
}
