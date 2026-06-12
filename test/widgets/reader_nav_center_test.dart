import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/widgets/navigation/reader_nav_center.dart';

void main() {
  group('ReaderNavCenter', () {
    testWidgets('מציג כותרת וארבעה כפתורי ניווט שמפעילים את ה-callbacks',
        (tester) async {
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());
      addTearDown(settingsBloc.close);

      final pressed = <String>[];
      await tester.pumpWidget(
        _buildHarness(
          settingsBloc: settingsBloc,
          child: ReaderNavCenter(
            title: const Text('ספר בדיקה'),
            prevMajorTooltip: 'פרק קודם',
            prevMinorTooltip: 'קטע קודם',
            nextMinorTooltip: 'קטע הבא',
            nextMajorTooltip: 'פרק הבא',
            onPrevMajor: () => pressed.add('prevMajor'),
            onPrevMinor: () => pressed.add('prevMinor'),
            onNextMinor: () => pressed.add('nextMinor'),
            onNextMajor: () => pressed.add('nextMajor'),
          ),
        ),
      );

      expect(find.text('ספר בדיקה'), findsOneWidget);

      for (final tooltip in ['פרק קודם', 'קטע קודם', 'קטע הבא', 'פרק הבא']) {
        await tester.tap(find.byTooltip(tooltip));
      }
      expect(pressed, ['prevMajor', 'prevMinor', 'nextMinor', 'nextMajor']);
    });

    testWidgets('במרכז צר הכותרת מתכווצת ואין overflow', (tester) async {
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());
      addTearDown(settingsBloc.close);

      await tester.pumpWidget(
        _buildHarness(
          settingsBloc: settingsBloc,
          child: SizedBox(
            width: 300,
            child: ReaderNavCenter(
              title: const Text(
                'כותרת ארוכה מאוד מאוד מאוד שלא נכנסת במקום צר',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              prevMajorTooltip: 'פרק קודם',
              prevMinorTooltip: 'קטע קודם',
              nextMinorTooltip: 'קטע הבא',
              nextMajorTooltip: 'פרק הבא',
              onPrevMajor: () {},
              onPrevMinor: () {},
              onNextMinor: () {},
              onNextMajor: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildHarness({
  required SettingsBloc settingsBloc,
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<SettingsBloc>.value(
        value: settingsBloc,
        child: Center(child: child),
      ),
    ),
  );
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
