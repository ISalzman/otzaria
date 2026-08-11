import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3;
import 'package:otzaria/plugins/database/plugin_database_registry.dart';
import 'package:otzaria/plugins/database/plugin_database_source.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_program_compiler.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDirectory;
  late String databasePath;
  late String sourceId;
  late InstalledPlugin plugin;
  late _TestBookResolver resolver;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'declarative-executor-',
    );
    databasePath = path.join(tempDirectory.path, 'catalog.db');
    sourceId = 'test.declarative.${tempDirectory.path.hashCode}';
    _createDatabase(databasePath);
    PluginDatabaseRegistry.instance.register(
      PluginDatabaseSource(
        sourceId: sourceId,
        label: 'קטלוג בדיקה',
        databasePath: databasePath,
        policy: const PluginDatabasePolicy(
          tables: {'mapping'},
          columnsByTable: {
            'mapping': {'internal_id', 'external_id', 'title'},
          },
          allowedJoins: [],
          maxLimit: 20,
          maxOffset: 0,
        ),
      ),
    );
    plugin = _plugin(sourceId: sourceId);
    resolver = _TestBookResolver();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('מריץ שאילתה, רזולוציה ומיפוי בלי JavaScript', () async {
    final program = _compile(sourceId, _program(sourceId));
    final result =
        await DeclarativeProgramExecutor(
          bookResolver: resolver,
        ).execute(
          program: program,
          plugin: plugin,
          grantedPermissions: const {'database.read', 'library.books.read'},
          context: _readerContext(bookId: 7, type: 'text'),
        );

    final editions = result.outputs['editions'] as List<dynamic>;
    expect(editions, hasLength(1));
    expect((editions.single as Map)['id'], 'edition-10');
    expect((editions.single as Map)['title'], 'מהדורה א');
    expect(
      result.outputs['defaultEdition'],
      containsPair('identity', containsPair('id', 10)),
    );
    expect(resolver.identities, hasLength(2));
    expect(resolver.batchCalls, 1);
    expect(() => editions.add('unsafe'), throwsUnsupportedError);
  });

  test('הרשאה שנשללה לאחר הקומפילציה חוסמת את הריצה', () async {
    final program = _compile(sourceId, _program(sourceId));

    await expectLater(
      DeclarativeProgramExecutor(bookResolver: resolver).execute(
        program: program,
        plugin: plugin,
        grantedPermissions: const {'database.read'},
        context: _readerContext(bookId: 7, type: 'text'),
      ),
      _throwsProgramError('declarative.permission_denied'),
    );
    expect(resolver.identities, isEmpty);
  });

  test('תוסף כבוי אינו מריץ תכנית', () async {
    final program = _compile(sourceId, _program(sourceId));

    await expectLater(
      DeclarativeProgramExecutor(bookResolver: resolver).execute(
        program: program,
        plugin: plugin.copyWith(enabled: false),
        grantedPermissions: const {'database.read', 'library.books.read'},
        context: _readerContext(bookId: 7, type: 'text'),
      ),
      _throwsProgramError('declarative.plugin_disabled'),
    );
  });

  test('when שאינו מתקיים מחזיר פלט ריק לפני גישה ל-DB', () async {
    final program = _compile(sourceId, _program(sourceId));
    await File(databasePath).delete();

    final result =
        await DeclarativeProgramExecutor(
          bookResolver: resolver,
        ).execute(
          program: program,
          plugin: plugin,
          grantedPermissions: const {'database.read', 'library.books.read'},
          context: _readerContext(bookId: 7, type: 'pdf'),
        );

    expect(result.outputs, isEmpty);
    expect(resolver.identities, isEmpty);
  });
}

class _TestBookResolver implements DeclarativeBookResolver {
  final identities = <Map<String, dynamic>>[];
  int batchCalls = 0;

  @override
  Future<List<Map<String, dynamic>?>> resolveUniqueBatch(
    List<Map<String, dynamic>> requestedIdentities,
  ) async {
    batchCalls++;
    identities.addAll(requestedIdentities);
    return [
      for (final identity in requestedIdentities)
        if ((identity['external'] as Map<String, dynamic>)['id'] == 11)
          null
        else
          {
            'id': (identity['external'] as Map<String, dynamic>)['id'],
            'type': 'pdf',
            'source': 'library',
          },
    ];
  }
}

