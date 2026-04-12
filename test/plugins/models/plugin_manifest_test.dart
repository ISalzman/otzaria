import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';

void main() {
  group('PluginManifest', () {
    test('parses icon metadata and resolves filled font family', () {
      final manifest = PluginManifest.fromJson({
        'schemaVersion': 1,
        'id': 'test.plugin.icon',
        'name': 'Icon Plugin',
        'version': '1.0.0',
        'entrypoint': 'index.html',
        'contributes': {
          'toolTab': {
            'title': 'Icon Plugin',
            'iconCodepoint': 983704,
            'iconVariant': 'filled',
          },
        },
      });

      expect(manifest.toolTabIconCodepoint, 983704);
      expect(manifest.toolTabIconVariant, 'filled');
      expect(manifest.toolTabIconFontFamily, 'FluentSystemIcons-Filled');

      final toolTab = (manifest.toJson()['contributes']
          as Map<String, dynamic>)['toolTab'] as Map<String, dynamic>;
      expect(toolTab['iconCodepoint'], 983704);
      expect(toolTab['iconVariant'], 'filled');
    });

    test('defaults to regular font family when variant is omitted', () {
      final manifest = PluginManifest.fromJson({
        'schemaVersion': 1,
        'id': 'test.plugin.default.icon',
        'name': 'Default Icon Plugin',
        'version': '1.0.0',
        'entrypoint': 'index.html',
        'contributes': {
          'toolTab': {
            'title': 'Default Icon Plugin',
            'iconCodepoint': 983685,
          },
        },
      });

      expect(manifest.toolTabIconVariant, isNull);
      expect(manifest.toolTabIconFontFamily, 'FluentSystemIcons-Regular');
    });
  });
}
