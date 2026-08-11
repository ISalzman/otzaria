import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_startup_contributions.dart';

Map<String, dynamic> _manifestJson({Map<String, dynamic>? startup}) => {
  'schemaVersion': 1,
  'id': 'test.startup',
  'name': 'Test',
  'version': '1.0.0',
  'entrypoint': 'index.html',
  'permissions': const <String>[],
  'contributes': {'startup': ?startup},
};

void main() {
  test('manifest without contributes.startup yields null', () {
    final manifest = PluginManifest.fromJson(_manifestJson());
    expect(manifest.startup, isNull);
  });

  test('parses all startup contribution categories', () {
    final manifest = PluginManifest.fromJson(
      _manifestJson(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'contextMenuItems': [
            {
              'id': 'm1',
              'title': 'פריט',
              'showWhen': {
                'selectionContainsAny': ['רש"י'],
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
          'programs': [
            {
              'id': 'p1',
              'version': 1,
              'triggers': ['plugin.enabledChanged'],
              'commands': [],
              'outputs': {},
            },
          ],
          'activationEvents': ['app.startup', 'reader.sectionContentChanged'],
          'keepAlive': true,
        },
      ),
    );

    final startup = manifest.startup!;
    expect(startup.isEmpty, isFalse);
    expect(startup.toolbarItems.single['id'], 'b1');
    expect(startup.contextMenuItems.single['showWhen'], isA<Map>());
    expect(startup.publishedData.single['key'], 'k1');
    expect(startup.programs.single['id'], 'p1');
    expect(startup.activationEvents, [
      PluginStartupContributions.startupActivationTopic,
      'reader.sectionContentChanged',
    ]);
    expect(startup.keepAlive, isTrue);
  });

  test('toJson roundtrips through PluginManifest', () {
    final original = PluginManifest.fromJson(
      _manifestJson(
        startup: {
          'toolbarItems': [
            {'id': 'b1', 'title': 'כפתור', 'icon': 'apps_24_regular'},
          ],
          'activationEvents': ['app.startup'],
          'keepAlive': true,
        },
      ),
    );

    final reparsed = PluginManifest.fromJson(original.toJson());
    expect(reparsed.startup, isNotNull);
    expect(reparsed.startup!.toolbarItems.single['id'], 'b1');
    expect(reparsed.startup!.activationEvents, ['app.startup']);
    expect(reparsed.startup!.keepAlive, isTrue);
    expect(reparsed.startup!.contextMenuItems, isEmpty);
  });

  test('wrong-typed values are skipped without throwing', () {
    final manifest = PluginManifest.fromJson(
      _manifestJson(
        startup: {
          'toolbarItems': 'not-a-list',
          'contextMenuItems': ['not-a-map'],
          'activationEvents': ['ok', 17],
        },
      ),
    );

    final startup = manifest.startup!;
    expect(startup.toolbarItems, isEmpty);
    expect(startup.contextMenuItems, isEmpty);
    expect(startup.activationEvents, ['ok']);
  });

  test('a non-map contributes.startup parses as null', () {
    final json = _manifestJson();
    json['contributes'] = <String, dynamic>{'startup': 'oops'};
    expect(PluginManifest.fromJson(json).startup, isNull);
  });

  test('empty startup section parses as empty contributions', () {
    final manifest = PluginManifest.fromJson(
      _manifestJson(startup: <String, dynamic>{}),
    );
    expect(manifest.startup, isNotNull);
    expect(manifest.startup!.isEmpty, isTrue);
    expect(manifest.startup!.keepAlive, isFalse);
  });

  test('keepAlive alone does not make an empty startup section actionable', () {
    final manifest = PluginManifest.fromJson(
      _manifestJson(startup: {'keepAlive': true}),
    );

    expect(manifest.startup!.keepAlive, isTrue);
    expect(manifest.startup!.isEmpty, isTrue);
  });

  test('background trigger ignores static data and foreground-only items', () {
    const startup = PluginStartupContributions(
      toolbarItems: [
        {'id': 'open', 'type': 'button', 'openPlugin': true},
      ],
      contextMenuItems: [
        {'id': 'separator', 'type': 'separator'},
        {'id': 'open', 'type': 'item', 'openPlugin': true},
      ],
      publishedData: [
        {'type': 'calendar.event', 'key': 'static', 'payload': {}},
      ],
      programs: [
        {'id': 'host-only'},
      ],
    );

    expect(startup.hasBackgroundActivationTrigger, isFalse);
  });

  test('פקדי Host דקלרטיביים אינם מפעילים מנוע רקע', () {
    const startup = PluginStartupContributions(
      toolbarItems: [
        {
          'id': 'default',
          'binding': {'program': 'links', 'visibleOutput': 'default'},
          'action': {'type': 'reader.openBook', 'args': <String, Object?>{}},
        },
        {
          'id': 'editions',
          'type': 'menu',
          'binding': {'program': 'links', 'visibleOutput': 'editions'},
          'childrenBinding': {'itemsOutput': 'editions'},
        },
      ],
    );

    expect(startup.hasBackgroundActivationTrigger, isFalse);
  });

  test('background trigger finds actionable nested items and color rows', () {
    const toolbar = PluginStartupContributions(
      toolbarItems: [
        {
          'id': 'menu',
          'type': 'menu',
          'children': [
            {'id': 'open', 'openPlugin': true},
            {'id': 'background'},
          ],
        },
      ],
    );
    const contextMenu = PluginStartupContributions(
      contextMenuItems: [
        {'id': 'colors', 'type': 'color-row'},
      ],
    );

    expect(toolbar.hasBackgroundActivationTrigger, isTrue);
    expect(contextMenu.hasBackgroundActivationTrigger, isTrue);
  });
}
