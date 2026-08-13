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
    expect(source.policy.maxJoins, 1);
    expect(source.policy.maxOffset, 0);
  });

  test('מכסות ה-bulk מאפשרות מיפוי אינדקס שלם במעבר גשר אחד', () {
    // ספק תוצאות חיצוני ממפה עד ~10K מזהים בסיווג האינדקס: 1000 ערכי IN
    // לשאילתה × 10 שאילתות ב-batch. הקטנת המכסות מחזירה מאות מעברי גשר.
    final policy = buildExternalCatalogPluginSource('/catalog.db').policy;

    expect(policy.maxInValues, 1000);
    expect(policy.maxLimit, 1000);
    expect(policy.maxBatchQueries, 10);
    // 1000 מזהים בני עד ~7 ספרות בשאילתה — מעל 4KB פרמטרים.
    expect(policy.maxParameterBytes, greaterThanOrEqualTo(16 * 1024));
    // 1000 שורות מיפוי בפורמט object — מעל 64KB תוצאה.
    expect(policy.maxResultBytes, greaterThanOrEqualTo(256 * 1024));
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
