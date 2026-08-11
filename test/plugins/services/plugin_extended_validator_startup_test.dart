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
    'search.dialog',
  ],
  String minAppVersion = '0.9.96',
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
    'searchDialogItems': [
      {
        'id': 'include-external',
        'type': 'checkbox',
        'title': 'חפש גם במקור חיצוני',
        'visibleInModes': ['exact', 'advanced'],
      },
    ],
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

  test('minAppVersion below 0.9.96 is a blocking error', () {
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

  test('unknown static search option id is a blocking error', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'searchDialogItems': [
            {
              'id': 'include-external',
              'type': 'checkbox',
              'title': 'חפש גם במקור חיצוני',
              'disabledSearchOptions': {
                'advanced': ['word.not-a-real-option'],
              },
            },
          ],
        },
      ),
    );

    expect(report.errors, contains(contains('searchDialogItems')));
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
          'programs': ['not-a-map'],
          'activationEvents': [17],
        },
      ),
    );
    expect(report.errors, contains(contains('toolbarItems')));
    expect(report.errors, contains(contains('contextMenuItems')));
    expect(report.errors, contains(contains('programs')));
    expect(report.errors, contains(contains('activationEvents')));
  });

  test('an empty startup section is only a warning', () {
    final report = _run(tempDir, _manifest(startup: <String, dynamic>{}));
    expect(report.errors, isEmpty);
    expect(report.warnings, contains(contains('contributes.startup ריק')));
  });

  test('keepAlive requires both background permissions', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'keepAlive': true,
        },
      ),
    );

    expect(report.errors, contains(contains('app.run_on_startup')));
    expect(report.errors, contains(contains('app.background_keep_alive')));
  });

  test('keepAlive with both permissions is valid', () {
    final report = _run(
      tempDir,
      _manifest(
        permissions: const [
          'app.startup_contributions',
          'app.run_on_startup',
          'app.background_keep_alive',
          'reader.toolbar',
        ],
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'keepAlive': true,
        },
      ),
    );

    expect(report.errors, isEmpty);
  });

  test('keepAlive with a non-boolean value is rejected cleanly', () {
    final report = _run(
      tempDir,
      _manifest(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'keepAlive': 'yes',
        },
      ),
    );

    expect(report.errors, contains(contains('keepAlive חייב להיות bool')));
  });

  test('keepAlive permission without the flag produces a warning', () {
    final report = _run(
      tempDir,
      _manifest(
        permissions: const [
          'app.startup_contributions',
          'app.background_keep_alive',
          'reader.toolbar',
        ],
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
        },
      ),
    );

    expect(report.errors, isEmpty);
    expect(
      report.warnings,
      contains(contains('ללא contributes.startup.keepAlive')),
    );
  });

  test('keepAlive without any contribution or trigger is rejected', () {
    final report = _run(
      tempDir,
      _manifest(
        permissions: const [
          'app.startup_contributions',
          'app.run_on_startup',
          'app.background_keep_alive',
        ],
        startup: {'keepAlive': true},
      ),
    );

    expect(report.errors, contains(contains('מפעיל מנוע רקע')));
  });

  test('keepAlive with static data only is rejected', () {
    final report = _run(
      tempDir,
      _manifest(
        permissions: const [
          'app.startup_contributions',
          'app.run_on_startup',
          'app.background_keep_alive',
          'published_data.write',
        ],
        startup: {
          'publishedData': [
            {
              'type': 'calendar.event',
              'key': 'static',
              'payload': {'title': 'אירוע'},
            },
          ],
          'keepAlive': true,
        },
      ),
    );

    expect(report.errors, contains(contains('מפעיל מנוע רקע')));
  });

  test('תכנית Host תקינה עוברת ולידציה בלי להפעיל מנוע רקע', () {
    final report = _run(
      tempDir,
      _manifest(
        minAppVersion: '0.9.96',
        permissions: const ['app.startup_contributions'],
        startup: {
          'programs': [_validHostProgram()],
        },
      ),
    );

    expect(report.errors, isEmpty);
  });

  test('פקודה דקלרטיבית לא מוכרת היא שגיאה חוסמת', () {
    final program = _validHostProgram();
    (program['commands'] as List<dynamic>)[0] = {
      'id': 'unsafe',
      'type': 'database.rawSql',
      'args': {'sql': 'DELETE FROM books'},
    };
    final report = _run(
      tempDir,
      _manifest(
        minAppVersion: '0.9.96',
        permissions: const ['app.startup_contributions'],
        startup: {
          'programs': [program],
        },
      ),
    );

    expect(report.errors, contains(contains('unknown_command')));
  });

  test('תכנית דקלרטיבית דורשת minAppVersion 0.9.96', () {
    final report = _run(
      tempDir,
      _manifest(
        minAppVersion: '0.9.95',
        permissions: const ['app.startup_contributions'],
        startup: {
          'programs': [_validHostProgram()],
        },
      ),
    );

    expect(report.errors, contains(contains('0.9.96')));
  });

  test('שני פקדי Host דקלרטיביים עוברים ולידציה', () {
    final report = _run(
      tempDir,
      _manifest(
        minAppVersion: '0.9.96',
        permissions: const [
          'app.startup_contributions',
          'reader.toolbar',
          'reader.open',
        ],
        startup: {
          'programs': [_toolbarProgram()],
          'toolbarItems': _declarativeToolbarItems(),
        },
      ),
    );

    expect(report.errors, isEmpty);
  });

  test('פקד Host דקלרטיבי ללא reader.toolbar נדחה בהתקנה', () {
    final report = _run(
      tempDir,
      _manifest(
        minAppVersion: '0.9.96',
        permissions: const ['app.startup_contributions', 'reader.open'],
        startup: {
          'programs': [_toolbarProgram()],
          'toolbarItems': _declarativeToolbarItems(),
        },
      ),
    );

    expect(report.errors, contains(contains('reader.toolbar')));
  });

  test('פקד דקלרטיבי שמפנה לפלט חסר נדחה', () {
    final items = _declarativeToolbarItems();
    (items.first['binding'] as Map<String, dynamic>)['visibleOutput'] =
        'missing';
    final report = _run(
      tempDir,
      _manifest(
        minAppVersion: '0.9.96',
        permissions: const [
          'app.startup_contributions',
          'reader.toolbar',
          'reader.open',
        ],
        startup: {
          'programs': [_toolbarProgram()],
          'toolbarItems': items,
        },
      ),
    );

    expect(report.errors, contains(contains('output_not_found')));
  });
}

