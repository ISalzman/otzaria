import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_extended_validator.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> _manifest({
  List<String> permissions = const [
    'app.startup_contributions',
    'reader.toolbar',
    'reader.context_menu',
    'published_data.write',
  ],
  String minAppVersion = '0.9.97',
  Map<String, dynamic>? startup,
}) => {
  'schemaVersion': 1,
  'id': 'test.startup.plugin',
  'name': 'Test Plugin',
  'version': '1.0.0',
  'entrypoint': 'index.html',
  'minAppVersion': minAppVersion,
  'sdkVersion': '1.x',
  'permissions': permissions,
  'contributes': {
    'toolTab': {'title': 'Test Plugin', 'order': 900, 'defaultPinned': true},
    'startup': ?startup,
  },
};

PluginValidationReport _run(Directory tempDir, Map<String, dynamic> json) {
  final dir = Directory(p.join(tempDir.path, 'plugin'))..createSync();
  File(p.join(dir.path, 'manifest.json')).writeAsStringSync(jsonEncode(json));
  File(p.join(dir.path, 'index.html')).writeAsStringSync(
    '<!doctype html><html lang="he" dir="rtl">'
    '<style>body { color: var(--color-text); }</style></html>',
  );
  return PluginExtendedValidator.validate(
    manifest: PluginManifest.fromJson(json),
    manifestJson: json,
    directoryPath: dir.path,
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('otzaria_startup_val_');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Map<String, dynamic> validStartup() => {
    'toolbarItems': [
      {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
    ],
    'contextMenuItems': [
      {
        'id': 'm1',
        'title': 'פריט',
        'showWhen': {
          'selectionContainsAny': ['מילה'],
        },
      },
    ],
    'publishedData': [
      {
        'type': 'calendar.event',
        'key': 'k1',
        'payload': {'title': 'אירוע'},
      },
    ],
    'activationEvents': ['app.startup'],
  };

  test('a valid startup section passes without errors', () {
    final report = _run(tempDir, _manifest(startup: validStartup()));
    expect(report.errors, isEmpty);
  });

  test('missing app.startup_contributions permission is a blocking error', () {
    final report = _run(
      tempDir,
      _manifest(
        permissions: const ['reader.toolbar'],
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
        },
      ),
    );
    expect(
      report.errors,
      contains(contains('app.startup_contributions')),
    );
  });

  test('minAppVersion below 0.9.97 is a blocking error', () {
    final report = _run(
      tempDir,
      _manifest(minAppVersion: '0.9.95', startup: validStartup()),
    );
    expect(report.errors, contains(contains('minAppVersion')));
  });

  test('an invalid toolbar item (missing icon) is a blocking error', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור'},
          ],
        },
      ),
    );
    expect(report.errors, contains(contains('toolbarItems')));
  });

  test('publishedData record without a key is a blocking error', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'publishedData': [
            {'type': 'calendar.event', 'payload': {}},
          ],
        },
      ),
    );
    expect(report.errors, contains(contains('publishedData')));
  });

  test('unknown activation event is a warning, not an error', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'activationEvents': ['no.such.event'],
        },
      ),
    );
    expect(report.errors, isEmpty);
    expect(report.warnings, contains(contains('no.such.event')));
  });

  test('app.startup without app.run_on_startup permission is a warning', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'activationEvents': ['app.startup'],
        },
      ),
    );
    expect(report.errors, isEmpty);
    expect(report.warnings, contains(contains('app.run_on_startup')));
  });

  test('activation event without its subscribe permission is a warning', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'activationEvents': ['reader.sectionContentChanged'],
        },
      ),
    );
    expect(report.errors, isEmpty);
    expect(
      report.warnings,
      contains(contains('events.subscribe:reader.sectionContentChanged')),
    );
  });

  test('missing domain permission for a category is a warning', () {
    final report = _run(
      tempDir,
      _manifest(
        permissions: const ['app.startup_contributions'],
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
        },
      ),
    );
    expect(report.errors, isEmpty);
    expect(report.warnings, contains(contains('reader.toolbar')));
  });

  test('wrong-typed startup fields yield clean errors, not a crash', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': 'not-a-list',
          'contextMenuItems': ['not-a-map'],
          'activationEvents': [17],
        },
      ),
    );
    expect(report.errors, contains(contains('toolbarItems')));
    expect(report.errors, contains(contains('contextMenuItems')));
    expect(report.errors, contains(contains('activationEvents')));
  });

  test('an empty startup section is only a warning', () {
    final report = _run(tempDir, _manifest(startup: <String, dynamic>{}));
    expect(report.errors, isEmpty);
    expect(report.warnings, contains(contains('contributes.startup ריק')));
  });
}
