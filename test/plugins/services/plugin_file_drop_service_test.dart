import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_file_drop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PluginFileDropService service;

  setUp(() => service = PluginFileDropService());

  WindowsFileDropEvent event({
    List<String> paths = const [],
    double x = 0,
    double y = 0,
  }) => WindowsFileDropEvent(paths: paths, x: x, y: y);

  test('גרירה קובעת את הגרירה הפעילה עם הנתיבים והמיקום', () {
    service.handleDrag(event(paths: ['C:/a.otzplugin'], x: 40, y: 60));

    expect(service.drag.value?.paths, ['C:/a.otzplugin']);
    expect(service.drag.value?.physicalPosition, const Offset(40, 60));
  });

  test('over חסר-נתיבים שומר את הנתיבים שהתקבלו ב-enter', () {
    service.handleDrag(event(paths: ['C:/a.otzplugin'], x: 10, y: 10));
    service.handleDrag(event(x: 80, y: 90));

    expect(service.drag.value?.paths, ['C:/a.otzplugin']);
    expect(service.drag.value?.physicalPosition, const Offset(80, 90));
  });

  test('גרירה מוחזרת כמאושרת רק כשאזור כלשהו מוכן לקלוט', () {
    expect(service.handleDrag(event(paths: ['C:/a.otzplugin'])), isFalse);

    final zone = Object();
    service.setZoneAccepting(zone, true);
    expect(service.handleDrag(event(paths: ['C:/a.otzplugin'])), isTrue);

    service.setZoneAccepting(zone, false);
    expect(service.handleDrag(event(paths: ['C:/a.otzplugin'])), isFalse);
  });

  test('leave מנקה את הגרירה', () {
    service.handleDrag(event(paths: ['C:/a.otzplugin']));
    service.handleLeave();

    expect(service.drag.value, isNull);
  });

  test('drop משדר את הנתיבים ומנקה את הגרירה', () async {
    service.handleDrag(event(paths: ['C:/a.otzplugin']));

    final dropped = expectLater(
      service.drops,
      emits(
        isA<PluginFileDrag>()
            .having((d) => d.paths, 'paths', ['C:/a.otzplugin'])
            .having((d) => d.physicalPosition, 'position', const Offset(5, 7)),
      ),
    );
    await service.handleDrop(event(paths: ['C:/a.otzplugin'], x: 5, y: 7));

    expect(service.drag.value, isNull);
    await dropped;
  });

  test('גרירת קבצים וירטואליים ללא נתיבים אינה מפילה', () {
    service.handleDrag(event());

    expect(service.drag.value?.paths, isEmpty);
  });
}
