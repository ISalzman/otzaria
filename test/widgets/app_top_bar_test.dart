import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/widgets/app_top_bar.dart';

void main() {
  group('AppTopBar', () {
    testWidgets(
      'does not update height notifier synchronously when visibility notifier instance changes',
      (tester) async {
        final settingsBloc = _TestSettingsBloc(SettingsState.initial());
        addTearDown(settingsBloc.close);

        final totalHeightNotifier = ValueNotifier<double>(0);
        addTearDown(totalHeightNotifier.dispose);

        final firstVisibilityNotifier = ValueNotifier<bool>(true);
        addTearDown(firstVisibilityNotifier.dispose);

        await tester.pumpWidget(
          _TestApp(
            settingsBloc: settingsBloc,
            totalHeightNotifier: totalHeightNotifier,
            visibilityNotifier: firstVisibilityNotifier,
          ),
        );
        await tester.pump();

        final secondVisibilityNotifier = ValueNotifier<bool>(false);
        addTearDown(secondVisibilityNotifier.dispose);

        await tester.pumpWidget(
          _TestApp(
            settingsBloc: settingsBloc,
            totalHeightNotifier: totalHeightNotifier,
            visibilityNotifier: secondVisibilityNotifier,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.settingsBloc,
    required this.totalHeightNotifier,
    required this.visibilityNotifier,
  });

  final SettingsBloc settingsBloc;
  final ValueNotifier<double> totalHeightNotifier;
  final ValueNotifier<bool> visibilityNotifier;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<SettingsBloc>.value(
          value: settingsBloc,
          child: Column(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: totalHeightNotifier,
                builder: (context, height, _) {
                  return Text(
                    'height: $height',
                    textDirection: TextDirection.rtl,
                  );
                },
              ),
              AppTopBar(
                totalHeightNotifier: totalHeightNotifier,
                secondaryRowVisible: visibilityNotifier,
                center: const SizedBox.shrink(),
                secondaryRow: const SizedBox(
                  height: 24,
                  child: Text(
                    'שורה שניה',
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
