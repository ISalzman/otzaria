import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_toolbar_item.dart';
import 'package:otzaria/plugins/services/plugin_toolbar_registry.dart';

void main() {
  group('PluginToolbarRegistry', () {
    late PluginToolbarRegistry registry;

    setUp(() => registry = PluginToolbarRegistry.forTesting());

    test('parses a button with defaults', () {
      registry.registerPayload('marker', {
        'id': 'mark',
        'title': 'Mark section',
        'icon': 'bookmark_24_regular',
        'param': {'mode': 'quick'},
      });

      final item = registry.getAll().single.$2;
      expect(item.type, 'button');
      expect(item.title, 'Mark section');
      expect(item.icon, 'bookmark_24_regular');
      expect(item.contexts, ['reader-text', 'reader-pdf']);
      expect(item.param, {'mode': 'quick'});
    });

    test('parses a menu with children inheriting contexts', () {
      registry.registerPayload('marker', {
        'id': 'menu',
        'type': 'menu',
        'title': 'Marker',
        'icon': 'highlight_24_regular',
        'contexts': ['reader-text'],
        'children': [
          {'id': 'add', 'title': 'Add'},
          {
            'id': 'clear',
            'title': 'Clear',
            'icon': 'eraser_24_regular',
            'onClickEvent': 'marker.clear',
          },
        ],
      });

      final item = registry.getAll().single.$2;
      expect(item.type, 'menu');
      expect(item.children, hasLength(2));
      expect(item.children.first.contexts, ['reader-text']);
      expect(item.children.last.onClickEvent, 'marker.clear');
    });

    test('requires an icon on a top-level item but not on children', () {
      expect(
        () => registry.registerPayload('marker', {
          'id': 'no-icon',
          'title': 'No icon',
        }),
        throwsA(
          isA<PluginToolbarException>().having(
            (error) => error.code,
            'code',
            'error.invalid_params',
          ),
        ),
      );

      registry.registerPayload('marker', {
        'id': 'menu',
        'type': 'menu',
        'title': 'Menu',
        'icon': 'apps_24_regular',
        'children': [
          {'id': 'child', 'title': 'Child'},
        ],
      });
      expect(registry.getAll().single.$2.children.single.icon, isNull);
    });

    test('rejects a menu without children and nested menus', () {
      expect(
        () => registry.registerPayload('marker', {
          'id': 'empty-menu',
          'type': 'menu',
          'title': 'Empty',
          'icon': 'apps_24_regular',
        }),
        throwsA(isA<PluginToolbarException>()),
      );
      expect(
        () => registry.registerPayload('marker', {
          'id': 'nested',
          'type': 'menu',
          'title': 'Nested',
          'icon': 'apps_24_regular',
          'children': [
            {
              'id': 'inner',
              'type': 'menu',
              'title': 'Inner',
              'children': [
                {'id': 'leaf', 'title': 'Leaf'},
              ],
            },
          ],
        }),
        throwsA(isA<PluginToolbarException>()),
      );
    });

    test('rejects duplicate child ids', () {
      expect(
        () => registry.registerPayload('marker', {
          'id': 'menu',
          'type': 'menu',
          'title': 'Menu',
          'icon': 'apps_24_regular',
          'children': [
            {'id': 'same', 'title': 'First'},
            {'id': 'same', 'title': 'Second'},
          ],
        }),
        throwsA(
          isA<PluginToolbarException>().having(
            (error) => error.code,
            'code',
            'error.invalid_params',
          ),
        ),
      );
    });

    test('rejects children on a plain button', () {
      expect(
        () => registry.registerPayload('marker', {
          'id': 'button',
          'title': 'Button',
          'icon': 'apps_24_regular',
          'children': [
            {'id': 'child', 'title': 'Child'},
          ],
        }),
        throwsA(isA<PluginToolbarException>()),
      );
    });

    test('rejects unsupported contexts and child context outside parent', () {
      expect(
        () => registry.registerPayload('marker', {
          'id': 'bad-context',
          'title': 'Bad',
          'icon': 'apps_24_regular',
          'contexts': ['reader-selection'],
        }),
        throwsA(
          isA<PluginToolbarException>().having(
            (error) => error.code,
            'code',
            'error.unsupported_context',
          ),
        ),
      );
      expect(
        () => registry.registerPayload('marker', {
          'id': 'menu',
          'type': 'menu',
          'title': 'Menu',
          'icon': 'apps_24_regular',
          'contexts': ['reader-text'],
          'children': [
            {
              'id': 'pdf-only',
              'title': 'PDF only',
              'contexts': ['reader-pdf'],
            },
          ],
        }),
        throwsA(
          isA<PluginToolbarException>().having(
            (error) => error.code,
            'code',
            'error.unsupported_context',
          ),
        ),
      );
    });

    test('allows at most two top-level items per plugin', () {
      const first = PluginToolbarItem(
        id: 'first',
        title: 'First',
        icon: 'apps_24_regular',
      );
      registry.register('marker', first);
      registry.register(
        'marker',
        const PluginToolbarItem(
          id: 'second',
          title: 'Second',
          icon: 'apps_24_regular',
        ),
      );

      expect(
        () => registry.register(
          'marker',
          const PluginToolbarItem(
            id: 'third',
            title: 'Third',
            icon: 'apps_24_regular',
          ),
        ),
        throwsA(isA<PluginToolbarException>()),
      );
      // רישום חוזר של id קיים מחליף ולא נחסם
      registry.register('marker', first);
      expect(registry.getAll(), hasLength(2));
    });

    test('updates an existing item without changing its id', () {
      registry.registerPayload('marker', {
        'id': 'mark',
        'title': 'Mark',
        'icon': 'bookmark_24_regular',
      });

      final updated = registry.update('marker', 'mark', {
        'title': 'Mark again',
      });

      expect(updated.id, 'mark');
      expect(updated.title, 'Mark again');
      expect(updated.icon, 'bookmark_24_regular');
      expect(registry.getAll(), hasLength(1));
    });

    test('update of a missing item throws not_found', () {
      expect(
        () => registry.update('marker', 'missing', {'title': 'X'}),
        throwsA(
          isA<PluginToolbarException>().having(
            (error) => error.code,
            'code',
            'error.not_found',
          ),
        ),
      );
    });

    test('keeps plugin ownership isolated', () {
      const item = PluginToolbarItem(
        id: 'same-id',
        title: 'Item',
        icon: 'apps_24_regular',
      );
      registry.register('first', item);
      registry.register('second', item);

      registry.removeAll('first');

      expect(registry.getAll().single.$1, 'second');
    });

    test('מחליף ומסתיר קבוצת פקדים בהתראה אטומית אחת', () {
      const managedIds = {'default', 'editions'};
      registry.replaceManagedItems(
        'marker',
        managedIds: managedIds,
        items: const [
          PluginToolbarItem(
            id: 'default',
            title: 'Old default',
            icon: 'apps_24_regular',
          ),
          PluginToolbarItem(
            id: 'editions',
            title: 'Old editions',
            icon: 'apps_24_regular',
          ),
        ],
      );
      final snapshots = <List<String>>[];
      registry.addListener(() {
        snapshots.add([
          for (final record in registry.getAll()) record.$2.title,
        ]);
      });

      registry.replaceManagedItems(
        'marker',
        managedIds: managedIds,
        items: const [
          PluginToolbarItem(
            id: 'default',
            title: 'New default',
            icon: 'apps_24_regular',
          ),
          PluginToolbarItem(
            id: 'editions',
            title: 'New editions',
            icon: 'apps_24_regular',
          ),
        ],
      );

      expect(snapshots, [
        ['New default', 'New editions'],
      ]);

      registry.replaceManagedItems(
        'marker',
        managedIds: managedIds,
        items: const [],
      );
      expect(snapshots.last, isEmpty);
      expect(snapshots, hasLength(2));
    });
  });
}
