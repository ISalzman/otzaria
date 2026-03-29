import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';

void main() {
  group('IndexingRepository.shouldResetBeforeFullReindex', () {
    test('מחזיר true כשמתחילים בנייה מחדש מעל אינדקס קיים', () {
      final shouldReset = IndexingRepository.shouldResetBeforeFullReindex(
        indexExistedBeforeInit: true,
        booksDone: const [],
      );

      expect(shouldReset, isTrue);
    });

    test('מחזיר false ביצירה ראשונית של אינדקס חדש', () {
      final shouldReset = IndexingRepository.shouldResetBeforeFullReindex(
        indexExistedBeforeInit: false,
        booksDone: const [],
      );

      expect(shouldReset, isFalse);
    });

    test('מחזיר false כשמדובר בעדכון אינקרמנטלי', () {
      final shouldReset = IndexingRepository.shouldResetBeforeFullReindex(
        indexExistedBeforeInit: true,
        booksDone: const ['ספר אחד'],
      );

      expect(shouldReset, isFalse);
    });
  });
}