Map<String, dynamic> _validHostProgram() => {
  'id': 'host-program',
  'version': 1,
  'triggers': ['reader.activeBookChanged'],
  'commands': [
    {
      'id': 'first',
      'type': 'data.first',
      'args': {
        'items': {
          r'$literal': [1],
        },
      },
    },
  ],
  'outputs': {
    'first': {r'$result': 'first'},
  },
};

Map<String, dynamic> _toolbarProgram() => {
  'id': 'book-links',
  'version': 1,
  'triggers': ['reader.activeBookChanged'],
  'commands': [
    {
      'id': 'first',
      'type': 'data.first',
      'args': {
        'items': {
          r'$literal': [
            {'id': 1, 'title': 'מהדורה'},
          ],
        },
      },
    },
  ],
  'outputs': {
    'defaultEdition': {r'$result': 'first'},
    'editions': {
      r'$literal': [
        {'id': 1, 'title': 'מהדורה'},
      ],
    },
  },
};

List<Map<String, dynamic>> _declarativeToolbarItems() => [
  {
    'id': 'default',
    'title': 'פתח מהדורת ברירת מחדל',
    'icon': 'book_24_regular',
    'binding': {
      'program': 'book-links',
      'visibleOutput': 'defaultEdition',
    },
    'action': {
      'type': 'reader.openBook',
      'args': {
        'identity': {r'$output': 'defaultEdition'},
      },
    },
  },
  {
    'id': 'editions',
    'type': 'menu',
    'title': 'פתח מהדורה אחרת',
    'icon': 'book_24_regular',
    'binding': {
      'program': 'book-links',
      'visibleOutput': 'editions',
    },
    'childrenBinding': {
      'itemsOutput': 'editions',
      'itemTemplate': {
        'id': {
          r'$concat': [
            'edition-',
            {r'$item': 'id'},
          ],
        },
        'title': {r'$item': 'title'},
        'action': {
          'type': 'reader.openBook',
          'args': {
            'identity': {
              'id': {r'$item': 'id'},
            },
          },
        },
      },
    },
  },
];
