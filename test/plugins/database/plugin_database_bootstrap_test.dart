import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/database/plugin_database_bootstrap.dart';

void main() {
  test('מקור הקטלוג החיצוני חושף רק את טבלאות ההשוואה הנחוצות', () {
    final source = buildExternalCatalogPluginSource('/catalog.db');

    expect(source.sourceId, pluginExternalCatalogSourceId);
    expect(source.readOnly, isTrue);
    expect(source.policy.tables, {
      'otzaria_hebrew_books',
      'hebrew_books',
    });
    expect(source.policy.isTableAllowed('otzar_hahochma'), isFalse);
    expect(
      source.policy.isColumnAllowed('hebrew_books', 'printing_place'),
      isFalse,
    );
    expect(source.policy.maxLimit, 20);
    expect(source.policy.maxJoins, 1);
    expect(source.policy.maxOffset, 0);
    expect(source.policy.maxResultBytes, 64 * 1024);
  });

  test('ה-join היחיד מחבר מזהה היברובוקס לכותרת הקטלוג', () {
    final policy = buildExternalCatalogPluginSource('/catalog.db').policy;

    expect(
      policy.isJoinAllowed(
        'otzaria_hebrew_books',
        'hb_id',
        'hebrew_books',
        'id_book',
      ),
      isTrue,
    );
    expect(
      policy.isJoinAllowed(
        'otzaria_hebrew_books',
        'otzaria_id',
        'hebrew_books',
        'id_book',
      ),
      isFalse,
    );
  });
}
