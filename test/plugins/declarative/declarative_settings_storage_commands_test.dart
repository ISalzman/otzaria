import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_program_compiler.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/declarative/services/declarative_program_executor.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

void main() {
  group('קומפילציה', () {
    test('settings.get מתקמפל ודורש settings.read', () {
      final compiled = _compiler().compile(
        _settingsProgram(SettingsRepository.keyDarkMode),
      );

      expect(compiled.commands.single.type, 'settings.get');
      expect(compiled.requiredPermissions, {'settings.read'});
    });

    test('settings.get על מפתח שאינו קריא לתוספים נדחה בקומפילציה', () {
      expect(
        () => _compiler().compile(
          _settingsProgram(SettingsRepository.keyLibraryPath),
        ),
        _throwsProgramError('declarative.setting_not_allowed'),
      );
    });

    test('key חסר נדחה בשתי הפקודות', () {
      for (final type in const ['settings.get', 'storage.get']) {
        expect(
          () => _compiler().compile(_program(type, const {})),
          _throwsProgramError('declarative.invalid_args'),
        );
      }
    });

    test('key שאינו ליטרל מחרוזת תקין נדחה', () {
      expect(
        () => _compiler().compile(
          _program('storage.get', {
            'key': {r'$context': 'reader.book.id'},
          }),
        ),
        _throwsProgramError('declarative.invalid_args'),
      );
      expect(
        () => _compiler().compile(
          _program('storage.get', {'key': 'k' * 129}),
        ),
        _throwsProgramError('declarative.invalid_args'),
      );
    });

    test('storage.get מתקמפל ודורש plugin.storage.read', () {
      final compiled = _compiler().compile(
        _program('storage.get', const {'key': 'showButton'}),
      );

      expect(compiled.requiredPermissions, {'plugin.storage.read'});
      expect(compiled.commands.single.args['key'], 'showButton');
    });

    test('namespace אינו ארגומנט מוכר ונדחה בקומפילציה', () {
      expect(
        () => _compiler().compile(
          _program('storage.get', const {
            'key': 'showButton',
            'namespace': 'prefs',
          }),
        ),
        _throwsProgramError('declarative.unknown_field'),
      );
    });

    test('storage.set היא פעולה ואינה נכנסת לתכנית חישוב', () {
      for (final type in const ['storage.set', 'storage.remove']) {
        expect(
          () => const DeclarativeProgramCompiler(
            declaredPermissions: {'plugin.storage.write'},
            declaredSourceIds: {},
          ).compile(_program(type, const {'key': 'k', 'value': 1})),
          _throwsProgramError('declarative.invalid_phase'),
        );
      }
    });

    test('הרשאה שלא הוצהרה במניפסט חוסמת את הקומפילציה', () {
      const bare = DeclarativeProgramCompiler(
        declaredPermissions: {},
        declaredSourceIds: {},
      );

      expect(
        () => bare.compile(_settingsProgram(SettingsRepository.keyDarkMode)),
        _throwsProgramError('declarative.permission_not_declared'),
      );
      expect(
        () => bare.compile(_program('storage.get', const {'key': 'a'})),
        _throwsProgramError('declarative.permission_not_declared'),
      );
    });
  });

  group('ריצה', () {
    late _FakeRegistryRepository registry;

    setUp(() {
      registry = _FakeRegistryRepository({
        'default/showButton': jsonEncode('yes'),
        'prefs/counter': jsonEncode(3),
      });
    });

    test('settings.get מחזיר את ערך ההגדרה', () async {
      final result = await _executor(registry).execute(
        program: _compiler().compile(
          _settingsProgram(SettingsRepository.keyDarkMode),
        ),
        plugin: _plugin(),
        grantedPermissions: const {'settings.read'},
        context: const {},
      );

      expect(result.outputs['value'], isTrue);
    });

    test(
      'settings.get על מפתח חסום מחזיר null גם אם עקף את הקומפילציה',
      () async {
        final result = await _executor(registry).execute(
          program: _handCompiled(
            type: 'settings.get',
            args: {'key': SettingsRepository.keyLibraryPath},
            permission: 'settings.read',
          ),
          plugin: _plugin(),
          grantedPermissions: const {'settings.read'},
          context: const {},
        );

        expect(result.outputs['value'], isNull);
      },
    );

    test('storage.get מחזיר ערך מפוענח, ומפתח חסר מחזיר null', () async {
      final executor = _executor(registry);

      final existing = await executor.execute(
        program: _compiler().compile(
          _program('storage.get', const {'key': 'showButton'}),
        ),
        plugin: _plugin(),
        grantedPermissions: const {'plugin.storage.read'},
        context: const {},
      );
      final missing = await executor.execute(
        program: _compiler().compile(
          _program('storage.get', const {'key': 'noSuchKey'}),
        ),
        plugin: _plugin(),
        grantedPermissions: const {'plugin.storage.read'},
        context: const {},
      );

      expect(existing.outputs['value'], 'yes');
      expect(missing.outputs['value'], isNull);
      expect(registry.namespaces, ['default', 'default']);
    });

    test(
      'storage.get נעול ל-namespace default גם בתכנית מקומפלת ביד',
      () async {
        final result = await _executor(registry).execute(
          program: _handCompiled(
            type: 'storage.get',
            args: {'key': 'counter', 'namespace': 'prefs'},
            permission: 'plugin.storage.read',
          ),
          plugin: _plugin(),
          grantedPermissions: const {'plugin.storage.read'},
          context: const {},
        );

        expect(result.outputs['value'], isNull);
        expect(registry.namespaces, ['default']);
      },
    );

    test('ערך KV שאינו JSON תקין מוחזר כמות שהוא', () async {
      final result =
          await _executor(
            _FakeRegistryRepository({'default/raw': 'לא-JSON'}),
          ).execute(
            program: _compiler().compile(
              _program('storage.get', const {'key': 'raw'}),
            ),
            plugin: _plugin(),
            grantedPermissions: const {'plugin.storage.read'},
            context: const {},
          );

      expect(result.outputs['value'], 'לא-JSON');
    });

    test('הרשאה שנשללה לאחר הקומפילציה חוסמת את שתי הפקודות', () async {
      final programs = [
        _compiler().compile(_settingsProgram(SettingsRepository.keyDarkMode)),
        _compiler().compile(_program('storage.get', const {'key': 'a'})),
      ];

      for (final program in programs) {
        await expectLater(
          _executor(registry).execute(
            program: program,
            plugin: _plugin(),
            grantedPermissions: const {},
            context: const {},
          ),
          _throwsProgramError('declarative.permission_denied'),
        );
      }
      expect(registry.namespaces, isEmpty);
    });
  });
}

