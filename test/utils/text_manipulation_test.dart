import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text_manipulation.dart';

void main() {
  group('removePunctuation', () {
    test('keeps dot and colon inside nested parentheses', () {
      const input = 'שלום: עולם! (א:ב. (ג:ד.))';

      final result = removePunctuation(input);

      expect(result, equals('שלום עולם (א:ב. (ג:ד.))'));
    });

    test('keeps allowed punctuation at end of line', () {
      const input = 'משפט עם נקודה.';

      final result = removePunctuation(input);

      expect(result, equals('משפט עם נקודה.'));
    });
  });
}
