import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/scrollable_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("ללא overflow - אין כפתורי חץ בעץ הווידג'טים", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late TabController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              controller = TabController(length: 2, vsync: tester);
              return ScrollableTabBarWithArrows(
                controller: controller,
                tabs: const [Tab(text: 'טאב א'), Tab(text: 'טאב ב')],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);

    expect(find.byKey(const ValueKey('left-arrow')), findsNothing);
    expect(find.byKey(const ValueKey('right-arrow')), findsNothing);
  });

  testWidgets('עם overflow - מוצגים כפתורי חץ שמאל וימין', (tester) async {
    await tester.binding.setSurfaceSize(const Size(80, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tabs = List.generate(10, (i) => Tab(text: 'כרטיסיה ארוכה מספר $i'));
    late TabController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              controller = TabController(length: 10, vsync: tester);
              return ScrollableTabBarWithArrows(
                controller: controller,
                tabs: tabs,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);

    expect(find.byKey(const ValueKey('left-arrow')), findsOneWidget);
    expect(find.byKey(const ValueKey('right-arrow')), findsOneWidget);
  });

  testWidgets('onOverflowChanged מופעל עם true כשיש overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(80, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tabs = List.generate(10, (i) => Tab(text: 'כרטיסיה ארוכה מספר $i'));
    late TabController controller;
    bool? overflowValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              controller = TabController(length: 10, vsync: tester);
              return ScrollableTabBarWithArrows(
                controller: controller,
                tabs: tabs,
                onOverflowChanged: (v) => overflowValue = v,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);

    expect(overflowValue, isTrue);
  });

  testWidgets('hideArrowsWhenNotScrollable: true - אין overflow, אין חיצים',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late TabController controller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              controller = TabController(length: 2, vsync: tester);
              return ScrollableTabBarWithArrows(
                controller: controller,
                tabs: const [Tab(text: 'א'), Tab(text: 'ב')],
                hideArrowsWhenNotScrollable: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);

    expect(find.byKey(const ValueKey('left-arrow')), findsNothing);
    expect(find.byKey(const ValueKey('right-arrow')), findsNothing);
  });
}
