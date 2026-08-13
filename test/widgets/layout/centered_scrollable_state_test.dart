import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/layout/centered_scrollable_state.dart';

/// גדלי חלון שבהם מסך מצב טיפוסי (אייקון 64 + טקסטים + כפתור) אינו נכנס:
/// טלפון לרוחב, מסך מפוצל וחלון דסקטופ נמוך.
const _shortWindows = [
  Size(640, 360),
  Size(800, 300),
  Size(360, 400),
];

Widget _wrap(Widget child, {Size? size}) => MaterialApp(
  home: Scaffold(
    body: size == null ? child : SizedBox.fromSize(size: size, child: child),
  ),
);

Widget _tallContent() => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const Icon(Icons.folder, size: 64),
    const SizedBox(height: 24),
    const Text('כותרת'),
    const SizedBox(height: 200),
    ElevatedButton(onPressed: () {}, child: const Text('פעולה')),
  ],
);

Widget _shortContent() => const Column(
  mainAxisSize: MainAxisSize.min,
  children: [Text('קצר')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CenteredScrollableState', () {
    testWidgets('תוכן נמוך ממורכז אנכית בלי גלילה', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CenteredScrollableState(child: _shortContent()),
          size: const Size(400, 600),
        ),
      );

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.maxScrollExtent, 0);

      final area = tester.getRect(find.byType(CenteredScrollableState));
      final text = tester.getRect(find.text('קצר'));
      expect((text.center.dy - area.center.dy).abs(), lessThan(1));
    });

    testWidgets('תוכן גבוה נעשה גליל במקום להיחתך', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CenteredScrollableState(child: _tallContent()),
          size: const Size(400, 300),
        ),
      );

      expect(tester.takeException(), isNull);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.maxScrollExtent, greaterThan(0));

      final button = find.text('פעולה');
      await tester.ensureVisible(button);
      expect(button.hitTestable(), findsOneWidget);
    });

    testWidgets('padding מוחל בתוך אזור הגלילה', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CenteredScrollableState(
            padding: const EdgeInsets.all(32),
            child: _shortContent(),
          ),
          size: const Size(400, 600),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.padding, const EdgeInsets.all(32));
      // גם עם padding גדול המרכוז נשמר — minHeight מקזז אותו.
      final area = tester.getRect(find.byType(CenteredScrollableState));
      final text = tester.getRect(find.text('קצר'));
      expect((text.center.dy - area.center.dy).abs(), lessThan(1));
    });

    testWidgets('אינו קורס בגובה בלתי-מוגבל', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: SizedBox(
              height: 500,
              child: CenteredScrollableState(child: _shortContent()),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('קצר'), findsOneWidget);
    });

    for (final size in _shortWindows) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: '
          'הכפתור נשאר נגיש', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrap(CenteredScrollableState(child: _tallContent())),
        );

        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('פעולה'));
        expect(find.text('פעולה').hitTestable(), findsOneWidget);
      });
    }
  });
}
