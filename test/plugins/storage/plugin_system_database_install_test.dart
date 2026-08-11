import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';
import 'package:sqlite3/sqlite3.dart';

const _pluginTable = '''
  CREATE TABLE plugin_installation (
    plugin_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    install_path TEXT NOT NULL,
    entrypoint_path TEXT NOT NULL,
    icon_path TEXT,
    enabled INTEGER NOT NULL,
    pinned INTEGER NOT NULL DEFAULT 1,
    pinned_to_nav_rail INTEGER NOT NULL DEFAULT 0,
    hidden_from_tools INTEGER NOT NULL DEFAULT 0,
    allow_order_before_built_ins_granted INTEGER,
    manifest_json TEXT NOT NULL,
    installed_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    source_type TEXT NOT NULL DEFAULT 'packaged',
    dev_root_path TEXT,
    user_order INTEGER
  )
''';

const _permissionTable = '''
  CREATE TABLE plugin_permission_grant (
    plugin_id TEXT NOT NULL,
    permission TEXT NOT NULL,
    granted INTEGER NOT NULL,
    granted_at TEXT NOT NULL,
    PRIMARY KEY (plugin_id, permission)
  )
''';

void main() {
  group('PluginSystemDatabase.applyPluginInstall', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      db.execute(_pluginTable);
      db.execute(_permissionTable);
    });

    tearDown(() => db.close());

    test('שומר תוסף והרשאות true/false באותה פעולה', () {
      final plugin = _plugin(
        version: '1.0.0',
        permissions: const ['app.startup_contributions', 'reader.open'],
      );

      PluginSystemDatabase.applyPluginInstall(db, plugin, const {
        'app.startup_contributions': false,
        'reader.open': true,
      });

      expect(_version(db), '1.0.0');
      expect(_grants(db), {
        'app.startup_contributions': false,
        'reader.open': true,
      });
    });

    test('כשל בכתיבת הרשאה מחזיר גם את התוסף וגם את ההרשאות', () {
      PluginSystemDatabase.applyPluginInstall(
        db,
        _plugin(version: '1.0.0', permissions: const ['app.info.read']),
        const {'app.info.read': true},
      );
      db.execute('''
        CREATE TRIGGER reject_reader_open
        BEFORE INSERT ON plugin_permission_grant
        WHEN NEW.permission = 'reader.open'
        BEGIN
          SELECT RAISE(ABORT, 'forced-fail');
        END
      ''');

      expect(
        () => PluginSystemDatabase.applyPluginInstall(
          db,
          _plugin(
            version: '2.0.0',
            permissions: const ['app.startup_contributions', 'reader.open'],
          ),
          const {
            'app.startup_contributions': false,
            'reader.open': true,
          },
        ),
        throwsA(anything),
      );

      expect(_version(db), '1.0.0');
      expect(_grants(db), {'app.info.read': true});
    });
  });
}

InstalledPlugin _plugin({
  required String version,
  required List<String> permissions,
}) {
  final manifest = PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': 'test.atomic.install',
    'name': 'Atomic Install',
    'version': version,
    'entrypoint': 'index.html',
    'permissions': permissions,
  });
  return InstalledPlugin(
    pluginId: manifest.id,
    name: manifest.name,
    version: manifest.version,
    installPath: '/plugins/${manifest.id}',
    entrypointPath: manifest.entrypoint,
    enabled: true,
    pinned: false,
    manifest: manifest,
    installedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

String _version(Database db) =>
    db.select('SELECT version FROM plugin_installation').first['version']
        as String;

Map<String, bool> _grants(Database db) => {
  for (final row in db.select(
    'SELECT permission, granted FROM plugin_permission_grant',
  ))
    row['permission'] as String: row['granted'] == 1,
};