DeclarativeProgramExecutor _executor(_FakeRegistryRepository registry) =>
    DeclarativeProgramExecutor(
      registryRepository: registry,
      settingReader: (key) =>
          key == SettingsRepository.keyDarkMode ? true : 'לא אמור להיקרא',
    );

DeclarativeProgramCompiler _compiler() => const DeclarativeProgramCompiler(
  declaredPermissions: {'settings.read', 'plugin.storage.read'},
  declaredSourceIds: {},
);

Map<String, dynamic> _settingsProgram(String key) =>
    _program('settings.get', {'key': key});

Map<String, dynamic> _program(String type, Map<String, dynamic> args) => {
  'id': 'read-value',
  'version': 1,
  'triggers': ['reader.activeBookChanged'],
  'commands': [
    {'id': 'value', 'type': type, 'args': args},
  ],
  'outputs': {
    'value': {r'$result': 'value'},
  },
};

CompiledDeclarativeProgram _handCompiled({
  required String type,
  required Map<String, dynamic> args,
  required String permission,
}) => CompiledDeclarativeProgram(
  id: 'read-value',
  version: 1,
  triggers: const ['reader.activeBookChanged'],
  when: null,
  commands: [
    CompiledDeclarativeCommand(
      id: 'value',
      type: type,
      args: args,
      requiredPermission: permission,
    ),
  ],
  outputs: const {
    'value': {r'$result': 'value'},
  },
  requiredPermissions: {permission},
);

class _FakeRegistryRepository extends PluginRegistryRepository {
  _FakeRegistryRepository(this.values);

  final Map<String, String> values;
  final List<String> namespaces = [];

  @override
  Future<String?> getKV(String pluginId, String namespace, String key) async {
    namespaces.add(namespace);
    return values['$namespace/$key'];
  }
}

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
      minAppVersion: '0.9.97',
      sdkVersion: '1.x',
      permissions: const ['settings.read', 'plugin.storage.read'],
      networkEnabled: false,
      networkAllowlist: const [],
      toolTabTitle: 'Declarative',
      toolTabOrder: 900,
      defaultPinned: false,
      publishedDataTypes: const [],
      databaseSources: const [],
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
