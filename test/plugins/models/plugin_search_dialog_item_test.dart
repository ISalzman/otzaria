import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_search_dialog_item.dart';
import 'package:otzaria/plugins/services/plugin_search_dialog_registry.dart';
import 'package:otzaria/search/models/search_configuration.dart';

void main() {
  Map<String, dynamic> item({Object? disabledSearchOptions}) {
    final payload = <String, dynamic>{
      'id': 'include-external',
      'type': 'checkbox',
      'title': 'חפש גם במקור חיצוני',
      'defaultValue': true,
      'visibleInModes': ['exact', 'advanced'],
    };
    if (disabledSearchOptions != null) {
      payload['disabledSearchOptions'] = disabledSearchOptions;
    }
    return payload;
  }

  test('parses a static checkbox with mode-specific disabled options', () {
    final parsed = PluginSearchDialogItem.fromPayload(
      item(
        disabledSearchOptions: {
          'advanced': ['word.partial', 'word.typo-tolerance'],
        },
      ),
    );

    expect(parsed.defaultValue, isTrue);
    expect(parsed.isVisibleIn(SearchMode.exact), isTrue);
    expect(parsed.isVisibleIn(SearchMode.advanced), isTrue);
    expect(parsed.isVisibleIn(SearchMode.fuzzy), isFalse);
    expect(parsed.disabledOptionsFor(SearchMode.advanced), {
      'word.partial',
      'word.typo-tolerance',
    });
  });

  test('rejects an unknown native search option id', () {
    expect(
      () => PluginSearchDialogItem.fromPayload(
        item(
          disabledSearchOptions: {
            'advanced': ['word.not-a-real-option'],
          },
        ),
      ),
      throwsA(isA<PluginSearchDialogItemException>()),
    );
  });

  test(
    'registry replaces an item with the same id instead of duplicating it',
    () {
      final registry = PluginSearchDialogRegistry.forTesting();
      addTearDown(registry.dispose);

      registry.registerPayload('test.plugin', item());
      registry.registerPayload('test.plugin', {
        ...item(),
        'title': 'חפש גם במקור אחר',
      });

      final records = registry.getAll();
      expect(records, hasLength(1));
      expect(records.single.$2.title, 'חפש גם במקור אחר');
    },
  );
}
