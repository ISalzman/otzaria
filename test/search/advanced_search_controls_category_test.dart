import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/view/advanced_search_controls.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

import '../test_helpers/memory_cache_provider.dart';

Future<void> main() async {
  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets('אפשרויות פר-מילה מתעלמות מחלק @קטגוריה', (tester) async {
    final tab = SearchingTab('חיפוש', 'שלום @תורה');
    tab.useGlobalSearchOptions.value = false;
    tab.queryController.selection = const TextSelection.collapsed(offset: 9);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: AdvancedSearchControls(
              tab: tab,
              supportsCategorySyntax: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('בחר מילה'), findsOneWidget);
    expect(_alternativeFieldFinder, findsNothing);

    tab.queryController.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();

    expect(find.text('שלום'), findsOneWidget);
    expect(
      tester.widget<RtlTextField>(_alternativeFieldFinder).enabled,
      isTrue,
    );
  });
}

final _alternativeFieldFinder = find.byWidgetPredicate(
  (widget) =>
      widget is RtlTextField && widget.decoration?.labelText == 'מילה חילופית',
);
