// Regression test for: לחיצה על קטגוריה ב-sidebar של ההגדרות חייבת לאפס את
// שדה החיפוש. לפני התיקון, התוצאות (overrideContent) המשיכו להופיע כי
// `_changeTab` שינה רק את `_selectedIndex` בלי לנקות את `_searchQuery`.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/search/settings_search_field.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/widgets/navigation/sidebar_nav_item.dart';

import '../../test_helpers/memory_cache_provider.dart';

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _FakeSettingsRepository extends Fake implements SettingsRepository {
  @override
  bool hasProtectedModePassword() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  group('MySettingsScreen — איפוס חיפוש בעת מעבר טאב', () {
    late MockSettingsBloc settingsBloc;
    late _FakeSettingsRepository settingsRepository;

    setUp(() {
      settingsBloc = MockSettingsBloc();
      settingsRepository = _FakeSettingsRepository();
      whenListen(
        settingsBloc,
        const Stream<SettingsState>.empty(),
        initialState: SettingsState.initial(),
      );
    });

    Widget buildScreen() {
      return MaterialApp(
        home: RepositoryProvider<SettingsRepository>.value(
          value: settingsRepository,
          child: BlocProvider<SettingsBloc>.value(
            value: settingsBloc,
            child: const MySettingsScreen(),
          ),
        ),
      );
    }

    testWidgets(
      'לחיצה על קטגוריה ב-sidebar (desktop) מנקה את שדה החיפוש',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildScreen());
        await tester.pump(); // ProtectedSettingsWrapper postFrame
        await tester.pump();

        // הקלדה לשדה החיפוש
        final searchFieldFinder = find.byType(SettingsSearchField);
        expect(searchFieldFinder, findsOneWidget);
        final initial = tester.widget<SettingsSearchField>(searchFieldFinder);
        initial.controller.text = 'בדיקה';
        initial.onChanged('בדיקה');
        await tester.pump();
        expect(initial.controller.text, 'בדיקה');

        // לחיצה על קטגוריה אחרת (כתב) ב-sidebar
        await tester.tap(find.widgetWithText(SidebarNavItem, 'כתב'));
        await tester.pump();
        await tester.pump();

        // אחרי לחיצה — שדה החיפוש חייב להיות ריק
        final after = tester.widget<SettingsSearchField>(searchFieldFinder);
        expect(after.controller.text, isEmpty,
            reason: 'מעבר טאב חייב לאפס את שדה החיפוש');
      },
    );
  });
}
