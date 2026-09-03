import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/nav_rail_column.dart';
import 'package:otzaria/widgets/navigation/nav_rail_item.dart';

void main() {
  Widget buildRail({required double height, int itemCount = 5}) {
    NavRailItem item(String label) => NavRailItem(
      icon: FluentIcons.book_24_regular,
      iconFilled: FluentIcons.book_24_filled,
      label: label,
      isSelected: false,
      onTap: () {},
    );

    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: NavRailItem.width,
            height: height,
            child: NavRailColumn(
              items: [
                for (int i = 0; i < itemCount; i++) item('פריט $i'),
              ],
              bottomItem: item('הגדרות'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('אינו חורג כשהגובה קטן מדי — הסרגל גולש', (tester) async {
    // 408 — הגובה שנותר לסרגל באנדרואיד כשהמקלדת הווירטואלית פתוחה.
    await tester.pumpWidget(buildRail(height: 408));
    await tester.pump();

    expect(tester.takeException(), isNull);

    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
    expect(
      scrollable.controller?.position.maxScrollExtent ??
          Scrollable.of(
            tester.element(find.byType(NavRailItem).first),
          ).position.maxScrollExtent,
      greaterThan(0),
      reason: 'התוכן חייב לחרוג מהגובה, אחרת הטסט אינו בודק כלום',
    );
  });

  testWidgets('בגובה רגיל הפריט התחתון צמוד לתחתית', (tester) async {
    await tester.pumpWidget(buildRail(height: 560));
    await tester.pump();

    expect(tester.takeException(), isNull);

    final settings = find.widgetWithText(NavRailItem, 'הגדרות');
    expect(tester.getRect(settings).bottom, closeTo(560, 0.5));
  });
}
