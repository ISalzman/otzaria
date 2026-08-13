import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_external_editions_registry.dart';

InstalledPlugin _plugin({
  String pluginId = 'test.editions.plugin',
  List<Map<String, dynamic>> databaseSources = const [
    {'id': 'external_catalog', 'label': 'קטלוגים', 'required': true},
  ],
}) {
  final manifest = PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': pluginId,
    'name': 'Test Plugin',
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'minAppVersion': '0.9.97',
    'sdkVersion': '1.x',
    'permissions': const ['database.read', 'library.books.read'],
    'contributes': {'databaseSources': databaseSources},
  });
  return InstalledPlugin(
    pluginId: pluginId,
    name: 'Test Plugin',
    version: '1.0.0',
    installPath: '/plugins/test',
    entrypointPath: '/plugins/test/index.html',
    enabled: true,
    pinned: false,
    manifest: manifest,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Map<String, dynamic> _payload({
  String id = 'editions-1',
  String provider = 'hebrewbooks',
  String sourceId = 'external_catalog',
  String table = 'otzaria_hebrew_books',
  String externalIdColumn = 'hb_id',
  String otzariaIdColumn = 'otzaria_id',
  Object? orderBy = const [
    {'column': 'is_best', 'direction': 'desc'},
    {'column': 'confidence', 'direction': 'desc'},
  ],
}) => {
  'id': id,
  'provider': provider,
  'sourceId': sourceId,
  'table': table,
  'externalIdColumn': externalIdColumn,
  'otzariaIdColumn': otzariaIdColumn,
  'orderBy': ?orderBy,
};

void main() {
  group('parsePayload', () {
    const declared = {'external_catalog'};

    test('תרומה תקינה נפרסת על כל שדותיה', () {
      final parsed = PluginExternalEditionsRegistry.parsePayload(
        _payload(),
        declaredSourceIds: declared,
      );
      expect(parsed.id, 'editions-1');
      expect(parsed.provider, 'hebrewbooks');
      expect(parsed.sourceId, 'external_catalog');
      expect(parsed.table, 'otzaria_hebrew_books');
      expect(parsed.externalIdColumn, 'hb_id');
      expect(parsed.otzariaIdColumn, 'otzaria_id');
      expect(parsed.orderBy, hasLength(2));
      expect(parsed.orderBy.first.column, 'is_best');
      expect(parsed.orderBy.first.descending, isTrue);
    });

    test('orderBy אופציונלי — ברירת המחדל ריקה', () {
      final parsed = PluginExternalEditionsRegistry.parsePayload(
        _payload(orderBy: null),
        declaredSourceIds: declared,
      );
      expect(parsed.orderBy, isEmpty);
    });

    test('ספק באותיות גדולות נדחה', () {
      expect(
        () => PluginExternalEditionsRegistry.parsePayload(
          _payload(provider: 'HebrewBooks'),
          declaredSourceIds: declared,
        ),
        throwsA(isA<PluginExternalEditionsException>()),
      );
    });

    test('שם טבלה עם תווים מסוכנים נדחה', () {
      expect(
        () => PluginExternalEditionsRegistry.parsePayload(
          _payload(table: 'books; DROP TABLE x'),
          declaredSourceIds: declared,
        ),
        throwsA(isA<PluginExternalEditionsException>()),
      );
    });

    test('עמודות זהות לשני הצדדים נדחות', () {
      expect(
        () => PluginExternalEditionsRegistry.parsePayload(
          _payload(externalIdColumn: 'same', otzariaIdColumn: 'same'),
          declaredSourceIds: declared,
        ),
        throwsA(isA<PluginExternalEditionsException>()),
      );
    });

    test('מקור שלא הוכרז ב-databaseSources נדחה', () {
      expect(
        () => PluginExternalEditionsRegistry.parsePayload(
          _payload(sourceId: 'other_source'),
          declaredSourceIds: declared,
        ),
        throwsA(isA<PluginExternalEditionsException>()),
      );
    });

    test('כיוון מיון לא מוכר נדחה', () {
      expect(
        () => PluginExternalEditionsRegistry.parsePayload(
          _payload(
            orderBy: const [
              {'column': 'is_best', 'direction': 'sideways'},
            ],
          ),
          declaredSourceIds: declared,
        ),
        throwsA(isA<PluginExternalEditionsException>()),
      );
    });
  });

  group('registry', () {
    late PluginExternalEditionsRegistry registry;

    setUp(() {
      registry = PluginExternalEditionsRegistry.detached();
    });

    test('רישום, החלפה והסרה', () {
      final plugin = _plugin();
      registry.registerPayload(plugin, _payload());
      expect(registry.configs, hasLength(1));
      expect(registry.configs.single.plugin.pluginId, plugin.pluginId);

      // רישום חוזר של אותו מזהה מחליף, לא מוסיף.
      registry.registerPayload(plugin, _payload(provider: 'otherlib'));
      expect(registry.configs, hasLength(1));
      expect(registry.configs.single.provider, 'otherlib');

      registry.remove(plugin.pluginId, 'editions-1');
      expect(registry.configs, isEmpty);
    });

    test('מכסת התרומות לתוסף נאכפת', () {
      final plugin = _plugin();
      registry.registerPayload(plugin, _payload(id: 'a'));
      registry.registerPayload(plugin, _payload(id: 'b'));
      expect(
        () => registry.registerPayload(plugin, _payload(id: 'c')),
        throwsA(isA<PluginExternalEditionsException>()),
      );
      // תוסף אחר אינו מוגבל על-ידי הראשון.
      registry.registerPayload(_plugin(pluginId: 'other.plugin'), _payload());
      expect(registry.configs, hasLength(3));
    });

    test('removePlugin מסיר את כל תרומות התוסף בלבד', () {
      registry.registerPayload(_plugin(), _payload(id: 'a'));
      registry.registerPayload(_plugin(pluginId: 'other.plugin'), _payload());
      registry.removePlugin('test.editions.plugin');
      expect(registry.configs, hasLength(1));
      expect(registry.configs.single.plugin.pluginId, 'other.plugin');
    });
  });
}
