import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/search/models/external_search_status.dart';
import 'package:otzaria/search/view/external_search_results_section.dart';
import 'package:otzaria/search/view/full_text_settings_widgets.dart';
import 'package:otzaria/search/view/tantivy_search_results.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class RecordingSearchBloc extends SearchBloc {
  RecordingSearchBloc(SearchState initialSearchState) {
    emit(initialSearchState);
  }

  @override
  void add(SearchEvent event) {
    if (event is! LoadMoreResults) {
      super.add(event);
    }
  }
}

const _status = ExternalSearchStatus(
  sourceTitle: 'היברובוקס',
  loading: false,
  books: 3,
  hits: 7,
);

void main() {
  late RecordingSearchBloc searchBloc;
  late MockSettingsBloc settingsBloc;
  late SearchingTab tab;

  setUp(() {
    searchBloc = RecordingSearchBloc(
      const SearchState(searchQuery: 'בדיקה', totalResults: 0, results: []),
    );
    settingsBloc = MockSettingsBloc();
    tab = SearchingTab('חיפוש', 'בדיקה');
  });

  tearDown(() async {
    tab.dispose();
    await searchBloc.close();
    await settingsBloc.close();
  });

  void stubSettings({required bool externalResultsFirst}) {
    whenListen(
      settingsBloc,
      const Stream<SettingsState>.empty(),
      initialState: SettingsState.initial().copyWith(
        externalResultsFirst: externalResultsFirst,
      ),
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SearchBloc>.value(value: searchBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: Scaffold(body: child),
      ),
    );
  }

  group('סדר הבלוק החיצוני ברשימה המאוחדת', () {
    testWidgets('ברירת המחדל (מאוחרות) — הבלוק החיצוני אחרון', (tester) async {
      stubSettings(externalResultsFirst: false);
      await tester.pumpWidget(
        wrap(SizedBox(height: 500, child: TantivySearchResults(tab: tab))),
      );
      await tester.pump();

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollView.slivers.last, isA<ExternalSearchResultsSection>());
      expect(
        scrollView.slivers.first,
        isNot(isA<ExternalSearchResultsSection>()),
      );
    });

    testWidgets('"קודמות" — הבלוק החיצוני ראשון', (tester) async {
      stubSettings(externalResultsFirst: true);
      await tester.pumpWidget(
        wrap(SizedBox(height: 500, child: TantivySearchResults(tab: tab))),
      );
      await tester.pump();

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollView.slivers.first, isA<ExternalSearchResultsSection>());
    });

    testWidgets('החלפת ההגדרה מזיזה את הבלוק בלי לפרק את ה-State שלו', (
      tester,
    ) async {
      // רגרסיה: בלי key על ה-sliver החיצוני, שינוי הסדר פירק ובנה מחדש את
      // ה-State של המדור — מה שירה חיפוש חיצוני חדש במקום רק להחליף מקום.
      final settingsStream = StreamController<SettingsState>();
      addTearDown(settingsStream.close);
      whenListen(
        settingsBloc,
        settingsStream.stream,
        initialState: SettingsState.initial().copyWith(
          externalResultsFirst: false,
        ),
      );
      tab.externalSearchStatus.value = _status;
      await tester.pumpWidget(
        wrap(SizedBox(height: 500, child: TantivySearchResults(tab: tab))),
      );
      await tester.pump();

      // המדור מרנדר sliver ריק (אין ספק פעיל ב-SearchBloc המדומה) ולכן הוא
      // "offstage" עבור finders — מכאן ה-skipOffstage: false.
      final section = find.byType(
        ExternalSearchResultsSection,
        skipOffstage: false,
      );
      final stateBefore = tester.state(section);

      settingsStream.add(
        SettingsState.initial().copyWith(externalResultsFirst: true),
      );
      await tester.pump();
      await tester.pump();

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollView.slivers.first, isA<ExternalSearchResultsSection>());
      expect(tester.state(section), same(stateBefore));

      // פירוק העץ בזמן שהטאב חי: dispose של המדור כותב ל-notifier של הטאב,
      // ו-tearDown מפרק את הטאב לפני הפירוק האוטומטי של סוף הטסט.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('ExternalResultsPositionControl', () {
    testWidgets('בלי ספק חיצוני פעיל הפקד מסתיר את עצמו', (tester) async {
      stubSettings(externalResultsFirst: false);
      await tester.pumpWidget(
        wrap(ExternalResultsPositionControl(tab: tab)),
      );
      await tester.pump();

      expect(find.textContaining('היברובוקס'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets); // shrink בלבד
    });

    testWidgets('עם ספק פעיל מוצג בורר בשם המקור, ובחירה מעדכנת את ההגדרה', (
      tester,
    ) async {
      stubSettings(externalResultsFirst: false);
      tab.externalSearchStatus.value = _status;
      await tester.pumpWidget(
        wrap(ExternalResultsPositionControl(tab: tab)),
      );
      await tester.pump();

      // שם המקור מגיע מהצהרת התוסף — לא קבוע בקוד.
      expect(find.text('תוצאות מהיברובוקס מאוחרות'), findsOneWidget);

      await tester.tap(find.text('תוצאות מהיברובוקס מאוחרות'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('תוצאות מהיברובוקס קודמות').last);
      await tester.pumpAndSettle();

      verify(
        () => settingsBloc.add(const UpdateExternalResultsFirst(true)),
      ).called(1);
    });
  });
}
