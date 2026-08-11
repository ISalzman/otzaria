import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/services/declarative_host_action_executor.dart';
import 'package:otzaria/plugins/declarative/services/declarative_plugin_host_service.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_toolbar_registry.dart';

void main() {
  test('מסנכרן, מחשב ומפרסם שני פקדים ללא מנוע תוסף', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );

    final items = fixture.toolbar.getAll().map((entry) => entry.$2).toList();
    expect(items, hasLength(2));
    expect(items.first.hostAction, isNotNull);
    expect(items.last.children.single.hostAction, isNotNull);
  });

  test('לחיצה נבדקת שוב מול ההרשאות העדכניות', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );
    final action = fixture.toolbar.getAll().first.$2.hostAction!;

    fixture.permissions.remove('reader.open');
    await expectLater(
      fixture.host.executeAction(fixture.plugin.pluginId, action),
      _throwsProgramError('declarative.permission_denied'),
    );
    expect(fixture.access.opened, isEmpty);
  });

  test('סנכרון הרשאות פוסל פעולה ישנה גם כשהספר לא השתנה', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );
    final oldAction = fixture.toolbar.getAll().first.$2.hostAction!;

    fixture.permissions.remove('reader.toolbar');
    await fixture.host.syncPlugins([fixture.plugin]);

    expect(fixture.toolbar.getAll(), isEmpty);
    await expectLater(
      fixture.host.executeAction(fixture.plugin.pluginId, oldAction),
      _throwsProgramError('declarative.stale_action'),
    );
    expect(fixture.access.opened, isEmpty);
  });

  test('הסרה מבטלת את ההקשר ומוחקת את שני הפקדים מיד', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );
    expect(fixture.toolbar.getAll(), hasLength(2));

    final oldAction = fixture.toolbar.getAll().first.$2.hostAction!;
    fixture.host.removePlugin(fixture.plugin.pluginId);

    expect(fixture.toolbar.getAll(), isEmpty);
    expect(
      fixture.host.programRepository.getPluginOutputs(fixture.plugin.pluginId),
      isEmpty,
    );
    await expectLater(
      fixture.host.executeAction(fixture.plugin.pluginId, oldAction),
      _throwsProgramError('declarative.stale_action'),
    );
    expect(fixture.access.opened, isEmpty);
  });

  test('יציאה ממסך ספר מוחקת פלט ופקדים', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );

    await fixture.host.readerBookChanged(null, context: 'reader-text');

    expect(fixture.toolbar.getAll(), isEmpty);
  });

  test('סכימה פגומה נכשלת סגור ואינה מפילה סנכרון', () async {
    final fixture = _Fixture(invalidProgram: true);
    addTearDown(fixture.dispose);

    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );

    expect(fixture.toolbar.getAll(), isEmpty);
    expect(fixture.errors, hasLength(1));
  });

  test('grant ישן אינו עוקף הרשאה שהוסרה מהמניפסט', () async {
    final fixture = _Fixture(
      declaredPermissions: const ['reader.toolbar', 'reader.open'],
    );
    addTearDown(fixture.dispose);

    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );

    expect(fixture.toolbar.getAll(), isEmpty);
    expect(fixture.errors, hasLength(1));
  });

  test('פקד Host דורש reader.toolbar גם בהצהרת המניפסט', () async {
    final fixture = _Fixture(
      declaredPermissions: const [
        'app.startup_contributions',
        'reader.open',
      ],
    );
    addTearDown(fixture.dispose);

    await fixture.host.syncPlugins([fixture.plugin]);
    await fixture.host.readerBookChanged(
      TextBook(id: 1, title: 'ספר נוכחי'),
      context: 'reader-text',
    );

    expect(fixture.toolbar.getAll(), isEmpty);
    expect(fixture.errors, hasLength(1));
  });
}

class _Fixture {
  final toolbar = PluginToolbarRegistry.forTesting();
  final permissions = <String>{
    'app.startup_contributions',
    'reader.toolbar',
    'reader.open',
  };
  final errors = <Object>[];
  final _BookAccess access = _BookAccess();
  late final InstalledPlugin plugin;
  late final DeclarativePluginHostService host;

  _Fixture({
    bool invalidProgram = false,
    List<String>? declaredPermissions,
  }) {
    plugin = _plugin(
      invalidProgram: invalidProgram,
      declaredPermissions: declaredPermissions,
    );
    host = DeclarativePluginHostService(
      loadPlugin: (pluginId) async =>
          pluginId == plugin.pluginId ? plugin : null,
      loadPermissions: (_) async => Set.of(permissions),
      bookResolver: access,
      bookOpener: access,
      toolbarRegistry: toolbar,
      onError: (_, error, _) => errors.add(error),
    );
  }

  void dispose() => host.dispose();
}

class _BookAccess implements DeclarativeBookResolver, DeclarativeBookOpener {
  final opened = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>?>> resolveUniqueBatch(
    List<Map<String, dynamic>> identities,
  ) async => identities;

  @override
  Future<bool> openUnique(
    Map<String, dynamic> identity, {
    required int index,
    required String searchQuery,
  }) async {
    opened.add(identity);
    return true;
  }
}

InstalledPlugin _plugin({
  required bool invalidProgram,
  List<String>? declaredPermissions,
}) {
  final now = DateTime(2026);
  final program = <String, dynamic>{
    'id': 'book-links',
    'version': 1,
    'triggers': ['reader.activeBookChanged'],
    'commands': [
      {
        'id': 'first',
        'type': invalidProgram ? 'javascript.eval' : 'data.first',
        'args': {
          'items': {
            r'$literal': [
              {
                'title': 'מהדורה',
                'identity': {'id': 7},
              },
            ],
          },
        },
      },
    ],
    'outputs': {
      'defaultEdition': {r'$result': 'first'},
      'editions': {
        r'$literal': [
          {
            'title': 'מהדורה',
            'identity': {'id': 7},
          },
        ],
      },
    },
  };
  return InstalledPlugin(
    pluginId: 'test.host.plugin',
    name: 'Host',
    version: '1.0.0',
    installPath: '/',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: false,
    manifest: PluginManifest.fromJson({
      'schemaVersion': 1,
      'id': 'test.host.plugin',
      'name': 'Host',
      'version': '1.0.0',
      'entrypoint': 'index.html',
      'minAppVersion': '0.9.98',
      'permissions':
          declaredPermissions ??
          [
            'app.startup_contributions',
            'reader.toolbar',
            'reader.open',
          ],
      'contributes': {
        'startup': {
          'programs': [program],
          'toolbarItems': _toolbarItems(),
        },
      },
    }),
    installedAt: now,
    updatedAt: now,
  );
}

List<Map<String, dynamic>> _toolbarItems() => [
  {
    'id': 'default',
    'title': 'פתח ברירת מחדל',
    'icon': 'book_24_regular',
    'binding': {
      'program': 'book-links',
      'visibleOutput': 'defaultEdition',
    },
    'action': {
      'type': 'reader.openBook',
      'args': {
        'identity': {r'$output': 'defaultEdition.identity'},
      },
    },
  },
  {
    'id': 'editions',
    'type': 'menu',
    'title': 'פתח מהדורה',
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
            {r'$item': 'identity.id'},
          ],
        },
        'title': {r'$item': 'title'},
        'action': {
          'type': 'reader.openBook',
          'args': {
            'identity': {
              'id': {r'$item': 'identity.id'},
            },
          },
        },
      },
    },
  },
];

Matcher _throwsProgramError(String code) => throwsA(
  isA<DeclarativeProgramException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
