import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/external_catalog_mapper.dart';

void main() {
  group('ExternalCatalogMapper', () {
    test('resolveLink מחזיר קישור HebrewBooks תקין', () {
      expect(
        ExternalCatalogMapper.resolveLink(externalLibraryId: 'hb:77'),
        'https://hebrewbooks.org/77',
      );
    });

    test('resolveLink מחזיר קישור אוצר החכמה תקין', () {
      expect(
        ExternalCatalogMapper.resolveLink(externalLibraryId: 'oh:42'),
        'https://tablet.otzar.org/book/book.php?book=42',
      );
    });
  });
}
