import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/nav_panel_search.dart';
import 'package:otzaria/widgets/navigation/search_pane_base.dart';

/// במסך צר שדה החיפוש נשאר בתוך חלונית הניווט, ו-TabBarView בונה את הלשונית
/// השכנה כבר בתחילת ההחלקה. autofocus חסר-תנאי היה חוטף שם את הפוקוס ופותח
/// את מקלדת המערכת בלי שהמשתמש ביקש.
void main() {
  Widget buildPanel({
    required NavPanelSearchHost host,
    required TabController Function() attach,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: NavPanelSearchScope(
          host: host,
          child: TabBarView(
            controller: attach(),
            children: [
              const NavPanelSearchSlot(
                index: 0,
                child: Center(child: Text('ניווט')),
              ),
              NavPanelSearchSlot(
                index: 1,
                child: SearchPaneBase(
                  searchController: controller,
                  focusNode: focusNode,
                  resultsWidget: const SizedBox.shrink(),
                  isNoResults: false,
                  resetSearchCallback: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('החלקה שבונה את לשונית החיפוש השכנה אינה ממקדת את שדה החיפוש', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = TextEditingController();
    final focusNode = FocusNode(debugLabel: 'searchTabField');
    final host = NavPanelSearchHost();
    late TabController tabController;
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
      host.dispose();
      tabController.dispose();
    });

    await tester.pumpWidget(
      buildPanel(
        host: host,
        attach: () {
          tabController = TabController(length: 2, vsync: const TestVSync());
          return tabController;
        },
        controller: controller,
        focusNode: focusNode,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    // גרירה חלקית: השכנה כבר נבנית, אך הלשונית הפעילה עדיין 0.
    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget, reason: 'השכנה אכן נבנתה');
    expect(focusNode.hasFocus, isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('הלשונית הפעילה כן מקבלת פוקוס אוטומטי', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = TextEditingController();
    final focusNode = FocusNode(debugLabel: 'searchTabField');
    final host = NavPanelSearchHost();
    late TabController tabController;
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
      host.dispose();
      tabController.dispose();
    });

    await tester.pumpWidget(
      buildPanel(
        host: host,
        attach: () {
          tabController = TabController(length: 2, vsync: const TestVSync());
          tabController.addListener(() => host.activeTab = tabController.index);
          return tabController;
        },
        controller: controller,
        focusNode: focusNode,
      ),
    );
    await tester.pumpAndSettle();

    tabController.index = 1;
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('מחוץ לחלונית ניווט הפוקוס האוטומטי נשמר', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchPaneBase(
            searchController: controller,
            focusNode: focusNode,
            resultsWidget: const SizedBox.shrink(),
            isNoResults: false,
            resetSearchCallback: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
  });
}
