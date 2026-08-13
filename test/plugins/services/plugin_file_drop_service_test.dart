import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_file_drop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PluginFileDropService service;

  setUp(() {
    service = PluginFileDropService(
      channel: const MethodChannel('test_file_drop'),
    );
  });

  MethodCall call(
    String event, {
    List<String> paths = const [],
    double x = 0,
    double y = 0,
  }) => MethodCall('onFileDrop', {
    'event': event,
    'paths': paths,
    'x': x,
    'y': y,
  });

  test('enter קובע את הגרירה הפעילה עם הנתיבים והמיקום', () async {
    await service.handleNativeCall(
      call('enter', paths: ['C:/a.otzplugin'], x: 40, y: 60),
    );

    expect(service.drag.value?.paths, ['C:/a.otzplugin']);
    expect(service.drag.value?.physicalPosition, const Offset(40, 60));
  });

  test('over מעדכן מיקום ושומר את הנתיבים שהתקבלו ב-enter', () async {
    await service.handleNativeCall(
      call('enter', paths: ['C:/a.otzplugin'], x: 10, y: 10),
    );
    await service.handleNativeCall(call('over', x: 80, y: 90));

    expect(service.drag.value?.paths, ['C:/a.otzplugin']);
    expect(service.drag.value?.physicalPosition, const Offset(80, 90));
  });

  test('leave מנקה את הגרירה', () async {
    await service.handleNativeCall(call('enter', paths: ['C:/a.otzplugin']));
    await service.handleNativeCall(
      MethodCall('onFileDrop', {'event': 'leave'}),
    );

    expect(service.drag.value, isNull);
  });

  test('drop משדר את הנתיבים ומנקה את הגרירה', () async {
    await service.handleNativeCall(call('enter', paths: ['C:/a.otzplugin']));

    final dropped = expectLater(
      service.drops,
      emits(
        isA<PluginFileDrag>()
            .having((d) => d.paths, 'paths', ['C:/a.otzplugin'])
            .having((d) => d.physicalPosition, 'position', const Offset(5, 7)),
      ),
    );
    await service.handleNativeCall(
      call('drop', paths: ['C:/a.otzplugin'], x: 5, y: 7),
    );

    expect(service.drag.value, isNull);
    await dropped;
  });

  test('גרירת קבצים וירטואליים ללא נתיבים אינה מפילה', () async {
    await service.handleNativeCall(call('enter'));

    expect(service.drag.value?.paths, isEmpty);
  });
}
