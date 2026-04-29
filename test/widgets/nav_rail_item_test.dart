import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/nav_rail_item.dart';

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
}
