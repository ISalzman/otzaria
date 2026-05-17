import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Main window navigation page transition', () {
    testWidgets(
      'מעבר ל"הגדרות" מספרייה מדלג ישירות ולא מנפיש דרך עמוד "כלים"',
      (tester) async {
        final widgetKey = GlobalKey<_NavigationAwarePageViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _NavigationAwarePageView(key: widgetKey),
            ),
          ),
        );
        await tester.pumpAndSettle();

        widgetKey.currentState!.navigateTo(Screen.settings);
        await tester.pump();

        expect(widgetKey.currentState!.controller.page, 3.0);
        expect(find.text('page-2'), findsNothing);
        expect(find.text('page-1'), findsNothing);
        expect(find.text('page-3'), findsOneWidget);
      },
    );

    testWidgets(
      'מעבר מ"הגדרות" לספרייה מדלג ישירות ולא מנפיש דרך עמוד "כלים"',
      (tester) async {
        final widgetKey = GlobalKey<_NavigationAwarePageViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _NavigationAwarePageView(
                key: widgetKey,
                initialPage: 3,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('page-3'), findsOneWidget);

        widgetKey.currentState!.navigateTo(Screen.library);
        await tester.pump();

        expect(widgetKey.currentState!.controller.page, 0.0);
        expect(find.text('page-2'), findsNothing);
        expect(find.text('page-1'), findsNothing);
        expect(find.text('page-0'), findsOneWidget);
      },
    );

    testWidgets(
      'מעבר ל"כלים" עצמו עדיין מנפיש (לא קופץ מיידית)',
      (tester) async {
        final widgetKey = GlobalKey<_NavigationAwarePageViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _NavigationAwarePageView(key: widgetKey),
            ),
          ),
        );
        await tester.pumpAndSettle();

        widgetKey.currentState!.navigateTo(Screen.more);
        await tester.pump();

        // animateToPage לא מסיים בפריים בודד — עמוד לא הגיע ל-2 מיד.
        expect(widgetKey.currentState!.controller.page, isNot(2.0));

        await tester.pumpAndSettle();
        expect(widgetKey.currentState!.controller.page, 2.0);
      },
    );

    testWidgets(
      'מעבר ספרייה→עיון נשאר מונפש (לא חוצה את עמוד הכלים)',
      (tester) async {
        final widgetKey = GlobalKey<_NavigationAwarePageViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _NavigationAwarePageView(key: widgetKey),
            ),
          ),
        );
        await tester.pumpAndSettle();

        widgetKey.currentState!.navigateTo(Screen.reading);
        await tester.pump();

        expect(widgetKey.currentState!.controller.page, isNot(1.0));

        await tester.pumpAndSettle();
        expect(widgetKey.currentState!.controller.page, 1.0);
      },
    );
  });
}

/// וידג'ט-בדיקה שמשכפל את לוגיקת מעבר העמודים מ-`_MainWindowScreenState._handleNavigationChange`.
/// אם הלוגיקה ב-main_window_screen.dart משתנה, יש לעדכן גם כאן.
class _NavigationAwarePageView extends StatefulWidget {
  const _NavigationAwarePageView({
    super.key,
    this.initialPage = 0,
  });

  final int initialPage;

  @override
  State<_NavigationAwarePageView> createState() =>
      _NavigationAwarePageViewState();
}

class _NavigationAwarePageViewState extends State<_NavigationAwarePageView> {
  late PageController controller;
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPage;
    controller = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  int? _pageIndexForScreen(Screen screen) {
    switch (screen) {
      case Screen.library:
        return 0;
      case Screen.reading:
      case Screen.search:
        return 1;
      case Screen.more:
        return 2;
      case Screen.settings:
        return 3;
      case Screen.find:
        return null;
    }
  }

  void navigateTo(Screen target) {
    final targetPage = _pageIndexForScreen(target);
    if (targetPage == null || _currentPageIndex == targetPage) {
      return;
    }
    setState(() {
      _currentPageIndex = targetPage;
    });
    if (!controller.hasClients) return;
    final currentPage = controller.page?.round() ?? _currentPageIndex;
    final crossesTools = (currentPage < 2 && targetPage > 2) ||
        (currentPage > 2 && targetPage < 2);
    if (crossesTools) {
      controller.jumpToPage(targetPage);
    } else {
      controller.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        4,
        (index) => Center(child: Text('page-$index')),
      ),
    );
  }
}
