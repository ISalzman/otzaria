import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/dual_adaptive_reader_pane.dart';

void main() {
  Widget buildPane({
    required double width,
    required bool showLeftPane,
    required bool showRightPane,
    required VoidCallback onCloseLeftPane,
    required VoidCallback onCloseRightPane,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: 700,
            child: DualAdaptiveReaderPane(
              mainContent: const Center(child: Text('main')),
              showLeftPane: showLeftPane,
              leftPaneContent: const Center(child: Text('left pane')),
              leftPaneWidth: 220,
              leftMinPaneWidth: 180,
              onCloseLeftPane: onCloseLeftPane,
              showRightPane: showRightPane,
              rightPaneContent: const Center(child: Text('right pane')),
              rightPaneWidth: 240,
              rightMinPaneWidth: 180,
              onCloseRightPane: onCloseRightPane,
              minMainContentWidth: 500,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('DualAdaptiveReaderPane shows both panes side by side when wide',
      (tester) async {
    await tester.pumpWidget(
      buildPane(
        width: 1400,
        showLeftPane: true,
        showRightPane: true,
        onCloseLeftPane: () {},
        onCloseRightPane: () {},
      ),
    );

    expect(find.text('main'), findsOneWidget);
    expect(find.text('left pane'), findsOneWidget);
    expect(find.text('right pane'), findsOneWidget);
  });

  testWidgets('DualAdaptiveReaderPane closes overlay pane on scrim tap',
      (tester) async {
    var leftPaneOpen = true;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return buildPane(
            width: 620,
            showLeftPane: leftPaneOpen,
            showRightPane: false,
            onCloseLeftPane: () {
              setState(() {
                leftPaneOpen = false;
              });
            },
            onCloseRightPane: () {},
          );
        },
      ),
    );

    expect(find.text('left pane'), findsOneWidget);

    await tester.tapAt(const Offset(320, 300));
    await tester.pumpAndSettle();

    expect(find.text('left pane'), findsNothing);
    expect(find.text('main'), findsOneWidget);
  });
}
