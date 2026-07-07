import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/panels/library_settings_panel.dart';

class _FakeSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  final List<SettingsEvent> dispatched = [];

  _FakeSettingsBloc({
    bool showExternalBooks = false,
    bool showOtzarHachochma = false,
    bool showHebrewBooks = false,
    bool autoSyncCatalogs = false,
  }) : super(SettingsState.initial().copyWith(
          showExternalBooks: showExternalBooks,
          showOtzarHachochma: showOtzarHachochma,
          showHebrewBooks: showHebrewBooks,
          autoSyncCatalogs: autoSyncCatalogs,
        )) {
    on<SettingsEvent>((event, emit) {
      dispatched.add(event);
      if (event is UpdateShowExternalBooks) {
        emit(state.copyWith(showExternalBooks: event.showExternalBooks));
      } else if (event is UpdateShowOtzarHachochma) {
        emit(state.copyWith(showOtzarHachochma: event.showOtzarHachochma));
      } else if (event is UpdateShowHebrewBooks) {
        emit(state.copyWith(showHebrewBooks: event.showHebrewBooks));
      } else if (event is UpdateAutoSyncCatalogs) {
        emit(state.copyWith(autoSyncCatalogs: event.autoSyncCatalogs));
      }
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(SettingsBloc settingsBloc) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: BlocProvider<SettingsBloc>.value(
          value: settingsBloc,
          child: const SingleChildScrollView(
            child: LibrarySettingsPanel(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('מציג "אל תציג" כשהצגת ספרים חיצוניים כבויה', (tester) async {
    await tester.pumpWidget(_wrap(_FakeSettingsBloc()));
    await tester.pumpAndSettle();

    expect(find.text('אל תציג'), findsOneWidget);
    expect(
      find.text('ספרים חיצוניים לא יוצגו בתוצאות החיפוש במסך הספרייה'),
      findsOneWidget,
    );
  });

  testWidgets('מציג "הצג הכל" כששני המקורות מופעלים', (tester) async {
    await tester.pumpWidget(_wrap(_FakeSettingsBloc(
      showExternalBooks: true,
      showOtzarHachochma: true,
      showHebrewBooks: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('הצג הכל'), findsOneWidget);
    expect(
      find.text(
          'יוצגו ספרים מאוצר החכמה ומהיברובוקס בתוצאות החיפוש במסך הספרייה'),
      findsOneWidget,
    );
  });

  testWidgets('מציג "אוצר החכמה בלבד" כשרק אוצר החכמה מופעל', (tester) async {
    await tester.pumpWidget(_wrap(_FakeSettingsBloc(
      showExternalBooks: true,
      showOtzarHachochma: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('אוצר החכמה בלבד'), findsOneWidget);
  });

  testWidgets('מציג "היברובוקס בלבד" כשרק היברובוקס מופעל', (tester) async {
    await tester.pumpWidget(_wrap(_FakeSettingsBloc(
      showExternalBooks: true,
      showHebrewBooks: true,
    )));
    await tester.pumpAndSettle();

    expect(find.text('היברובוקס בלבד'), findsOneWidget);
  });

  testWidgets('שורת הסנכרון האוטומטי מוצגת רק כשהצגת חיצוניים מופעלת',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeSettingsBloc()));
    await tester.pumpAndSettle();
    expect(find.text('סנכרון קטלוגים אוטומטי'), findsNothing);

    await tester.pumpWidget(_wrap(_FakeSettingsBloc(
      showExternalBooks: true,
      showOtzarHachochma: true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('סנכרון קטלוגים אוטומטי'), findsOneWidget);
  });

  testWidgets(
    'בחירת "אל תציג" מכבה את כל המקורות ואת הסנכרון האוטומטי',
    (tester) async {
      final settingsBloc = _FakeSettingsBloc(
        showExternalBooks: true,
        showOtzarHachochma: true,
        showHebrewBooks: true,
        autoSyncCatalogs: true,
      );

      await tester.pumpWidget(_wrap(settingsBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('הצג הכל'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('אל תציג').last);
      await tester.pumpAndSettle();

      expect(settingsBloc.state.showExternalBooks, isFalse);
      expect(settingsBloc.state.showOtzarHachochma, isFalse);
      expect(settingsBloc.state.showHebrewBooks, isFalse);
      expect(settingsBloc.state.autoSyncCatalogs, isFalse);
    },
  );
}
