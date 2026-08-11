import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_action_compiler.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/services/declarative_host_action_executor.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';

void main() {
  test('מקמפל ומבצע reader.openBook מורשה בהקשר הנכון', () async {
    final action = _compileAction();
    final opener = _BookOpener();

    final opened =
        await DeclarativeHostActionExecutor(
          bookOpener: opener,
        ).execute(
          action: action,
          plugin: _plugin(),
          grantedPermissions: const {'reader.open'},
          currentContextSignature: 'book-7',
          currentProgramGeneration: 7,
        );

    expect(opened, isTrue);
    expect(opener.identities.single, {'id': 10, 'type': 'pdf'});
    expect(() => action.args['index'] = 5, throwsUnsupportedError);
  });

  test('פעולה עם נתיב קובץ נדחית בזמן קומפילציה', () {
    expect(
      () => _compiler().compileResolved(
        {
          'type': 'reader.openBook',
          'args': {
            'identity': {'id': 10, 'filePath': '/tmp/book.pdf'},
          },
        },
        contextSignature: 'book-7',
        programGeneration: 7,
      ),
      _throwsProgramError('declarative.unknown_field'),
    );
  });

  test('הרשאה שלא הוצהרה דוחה את הפעולה בזמן קומפילציה', () {
    expect(
      () =>
          const DeclarativeActionCompiler(
            declaredPermissions: {},
          ).compileResolved(
            {
              'type': 'reader.openBook',
              'args': {
                'identity': {'id': 10},
              },
            },
            contextSignature: 'book-7',
            programGeneration: 7,
          ),
      _throwsProgramError('declarative.permission_not_declared'),
    );
  });

  test('חתימת הקשר ישנה חוסמת לפני פתיחת ספר', () async {
    final opener = _BookOpener();

    await expectLater(
      DeclarativeHostActionExecutor(bookOpener: opener).execute(
        action: _compileAction(),
        plugin: _plugin(),
        grantedPermissions: const {'reader.open'},
        currentContextSignature: 'book-8',
        currentProgramGeneration: 7,
      ),
      _throwsProgramError('declarative.stale_action'),
    );
    expect(opener.identities, isEmpty);
  });

  test('דור תוכנית ישן חוסם גם כאשר הקשר לא השתנה', () async {
    final opener = _BookOpener();

    await expectLater(
      DeclarativeHostActionExecutor(bookOpener: opener).execute(
        action: _compileAction(),
        plugin: _plugin(),
        grantedPermissions: const {'reader.open'},
        currentContextSignature: 'book-7',
        currentProgramGeneration: 8,
      ),
      _throwsProgramError('declarative.stale_action'),
    );
    expect(opener.identities, isEmpty);
  });

  test('שלילת הרשאה לאחר יצירת הכפתור חוסמת את הפעולה', () async {
    final opener = _BookOpener();

    await expectLater(
      DeclarativeHostActionExecutor(bookOpener: opener).execute(
        action: _compileAction(),
        plugin: _plugin(),
        grantedPermissions: const {},
        currentContextSignature: 'book-7',
        currentProgramGeneration: 7,
      ),
      _throwsProgramError('declarative.permission_denied'),
    );
    expect(opener.identities, isEmpty);
  });
}

class _BookOpener implements DeclarativeBookOpener {
  final identities = <Map<String, dynamic>>[];

  @override
  Future<bool> openUnique(
    Map<String, dynamic> identity, {
    required int index,
    required String searchQuery,
  }) async {
    identities.add(identity);
    return true;
  }
}

DeclarativeActionCompiler _compiler() => const DeclarativeActionCompiler(
  declaredPermissions: {'reader.open'},
);

CompiledDeclarativeAction _compileAction() => _compiler().compileResolved(
  {
    'type': 'reader.openBook',
    'args': {
      'identity': {'id': 10, 'type': 'pdf'},
      'index': 1,
    },
  },
  contextSignature: 'book-7',
  programGeneration: 7,
);

InstalledPlugin _plugin() {
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
      permissions: const ['reader.open'],
      networkEnabled: false,
      networkAllowlist: const [],
      toolTabTitle: 'Declarative',
      toolTabOrder: 900,
      defaultPinned: false,
      publishedDataTypes: const [],
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
