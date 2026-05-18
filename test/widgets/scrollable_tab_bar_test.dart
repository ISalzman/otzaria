import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/scrollable_tab_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'כש-tabWidth מסופק ואין overflow, כל טאב נעטף ברוחב קבוע וללא IntrinsicWidth',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: _TabBarHost(
              tabWidth: 120,
              hideArrowsWhenNotScrollable: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(IntrinsicWidth), findsNothing);

    final sizedBoxes = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(ScrollableTabBarWithArrows),
            matching: find.byType(SizedBox),
          ),
        )
        .where((box) => box.width == 120 && box.child is Tab)
        .toList();

    expect(sizedBoxes, hasLength(2));
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}

class _TabBarHost extends StatefulWidget {
  final double? tabWidth;
  final bool hideArrowsWhenNotScrollable;

  const _TabBarHost({
    this.tabWidth,
    this.hideArrowsWhenNotScrollable = false,
  });

  @override
  State<_TabBarHost> createState() => _TabBarHostState();
}

class _TabBarHostState extends State<_TabBarHost>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollableTabBarWithArrows(
      controller: _controller,
      tabWidth: widget.tabWidth,
      hideArrowsWhenNotScrollable: widget.hideArrowsWhenNotScrollable,
      tabs: const [
        Tab(text: 'א'),
        Tab(text: 'ב'),
      ],
    );
  }
}
