import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/controls/bar_split_button.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('לחיצה על החלק הראשי מפעילה את הפעולה ולא פותחת תפריט', (
    tester,
  ) async {
    var primaryTaps = 0;
    await tester.pumpWidget(
      host(
        BarSplitButton<String>(
          icon: FluentIcons.bookmark_24_regular,
          tooltip: 'שמור',
          onPressed: () => primaryTaps++,
          entries: const [AppMenuEntry(value: 'a', label: 'אפשרות א')],
          onSelected: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.bookmark_24_regular));
    await tester.pumpAndSettle();

    expect(primaryTaps, 1);
    expect(find.text('אפשרות א'), findsNothing);
  });

  testWidgets('לחיצה על החץ פותחת את התפריט ובחירה מחזירה את הערך', (
    tester,
  ) async {
    var primaryTaps = 0;
    String? selected;
    await tester.pumpWidget(
      host(
        BarSplitButton<String>(
          icon: FluentIcons.bookmark_24_regular,
          tooltip: 'שמור',
          onPressed: () => primaryTaps++,
          entries: const [
            AppMenuEntry(value: 'a', label: 'אפשרות א'),
            AppMenuEntry(value: 'b', label: 'אפשרות ב'),
          ],
          onSelected: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.chevron_down_16_regular));
    await tester.pumpAndSettle();
    expect(find.text('אפשרות א'), findsOneWidget);

    await tester.tap(find.text('אפשרות ב'));
    await tester.pumpAndSettle();

    expect(selected, 'b');
    expect(primaryTaps, 0);
  });

  testWidgets('בלי פריטי תפריט החץ מושבת ואינו פותח דבר', (tester) async {
    await tester.pumpWidget(
      host(
        BarSplitButton<String>(
          icon: FluentIcons.bookmark_24_regular,
          tooltip: 'שמור',
          onPressed: () {},
          entries: const [],
          onSelected: (_) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.chevron_down_16_regular));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsNothing);
  });
}
