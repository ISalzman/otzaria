import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/search_pane_base.dart';

void main() {
  testWidgets('מציג toolbar של תוצאות באותה שורה מול מונה התוצאות',
      (tester) async {
    final controller = TextEditingController(text: 'נחל');
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
            resultToolbar: const Text(
              '1 מתוך 4',
              textDirection: TextDirection.rtl,
            ),
            resultCountString: 'נמצאו 4 תוצאות',
            resultsWidget: const SizedBox.shrink(),
            isNoResults: false,
            resetSearchCallback: () {},
          ),
        ),
      ),
    );

    final toolbarFinder = find.text('1 מתוך 4');
    final counterFinder = find.text('נמצאו 4 תוצאות');

    expect(toolbarFinder, findsOneWidget);
    expect(counterFinder, findsOneWidget);
    final toolbarRect = tester.getRect(toolbarFinder);
    final counterRect = tester.getRect(counterFinder);

    expect(
      (toolbarRect.center.dy - counterRect.center.dy).abs(),
      lessThan(4),
    );
    expect(toolbarRect.left, greaterThan(counterRect.left));
  });
}
