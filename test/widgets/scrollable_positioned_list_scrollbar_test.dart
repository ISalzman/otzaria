import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/feedback/scrollable_positioned_list_scrollbar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('פס הגלילה שומר רצועה נפרדת מהתוכן', (tester) async {
    final listener = ItemPositionsListener.create();
    final controller = ItemScrollController();
    const contentKey = Key('scroll-content');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollablePositionedListScrollbar(
            scrollController: controller,
            itemPositionsListener: listener,
            itemCount: 10,
            child: Container(key: contentKey),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byKey(contentKey)).dx, 12.0);
  });

  testWidgets('listener ישן לא מעדכן State אחרי החלפת widget ו-dispose',
      (tester) async {
    final firstListener = ItemPositionsListener.create();
    final secondListener = ItemPositionsListener.create();
    final controller = ItemScrollController();

    Widget build(ItemPositionsListener listener) {
      return MaterialApp(
        home: ScrollablePositionedListScrollbar(
          scrollController: controller,
          itemPositionsListener: listener,
          itemCount: 10,
          child: const SizedBox.expand(),
        ),
      );
    }

    await tester.pumpWidget(build(firstListener));
    await tester.pumpWidget(build(secondListener));

    (secondListener.itemPositions as ValueNotifier<Iterable<ItemPosition>>)
        .value = const [
      ItemPosition(index: 1, itemLeadingEdge: 0, itemTrailingEdge: 0.5),
    ];

    await tester.pumpWidget(const SizedBox.shrink());

    (firstListener.itemPositions as ValueNotifier<Iterable<ItemPosition>>)
        .value = const [
      ItemPosition(index: 1, itemLeadingEdge: 0, itemTrailingEdge: 0.5),
    ];

    expect(tester.takeException(), isNull);
  });
}
