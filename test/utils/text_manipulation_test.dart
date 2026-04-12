import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text_manipulation.dart';

void main() {
  group('highLight', () {
    test('single word - highlights the word', () {
      const text = 'כל יום טוב';
      final result = highLight(text, 'יום');
      expect(result, contains('<span style="color: red">'));
      expect(result, contains('יום'));
    });

    test('multi-word query - highlights only the complete sequence', () {
      // "כל היום" should be highlighted only where both words appear together
      const text = 'היה זה כל היום טוב';
      final result = highLight(text, 'כל היום');
      // המילה "היה" לא אמורה להיות מודגשת
      expect(result, isNot(contains('<span style="color: red">היה')));
      // הרצף "כל היום" אמור להיות מודגש כיחידה אחת
      expect(result, contains('<span style="color: red">כל היום</span>'));
      // "היה", "זה", "טוב" לא אמורים להיות מודגשים
      expect(result, isNot(contains('<span style="color: red">טוב')));
    });

    test('multi-word query - does not highlight lone words from query', () {
      // אם מחפשים "כל היום", מילה בודדת "כל" לא אמורה להיות מודגשת
      const text = 'כל הספרים היו שם';
      final result = highLight(text, 'כל היום');
      // אין מופע של "כל היום" יחד - לכן לא אמור להיות highlighting כלל
      expect(result, isNot(contains('<span')));
    });

    test('single word with nikud in text - highlights correctly', () {
      const text = 'הָיָה כָּל הַיּוֹם';
      final result = highLight(text, 'כל');
      expect(result, contains('<span style="color: red">'));
    });
  });

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
