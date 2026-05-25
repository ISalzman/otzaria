import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/nav_rail_item.dart';

void main() {
  testWidgets('NavRailItem מצמיד tourTargetKey לכפתור עצמו', (tester) async {
    final buttonKey = GlobalKey();
    final itemKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: NavRailItem(
            icon: FluentIcons.search_24_regular,
            label: 'איתור',
            isSelected: true,
            onTap: () {},
            tourTargetKey: buttonKey,
            tourItemKey: itemKey,
          ),
        ),
      ),
    );

    expect(buttonKey.currentWidget, isA<IconButton>());
    expect(itemKey.currentWidget, isA<SizedBox>());
  });

  group('NavRailItem imageAsset support', () {
    testWidgets(
      'renders ImageIcon when imageAsset is provided (instead of IconData)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: NavRailItem(
                imageAsset: 'assets/icon/שמור וזכור שחור ריק.png',
                label: 'שמור וזכור',
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        );

        // ה-tree צריך להכיל ImageIcon, לא Icon רגיל עם IconData fallback.
        expect(find.byType(ImageIcon), findsOneWidget);
        expect(
          find.byWidgetPredicate((w) =>
              w is Icon && w.icon == FluentIcons.wrench_24_regular),
          findsNothing,
          reason:
              'P3 regression: image-based built-in tools must NOT fall back '
              'to a generic wrench icon in the nav rail',
        );
      },
    );

    testWidgets(
      'ImageIcon color reflects selection state (selected vs unselected)',
      (tester) async {
        Widget itemWith(bool selected) => MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: NavRailItem(
                  imageAsset: 'assets/icon/שמור וזכור שחור ריק.png',
                  label: 'שמור וזכור',
                  isSelected: selected,
                  onTap: () {},
                ),
              ),
            );

        await tester.pumpWidget(itemWith(false));
        final unselected = tester.widget<ImageIcon>(find.byType(ImageIcon));
        final unselectedColor = unselected.color;

        await tester.pumpWidget(itemWith(true));
        final selected = tester.widget<ImageIcon>(find.byType(ImageIcon));
        final selectedColor = selected.color;

        expect(unselectedColor, isNotNull);
        expect(selectedColor, isNotNull);
        expect(selectedColor, isNot(equals(unselectedColor)),
            reason:
                'selected and unselected states must use different colors '
                'so the user sees which item is active');
      },
    );

    testWidgets(
      'when both icon and imageAsset are given, imageAsset wins',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: NavRailItem(
                icon: FluentIcons.wrench_24_regular,
                imageAsset: 'assets/icon/שמור וזכור שחור ריק.png',
                label: 'שמור וזכור',
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.byType(ImageIcon), findsOneWidget);
        // ה-Icon לא צריך להתרנדר — ImageIcon מחליף אותו לחלוטין
        expect(
          find.byWidgetPredicate((w) =>
              w is Icon && w.icon == FluentIcons.wrench_24_regular),
          findsNothing,
        );
      },
    );

    test(
      'asserts when both icon and imageAsset are null',
      () {
        expect(
          () => NavRailItem(
            label: 'broken',
            isSelected: false,
            onTap: () {},
          ),
          throwsAssertionError,
          reason: 'a NavRailItem with no visual must fail loudly at '
              'construction, not silently render an empty space',
        );
      },
    );
  });
}
