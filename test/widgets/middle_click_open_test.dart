import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/misc/middle_click_autoscroll.dart';
import 'package:otzaria/widgets/misc/middle_click_open.dart';

/// [MiddleClickOpen] — לחיצת גלגל על פריט פותחת אותו ("פתח בכרטיסייה
/// חדשה") ולא מפעילה את האוטו-גלילה, ולחיצה רגילה נשארת של הפריט עצמו.
void main() {
  Future<void> pumpItem(
    WidgetTester tester, {
    required VoidCallback onMiddleClick,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MiddleClickAutoScroll(
          child: Scaffold(
            body: ListView(
              children: [
                MiddleClickOpen(
                  onMiddleClick: onMiddleClick,
                  child: InkWell(
                    onTap: onTap,
                    child: const SizedBox(
                      key: Key('item'),
                      height: 60,
                      child: Text('תוצאה'),
                    ),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('לחיצת גלגל מפעילה את onMiddleClick', (tester) async {
    var middleClicks = 0;
    var taps = 0;
    await pumpItem(
      tester,
      onMiddleClick: () => middleClicks++,
      onTap: () => taps++,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('item'))),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.up();
    await tester.pump();

    expect(middleClicks, 1);
    expect(taps, 0);
  });

  testWidgets('לחיצה שמאלית אינה מפעילה את onMiddleClick', (tester) async {
    var middleClicks = 0;
    var taps = 0;
    await pumpItem(
      tester,
      onMiddleClick: () => middleClicks++,
      onTap: () => taps++,
    );

    await tester.tap(find.byKey(const Key('item')));
    await tester.pump();

    expect(middleClicks, 0);
    expect(taps, 1);
  });

  testWidgets('לחיצת גלגל על הפריט אינה מתחילה אוטו-גלילה', (tester) async {
    await pumpItem(tester, onMiddleClick: () {});

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('item'))),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.up();
    await tester.pump();

    // עוגן הגלילה מצויר בשכבת CustomPaint שנוספת רק כשהגלילה פעילה.
    expect(
      find.descendant(
        of: find.byType(MiddleClickAutoScroll),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
