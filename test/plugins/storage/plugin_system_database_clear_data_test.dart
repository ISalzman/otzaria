import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// הטבלאות בלבד — DB in-memory בלי לעבור דרך ה-singleton וה-FS.
const _schema = '''
  CREATE TABLE plugin_installation (
    plugin_id TEXT PRIMARY KEY,
    name TEXT NOT NULL
  );
  CREATE TABLE plugin_permission_grant (
    plugin_id TEXT NOT NULL,
    permission TEXT NOT NULL,
    granted INTEGER NOT NULL,
    granted_at TEXT NOT NULL,
    PRIMARY KEY (plugin_id, permission)
  );
  CREATE TABLE plugin_kv_store (
    plugin_id TEXT NOT NULL,
    namespace TEXT NOT NULL,
    key TEXT NOT NULL,
    value_json TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (plugin_id, namespace, key)
  );
  CREATE TABLE plugin_published_record (
    plugin_id TEXT NOT NULL,
    type TEXT NOT NULL,
    scope TEXT NOT NULL,
    record_key TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    expires_at TEXT,
    PRIMARY KEY (plugin_id, type, scope, record_key)
  );
  CREATE TABLE plugin_runtime_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plugin_id TEXT NOT NULL,
    level TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TEXT NOT NULL
  );
''';

void _seedPlugin(Database db, String pluginId) {
  const ts = '2026-01-01T00:00:00.000Z';
  db.execute('INSERT INTO plugin_installation VALUES (?, ?)', [
    pluginId,
    'תוסף $pluginId',
  ]);
  db.execute('INSERT INTO plugin_permission_grant VALUES (?, ?, 1, ?)', [
    pluginId,
    'network.access',
    ts,
  ]);
  db.execute('INSERT INTO plugin_kv_store VALUES (?, ?, ?, ?, ?)', [
    pluginId,
    'default',
    'counter',
    '7',
    ts,
  ]);
  db.execute(
    'INSERT INTO plugin_published_record VALUES (?, ?, ?, ?, ?, 1, ?, ?, NULL)',
    [pluginId, 'calendar.event', 'global', 'ev-1', '{}', ts, ts],
  );
  db.execute(
    'INSERT INTO plugin_runtime_log (plugin_id, level, message, '
    'created_at) VALUES (?, ?, ?, ?)',
    [pluginId, 'info', 'hi', ts],
  );
}

int _count(Database db, String table, String pluginId) =>
    db.select('SELECT COUNT(*) AS c FROM $table WHERE plugin_id = ?', [
          pluginId,
        ]).first['c']
        as int;

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute(_schema);
    _seedPlugin(db, 'p1');
    _seedPlugin(db, 'p2');
  });

  tearDown(() => db.close());

  test('מוחק KV, רשומות שפורסמו ולוג של התוסף בלבד', () {
    PluginSystemDatabase.deletePluginDataRows(db, 'p1');

    expect(_count(db, 'plugin_kv_store', 'p1'), 0);
    expect(_count(db, 'plugin_published_record', 'p1'), 0);
    expect(_count(db, 'plugin_runtime_log', 'p1'), 0);

    expect(_count(db, 'plugin_kv_store', 'p2'), 1);
    expect(_count(db, 'plugin_published_record', 'p2'), 1);
    expect(_count(db, 'plugin_runtime_log', 'p2'), 1);
  });

  test('משאיר את ההתקנה וההרשאות של התוסף על כנן', () {
    PluginSystemDatabase.deletePluginDataRows(db, 'p1');

    expect(_count(db, 'plugin_installation', 'p1'), 1);
    expect(_count(db, 'plugin_permission_grant', 'p1'), 1);
  });
}
