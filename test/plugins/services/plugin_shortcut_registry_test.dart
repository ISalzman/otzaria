import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_shortcut_registry.dart';

void main() {
  group('PluginShortcutRegistry', () {
    late PluginShortcutRegistry registry;

    setUp(() => registry = PluginShortcutRegistry.forTesting());

    test('registerPayload parses a command shortcut', () {
      final shortcut = registry.registerPayload('plugin-a', {
        'id': 'my-command',
        'label': 'הפעלת פקודה',
        'key': 'ctrl+alt+c',
        'command': 'runCommand',
      });

      expect(shortcut.id, 'my-command');
      expect(shortcut.label, 'הפעלת פקודה');
      expect(shortcut.key, 'ctrl+alt+c');
      expect(shortcut.command, 'runCommand');
      expect(shortcut.contextMenuItemId, isNull);
      expect(registry.getAll().single.$1, 'plugin-a');
    });

    test('registerPayload parses a context-menu-bound shortcut', () {
      final shortcut = registry.registerPayload('plugin-a', {
        'id': 'ctx-action',
        'label': 'פעולת תפריט',
        'contextMenuItemId': 'menu-item-1',
      });

      expect(shortcut.command, isNull);
      expect(shortcut.contextMenuItemId, 'menu-item-1');
    });

    test(
      'registering a shortcut without command and contextMenuItemId throws',
      () {
        expect(
          () => registry.registerPayload('plugin-a', {
            'id': 'empty',
            'label': 'ריק',
          }),
          throwsA(isA<PluginShortcutException>()),
        );
      },
    );

    test('registering the same id replaces the existing shortcut', () {
      registry.registerPayload('plugin-a', {
        'id': 's',
        'label': 'ראשון',
        'command': 'one',
      });
      registry.registerPayload('plugin-a', {
        'id': 's',
        'label': 'שני',
        'command': 'two',
      });

      expect(registry.getAll().single.$2.command, 'two');
    });

    test('update changes the key', () {
      registry.registerPayload('plugin-a', {
        'id': 's',
        'label': 'קיצור',
        'key': 'ctrl+alt+x',
        'command': 'x',
      });

      final updated = registry.update('plugin-a', 's', {'key': 'ctrl+alt+y'});
      expect(updated.key, 'ctrl+alt+y');
      expect(registry.find('plugin-a', 's')?.key, 'ctrl+alt+y');
    });

    test('update of a missing shortcut throws', () {
      expect(
        () => registry.update('plugin-a', 'missing', {'key': 'ctrl+alt+y'}),
        throwsA(isA<PluginShortcutException>()),
      );
    });

    test('remove deletes the shortcut and notifies', () {
      var notified = 0;
      registry.addListener(() => notified++);
      registry.registerPayload('plugin-a', {
        'id': 's',
        'label': 'קיצור',
        'command': 'x',
      });

      registry.remove('plugin-a', 's');
      expect(registry.find('plugin-a', 's'), isNull);
      expect(registry.getAll(), isEmpty);
      expect(notified, 2); // רישום + הסרה
    });

    test('removeAll removes every shortcut of a plugin', () {
      registry.registerPayload('plugin-a', {
        'id': 's1',
        'label': 'א',
        'command': 'a',
      });
      registry.registerPayload('plugin-a', {
        'id': 's2',
        'label': 'ב',
        'command': 'b',
      });
      registry.registerPayload('plugin-b', {
        'id': 's1',
        'label': 'ג',
        'command': 'c',
      });

      registry.removeAll('plugin-a');
      expect(registry.getAll().map((r) => r.$1), ['plugin-b']);
    });

    test('find returns null for unknown plugin or id', () {
      expect(registry.find('nope', 's'), isNull);
    });
  });
}
