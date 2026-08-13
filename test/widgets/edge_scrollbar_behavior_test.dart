import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/feedback/edge_scrollbar_behavior.dart';

void main() {
  /// רשימה אנכית בעברית, עם או בלי התנהגות הגלילה שמצמידה את הפס לימין.
  /// [MaterialScrollBehavior] קורא את הפלטפורמה מה-Theme, ו-flutter_test מריץ
  /// כברירת מחדל כאנדרואיד — שבו אין פס גלילה אוטומטי כלל, ולכן היא נקבעת כאן
  /// מפורשות. [thumbAlwaysVisible] נחוץ לבדיקות מגע: הפס דוהה כשאין גלילה או
  /// ריחוף, ולא ניתן ללחוץ עליו.
  Future<ScrollController> pumpList(
    WidgetTester tester, {
    ScrollBehavior? behavior,
    Axis axis = Axis.vertical,
    bool thumbAlwaysVisible = false,
    TextDirection direction = TextDirection.rtl,
    TargetPlatform platform = TargetPlatform.windows,
  }) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = ScrollController();
    addTearDown(controller.dispose);

    Widget list = ListView.builder(
      controller: controller,
      scrollDirection: axis,
      itemCount: 100,
      itemBuilder: (context, i) =>
          SizedBox(height: 50, width: 200, child: Text('שורה $i')),
    );
    if (behavior != null) {
      list = ScrollConfiguration(behavior: behavior, child: list);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: platform,
          scrollbarTheme: thumbAlwaysVisible
              ? const ScrollbarThemeData(
                  thumbVisibility: WidgetStatePropertyAll(true),
                )
              : const ScrollbarThemeData(),
        ),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: list),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  ScrollbarOrientation? orientationOf(WidgetTester tester) =>
      tester.widget<Scrollbar>(find.byType(Scrollbar)).scrollbarOrientation;

  group('EdgeScrollbarBehavior', () {
    testWidgets('מצמידה את הפס האנכי לימין', (tester) async {
      await pumpList(tester, behavior: const EdgeScrollbarBehavior.right());

      expect(orientationOf(tester), ScrollbarOrientation.right);
    });

    testWidgets('מקבלת גם צד שמאל במפורש', (tester) async {
      await pumpList(
        tester,
        behavior: const EdgeScrollbarBehavior(ScrollbarOrientation.left),
      );

      expect(orientationOf(tester), ScrollbarOrientation.left);
    });

    testWidgets('ברירת המחדל של Material אינה קובעת צד — ומכאן הבאג בעברית', (
      tester,
    ) async {
      // בלי ההתנהגות הזו הצד נגזר מכיוון הטקסט, ובעברית הוא נופל לשמאל.
      await pumpList(tester);

      expect(orientationOf(tester), isNull);
    });

    testWidgets('אינה נוגעת בגלילה אופקית', (tester) async {
      await pumpList(
        tester,
        behavior: const EdgeScrollbarBehavior.right(),
        axis: Axis.horizontal,
      );

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('במובייל אין פס גלילה, כמו ב-MaterialScrollBehavior', (
      tester,
    ) async {
      await pumpList(
        tester,
        behavior: const EdgeScrollbarBehavior.right(),
        platform: TargetPlatform.android,
      );

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('גרירה בקצה ימין גוללת את הרשימה', (tester) async {
      final controller = await pumpList(
        tester,
        behavior: const EdgeScrollbarBehavior.right(),
        thumbAlwaysVisible: true,
      );
      expect(controller.offset, 0);

      final size = tester.getSize(find.byType(ListView));
      await tester.dragFrom(Offset(size.width - 4, 30), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(
        controller.offset,
        greaterThan(0),
        reason: 'האגודל אינו בקצה ימין — גרירה שם לא גללה כלום',
      );
    });

    testWidgets('בברירת המחדל בעברית גרירה בקצה ימין אינה גוללת (הבאג)', (
      tester,
    ) async {
      final controller = await pumpList(tester, thumbAlwaysVisible: true);

      final size = tester.getSize(find.byType(ListView));
      await tester.dragFrom(Offset(size.width - 4, 30), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    });

    testWidgets('גרירה בקצה שמאל אינה גוללת כשהפס מוצמד לימין', (tester) async {
      final controller = await pumpList(
        tester,
        behavior: const EdgeScrollbarBehavior.right(),
        thumbAlwaysVisible: true,
      );

      await tester.dragFrom(const Offset(4, 30), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    });
  });
}
