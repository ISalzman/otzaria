import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/plugins/database/plugin_database_registry.dart';
import 'package:otzaria/plugins/database/plugin_database_service.dart';
import 'package:otzaria/plugins/database/plugin_database_source.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late String sourceId;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'plugin-database-service-',
    );
    databasePath = path.join(tempDirectory.path, 'catalog.db');
    sourceId = 'test.source.${tempDirectory.path.hashCode}';
    _createDatabase(databasePath, 'ספר בדיקה');
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('מקור שאינו מסומן לקריאה בלבד נדחה', () {
    _registerSource(
      sourceId: sourceId,
      databasePath: databasePath,
      readOnly: false,
    );
    final service = PluginDatabaseService();

    expect(
      () => service.query(_pluginWithSource(sourceId), {
        'sourceId': sourceId,
        'from': {'table': 'books'},
        'select': [
          {'expr': 'books.id'},
        ],
      }),
      throwsA(
        isA<PluginDatabaseException>().having(
          (error) => error.code,
          'code',
          'database.source_not_read_only',
        ),
      ),
    );
  });

  test('שאילתה קוראת את הקובץ העדכני ואינה משאירה אותו נעול', () async {
    _registerSource(sourceId: sourceId, databasePath: databasePath);
    final service = PluginDatabaseService();
    final plugin = _pluginWithSource(sourceId);

    expect(
      _firstTitle(service.query(plugin, _titleQuery(sourceId))),
      'ספר בדיקה',
    );

    await File(databasePath).rename('$databasePath.old');
    _createDatabase(databasePath, 'ספר מעודכן');

    expect(
      _firstTitle(service.query(plugin, _titleQuery(sourceId))),
      'ספר מעודכן',
    );
  });

  test('alias כפול נדחה', () {
    _registerSource(sourceId: sourceId, databasePath: databasePath);

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'joins': [
          {
            'table': 'authors',
            'alias': 'books',
            'on': [
              {'left': 'books.id', 'op': '=', 'right': 'books.author_id'},
            ],
          },
        ],
      }),
      _throwsDatabaseError('database.invalid_spec'),
    );
  });

  test('join חייב לחבר את ה-alias החדש לטבלה קודמת', () {
    _registerSource(sourceId: sourceId, databasePath: databasePath);

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'joins': [
          {
            'table': 'authors',
            'alias': 'a',
            'on': [
              {'left': 'books.id', 'op': '=', 'right': 'books.author_id'},
            ],
          },
        ],
      }),
      _throwsDatabaseError('database.invalid_spec'),
    );
  });

  test('מספר ערכי IN מוגבל לפי policy', () {
    _registerSource(
      sourceId: sourceId,
      databasePath: databasePath,
      policy: _policy(maxInValues: 2),
    );

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'where': {
          'left': 'books.id',
          'op': 'in',
          'value': [1, 2, 3],
        },
      }),
      _throwsDatabaseError('database.query_too_large'),
    );
  });

  test('limit שאינו מספר שלם נדחה', () {
    _registerSource(sourceId: sourceId, databasePath: databasePath);

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'limit': 1.5,
      }),
      _throwsDatabaseError('database.invalid_spec'),
    );
  });

  test('שדה שאינו מוכר ב-query נדחה', () {
    _registerSource(sourceId: sourceId, databasePath: databasePath);

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'sql': 'SELECT * FROM books',
      }),
      _throwsDatabaseError('database.invalid_spec'),
    );
  });

  test('טיפוס שגוי בשדה טקסט מוחזר כשגיאת spec מבוקרת', () {
    _registerSource(sourceId: sourceId, databasePath: databasePath);

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'from': {'table': 42},
      }),
      _throwsDatabaseError('database.invalid_spec'),
    );
  });

  test('מערך WHERE רחב נדחה לפני מעבר על כל איבריו', () {
    final basePolicy = _policy();
    _registerSource(
      sourceId: sourceId,
      databasePath: databasePath,
      policy: PluginDatabasePolicy(
        tables: basePolicy.tables,
        columnsByTable: basePolicy.columnsByTable,
        allowedJoins: basePolicy.allowedJoins,
        maxWhereConditions: 2,
      ),
    );

    expect(
      () => PluginDatabaseService().query(_pluginWithSource(sourceId), {
        ..._titleQuery(sourceId),
        'where': {
          'op': 'and',
          'conditions': List<Object?>.filled(2, null),
        },
      }),
      _throwsDatabaseError('database.query_too_large'),
    );
  });
}

void _createDatabase(String databasePath, String title) {
  final database = sqlite3.sqlite3.open(databasePath);
  database
    ..execute(
      'CREATE TABLE authors (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
    )
    ..execute(
      'CREATE TABLE books ('
      'id INTEGER PRIMARY KEY, title TEXT NOT NULL, author_id INTEGER)',
    )
    ..execute("INSERT INTO authors (id, name) VALUES (1, 'מחבר')")
    ..execute(
      'INSERT INTO books (title, author_id) VALUES (?, ?)',
      [title, 1],
    )
    ..close();
}

void _registerSource({
  required String sourceId,
  required String databasePath,
  bool readOnly = true,
  PluginDatabasePolicy? policy,
}) {
  PluginDatabaseRegistry.instance.register(
    PluginDatabaseSource(
      sourceId: sourceId,
      label: 'מקור בדיקה',
      databasePath: databasePath,
      readOnly: readOnly,
      policy: policy ?? _policy(),
    ),
  );
}

PluginDatabasePolicy _policy({int maxInValues = 100}) {
  return PluginDatabasePolicy(
    tables: const {'books', 'authors'},
    columnsByTable: const {
      'books': {'id', 'title', 'author_id'},
      'authors': {'id', 'name'},
    },
    allowedJoins: const [
      PluginJoinRule(
        tableA: 'books',
        columnA: 'author_id',
        tableB: 'authors',
        columnB: 'id',
      ),
    ],
    maxInValues: maxInValues,
  );
}

Map<String, dynamic> _titleQuery(String sourceId) => {
  'sourceId': sourceId,
  'from': {'table': 'books'},
  'select': [
    {'expr': 'books.title', 'as': 'title'},
  ],
  'limit': 1,
  'rowFormat': 'object',
};

String _firstTitle(Map<String, dynamic> result) {
  final rows = result['rows'] as List<dynamic>;
  return (rows.first as Map<String, dynamic>)['title'] as String;
}

Matcher _throwsDatabaseError(String code) => throwsA(
  isA<PluginDatabaseException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);

InstalledPlugin _pluginWithSource(String sourceId) {
  final now = DateTime(2026);
  return InstalledPlugin(
    pluginId: 'test.plugin',
    name: 'Test Plugin',
    version: '1.0.0',
    installPath: '/',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: false,
    manifest: PluginManifest(
      schemaVersion: 1,
      id: 'test.plugin',
      name: 'Test Plugin',
      version: '1.0.0',
      description: '',
      author: '',
      homepage: '',
      entrypoint: 'index.html',
      minAppVersion: '0.9.97',
      sdkVersion: '1.x',
      permissions: const ['database.read'],
      networkEnabled: false,
      networkAllowlist: const [],
      toolTabTitle: 'Test Plugin',
      toolTabOrder: 900,
      defaultPinned: false,
      publishedDataTypes: const [],
      databaseSources: [
        {'id': sourceId},
      ],
    ),
    installedAt: now,
    updatedAt: now,
  );
}
