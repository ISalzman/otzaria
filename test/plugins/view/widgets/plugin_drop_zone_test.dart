import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/services/plugin_file_drop_service.dart';
import 'package:otzaria/plugins/view/widgets/plugin_drop_zone.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

class _RecordingPluginSystemBloc
    extends Bloc<PluginSystemEvent, PluginSystemState>
    implements PluginSystemBloc {
  _RecordingPluginSystemBloc() : super(PluginSystemInitial());

  final List<PluginSystemEvent> added = [];

  @override
  void add(PluginSystemEvent event) => added.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState);
}

class _StubSettingsRepository implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// יחס פיקסלים גדול מ-1 כדי לוודא את ההמרה מפיקסלים פיזיים ללוגיים.
const double _ratio = 2.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingPluginSystemBloc pluginBloc;
  late PluginFileDropService service;

  setUp(() {
    pluginBloc = _RecordingPluginSystemBloc();
    service = PluginFileDropService(
      channel: const MethodChannel('test_file_drop'),
    );
    PluginFileDropService.instance = service;
  });

  tearDown(() => pluginBloc.close());

  // אזור הקליטה תופס 100x100 לוגיים בפינה השמאלית-עליונה של חלון 400x400.
  Future<void> pumpZone(WidgetTester tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 400),
          devicePixelRatio: _ratio,
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PluginSystemBloc>.value(value: pluginBloc),
            BlocProvider<SettingsBloc>.value(
              value: _TestSettingsBloc(SettingsState.initial()),
            ),
          ],
          child: RepositoryProvider<SettingsRepository>.value(
            value: _StubSettingsRepository(),
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: PluginDropZone(child: Container()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  MethodCall drag(
    String event, {
    List<String> paths = const [],
    required double logicalX,
    required double logicalY,
  }) => MethodCall('onFileDrop', {
    'event': event,
    'paths': paths,
    'x': logicalX * _ratio,
    'y': logicalY * _ratio,
  });

  testWidgets('גרירת ‎.otzplugin‎ מעל האזור מציגה חיווי שחרור', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag(
        'enter',
        paths: ['C:/x.otzplugin'],
        logicalX: 50,
        logicalY: 50,
      ),
    );
    await tester.pump();

    expect(find.text('שחרר כדי להתקין את התוסף'), findsOneWidget);
  });

  testWidgets('גרירה מחוץ לאזור אינה מציגה חיווי', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag(
        'enter',
        paths: ['C:/x.otzplugin'],
        logicalX: 300,
        logicalY: 300,
      ),
    );
    await tester.pump();

    expect(find.text('שחרר כדי להתקין את התוסף'), findsNothing);
  });

  testWidgets('קובץ שאינו תוסף אינו מציג חיווי', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('enter', paths: ['C:/x.txt'], logicalX: 50, logicalY: 50),
    );
    await tester.pump();

    expect(find.text('שחרר כדי להתקין את התוסף'), findsNothing);
  });

  testWidgets('סמן הגרירה מאושר רק מעל האזור', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('enter', paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    await tester.pump();
    expect(service.acceptedForTest, isTrue);

    await service.handleNativeCall(
      drag('over', logicalX: 300, logicalY: 300),
    );
    await tester.pump();
    expect(service.acceptedForTest, isFalse);
  });

  testWidgets('קובץ שאינו תוסף אינו מאשר את הסמן', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('enter', paths: ['C:/x.txt'], logicalX: 50, logicalY: 50),
    );
    await tester.pump();

    expect(service.acceptedForTest, isFalse);
  });

  testWidgets('סיום הגרירה מבטל את אישור הסמן', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('enter', paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    await tester.pump();
    expect(service.acceptedForTest, isTrue);

    await service.handleNativeCall(
      MethodCall('onFileDrop', {'event': 'leave'}),
    );
    await tester.pump();
    expect(service.acceptedForTest, isFalse);
  });

  testWidgets('שחרור בתוך האזור מבקש התקנה', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('drop', paths: ['C:/x.otzplugin'], logicalX: 50, logicalY: 50),
    );
    await tester.pumpAndSettle();

    expect(pluginBloc.added, hasLength(1));
    final event = pluginBloc.added.single as InstallPluginRequested;
    expect(event.archivePath, 'C:/x.otzplugin');
  });

  testWidgets('שחרור מחוץ לאזור אינו מבקש התקנה', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('drop', paths: ['C:/x.otzplugin'], logicalX: 300, logicalY: 300),
    );
    await tester.pumpAndSettle();

    expect(pluginBloc.added, isEmpty);
  });

  testWidgets('שחרור קובץ שאינו תוסף אינו מבקש התקנה', (tester) async {
    await pumpZone(tester);

    await service.handleNativeCall(
      drag('drop', paths: ['C:/x.txt'], logicalX: 50, logicalY: 50),
    );
    await tester.pumpAndSettle();

    expect(pluginBloc.added, isEmpty);
  });
}