void _createDatabase(String databasePath) {
  final database = sqlite3.sqlite3.open(databasePath);
  database
    ..execute(
      'CREATE TABLE mapping ('
      'internal_id INTEGER, external_id INTEGER, title TEXT)',
    )
    ..execute(
      "INSERT INTO mapping VALUES (7, 10, 'מהדורה א'), (7, 11, 'עמומה')",
    )
    ..close();
}

CompiledDeclarativeProgram _compile(
  String sourceId,
  Map<String, dynamic> program,
) {
  return DeclarativeProgramCompiler(
    declaredPermissions: const {'database.read', 'library.books.read'},
    declaredSourceIds: {sourceId},
  ).compile(program);
}

Map<String, dynamic> _program(String sourceId) => {
  'id': 'parallel-editions',
  'version': 1,
  'triggers': ['reader.activeBookChanged'],
  'when': {
    'op': 'equals',
    'left': {r'$context': 'reader.book.type'},
    'right': {r'$literal': 'text'},
  },
  'commands': [
    {
      'id': 'editions',
      'type': 'database.select',
      'args': {
        'sourceId': sourceId,
        'from': {'table': 'mapping', 'alias': 'm'},
        'select': [
          {'expr': 'm.external_id', 'as': 'id'},
          {'expr': 'm.title', 'as': 'title'},
        ],
        'where': {
          'op': '=',
          'left': 'm.internal_id',
          'value': {r'$context': 'reader.book.id'},
        },
        'orderBy': [
          {'expr': 'm.external_id', 'direction': 'asc'},
        ],
        'limit': 20,
        'rowFormat': 'object',
      },
    },
    {
      'id': 'resolved',
      'type': 'library.resolveBooks',
      'args': {
        'items': {r'$result': 'editions.rows'},
        'identity': <String, dynamic>{
          'external': {
            'provider': {r'$literal': 'hebrewbooks'},
            'id': {r'$row': 'id'},
          },
        },
        'keepInputFields': true,
        'limit': 20,
      },
    },
    {
      'id': 'menuItems',
      'type': 'data.map',
      'args': {
        'items': {r'$result': 'resolved'},
        'template': {
          'id': {
            r'$concat': [
              {r'$literal': 'edition-'},
              {r'$row': 'identity.id'},
            ],
          },
          'title': {r'$row': 'title'},
          'identity': {r'$row': 'identity'},
        },
      },
    },
    {
      'id': 'defaultEdition',
      'type': 'data.first',
      'args': {
        'items': {r'$result': 'resolved'},
      },
    },
  ],
  'outputs': {
    'editions': {r'$result': 'menuItems'},
    'defaultEdition': {r'$result': 'defaultEdition'},
  },
};

Map<String, dynamic> _readerContext({
  required int bookId,
  required String type,
}) => {
  'reader': {
    'context': 'reader-$type',
    'book': {'id': bookId, 'type': type, 'source': 'library'},
  },
};

InstalledPlugin _plugin({required String sourceId}) {
  final now = DateTime(2026);
  return InstalledPlugin(
    pluginId: 'test.declarative.plugin',
    name: 'Declarative',
    version: '1.0.0',
    installPath: '/',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: false,
    manifest: PluginManifest(
      schemaVersion: 1,
      id: 'test.declarative.plugin',
      name: 'Declarative',
      version: '1.0.0',
      description: '',
      author: '',
      homepage: '',
      entrypoint: 'index.html',
      minAppVersion: '0.9.98',
      sdkVersion: '1.x',
      permissions: const [
        'app.startup_contributions',
        'database.read',
        'library.books.read',
      ],
      networkEnabled: false,
      networkAllowlist: const [],
      toolTabTitle: 'Declarative',
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

Matcher _throwsProgramError(String code) => throwsA(
  isA<DeclarativeProgramException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
