import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/view/full_text_settings_widgets.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';

/// issue #1120 — במקורב המספר הוא מרחק עריכה, והמנוע חותך אותו ל-0..2
/// (`_fuzzyDistance`); שדה שמציע עד 30 מבטיח שכל ערך מעל 2 יתנהג כמו 2.
void main() {
  Widget harness(SearchBloc bloc, SearchingTab tab) => MaterialApp(
    home: BlocProvider<SearchBloc>.value(
      value: bloc,
      child: Scaffold(
        body: Center(child: FuzzyDistance(tab: tab, triggerSearch: false)),
      ),
    ),
  );

  testWidgets('במקורב שדה המרחק מוגבל ל-2, במדויק נשאר 30', (tester) async {
    final tab = SearchingTab('חיפוש', null);
    final bloc = tab.searchBloc;
    addTearDown(bloc.close);

    await tester.pumpWidget(harness(bloc, tab));
    expect(tester.widget<SpinBox>(find.byType(SpinBox)).max, 30);

    bloc.add(SetSearchModeWithoutSearch(SearchMode.fuzzy));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SpinBox>(find.byType(SpinBox)).max,
      2,
      reason: 'המנוע מתעלם מכל מרחק מעל 2 — הממשק לא יציע ערכים חסרי משמעות',
    );
  });

  test('מעבר למקורב עם מרווח גדול מ-2 מצמצם אותו לטווח שהמנוע מכבד', () async {
    final bloc = SearchBloc();
    addTearDown(bloc.close);

    final fuzzyState = bloc.stream.firstWhere(
      (s) => s.configuration.searchMode == SearchMode.fuzzy,
    );
    bloc.add(UpdateDistanceWithoutSearch(7));
    bloc.add(SetSearchModeWithoutSearch(SearchMode.fuzzy));

    expect((await fuzzyState).configuration.distance, lessThanOrEqualTo(2));
  });
}
