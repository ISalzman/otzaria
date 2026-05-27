import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/book_source_dialog.dart';

void main() {
  group('getSourceDisplayInfo', () {
    test('should resolve Sefaria source case-insensitively', () {
      final lower = getSourceDisplayInfo('sefaria');
      final upper = getSourceDisplayInfo('Sefaria');

      expect(lower.text, equals('ספריא'));
      expect(upper.text, equals('ספריא'));
      expect(lower.url, equals('https://www.sefaria.org/texts'));
      expect(upper.url, equals('https://www.sefaria.org/texts'));
    });

    test('should resolve Tashma source with link', () {
      final info = getSourceDisplayInfo('Tashma');

      expect(info.text, equals('תא שמע'));
      expect(info.url, equals('https://tashma.co.il/'));
    });
  });

  group('isTashmaSource', () {
    test('should detect Tashma source case-insensitively', () {
      expect(isTashmaSource('Tashma'), isTrue);
      expect(isTashmaSource('tashma'), isTrue);
      expect(isTashmaSource('TashmaToOtzaria'), isTrue);
    });

    test('should detect Tashma variants with separators', () {
      // אותו נרמול כמו getSourceDisplayInfo - הסרת רווחים/מקפים/קווים תחתונים
      expect(isTashmaSource('Ta-Shma'), isTrue);
      expect(isTashmaSource('Ta Shma'), isTrue);
      expect(isTashmaSource('Ta_Shma'), isTrue);
      // כל הווריאנטים האלה גם מזוהים כתא שמע בתצוגת המקור
      expect(getSourceDisplayInfo('Ta-Shma').text, equals('תא שמע'));
    });

    test('should return false for non-Tashma or empty sources', () {
      expect(isTashmaSource('sefaria'), isFalse);
      expect(isTashmaSource(''), isFalse);
      expect(isTashmaSource(null), isFalse);
    });
  });
}
