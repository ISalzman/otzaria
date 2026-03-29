import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';

void main() {
  group('TantivyDataProvider.shouldInvalidateStoredIndexState', () {
    test('מחזיר true כשגרסת מצב האינדקס השתנתה', () {
      final shouldInvalidate =
          TantivyDataProvider.shouldInvalidateStoredIndexState(
        storedIndexStateVersion:
            TantivyDataProvider.currentIndexStateVersion - 1,
        storedCatalogueOrderSignature: 'same-signature',
        currentCatalogueOrderSignature: 'same-signature',
      );

      expect(shouldInvalidate, isTrue);
    });

    test('מחזיר true כשחתימת הקטלוג השתנתה', () {
      final shouldInvalidate =
          TantivyDataProvider.shouldInvalidateStoredIndexState(
        storedIndexStateVersion: TantivyDataProvider.currentIndexStateVersion,
        storedCatalogueOrderSignature: 'old-signature',
        currentCatalogueOrderSignature: 'new-signature',
      );

      expect(shouldInvalidate, isTrue);
    });

    test('מחזיר false כשהגרסה והחתימה תואמות', () {
      final shouldInvalidate =
          TantivyDataProvider.shouldInvalidateStoredIndexState(
        storedIndexStateVersion: TantivyDataProvider.currentIndexStateVersion,
        storedCatalogueOrderSignature: 'same-signature',
        currentCatalogueOrderSignature: 'same-signature',
      );

      expect(shouldInvalidate, isFalse);
    });
  });
}
