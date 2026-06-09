import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/search/view/enhanced_search_field.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';

class MockNavigationBloc extends MockBloc<NavigationEvent, NavigationState>
    implements NavigationBloc {}

class _TestSearchDialogWrapper {
  final SearchingTab tab;

  _TestSearchDialogWrapper(this.tab);
}

void main() {
  testWidgets('שדה החיפוש מקבל רקע מלא מתוך ה-theme',
      (WidgetTester tester) async {
    final tab = SearchingTab('חיפוש', 'בדיקה');
    final navigationBloc = MockNavigationBloc();
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB85C38),
      ),
    );

    whenListen(
      navigationBloc,
      const Stream<NavigationState>.empty(),
      initialState: const NavigationState(currentScreen: Screen.search),
    );

    addTearDown(() async {
      await navigationBloc.close();
      tab.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<NavigationBloc>.value(value: navigationBloc),
            BlocProvider.value(value: tab.searchBloc),
          ],
          child: Scaffold(
            body: EnhancedSearchField(
              widget: _TestSearchDialogWrapper(tab),
              showInlineSearchButton: false,
            ),
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(textField.decoration?.filled, isTrue);
    expect(
      textField.decoration?.fillColor,
      theme.colorScheme.surfaceContainerHigh,
    );
    expect(textField.decoration?.labelText, 'חיפוש');
    expect(textField.decoration?.hintText, 'הקלד מילות חיפוש');
  });
}
