import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/search/view/tantivy_search_results.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:search_engine/search_engine.dart';

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class RecordingSearchBloc extends SearchBloc {
  RecordingSearchBloc(this.initialSearchState) {
    emit(initialSearchState);
  }

  final SearchState initialSearchState;
  final List<SearchEvent> recordedEvents = [];

  @override
  void add(SearchEvent event) {
    recordedEvents.add(event);
    if (event is! LoadMoreResults) {
      super.add(event);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TantivySearchResults', () {
    late RecordingSearchBloc searchBloc;
    late MockSettingsBloc settingsBloc;
    late SearchingTab tab;

    setUp(() {
      settingsBloc = MockSettingsBloc();
      tab = SearchingTab('חיפוש', 'בדיקה');

      searchBloc = RecordingSearchBloc(
        SearchState(
          searchQuery: 'בדיקה',
          totalResults: 200,
          results: List.generate(
            100,
            (index) => SearchResult(
              id: BigInt.from(index + 1),
              title: 'ספר $index',
              reference: 'סימן $index',
              text: 'טקסט בדיקה $index',
              segment: BigInt.from(index),
              isPdf: false,
              filePath: 'book_$index.txt',
            ),
          ),
        ),
      );

      whenListen(
        settingsBloc,
        const Stream<SettingsState>.empty(),
        initialState: SettingsState.initial(),
      );
    });

    tearDown(() async {
      tab.dispose();
      await searchBloc.close();
      await settingsBloc.close();
    });

    testWidgets('גלילה לתחתית טוענת עוד תוצאות אוטומטית', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<SearchBloc>.value(value: searchBloc),
              BlocProvider<SettingsBloc>.value(value: settingsBloc),
            ],
            child: Scaffold(
              body: SizedBox(
                height: 500,
                child: TantivySearchResults(tab: tab),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -12000));
      await tester.pump();

      expect(
        searchBloc.recordedEvents.whereType<LoadMoreResults>().length,
        1,
      );
    });
  });
}
