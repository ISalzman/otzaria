import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/word_number_format.dart';

/// מקור יחיד לפורמטי המספור של Word — משמש את שלושת הממירים (DOCX, WordML
/// 2003, DOC בינארי) גם לרשימות ממוספרות וגם לסימוני הערות שוליים.
void main() {
  group('formatWordNumber', () {
    test('decimal ו-decimalZero', () {
      expect(formatWordNumber(7, 'decimal'), '7');
      expect(formatWordNumber(7, 'decimalZero'), '07');
      expect(formatWordNumber(12, 'decimalZero'), '12');
    });

    test('אותיות לטיניות', () {
      expect(formatWordNumber(1, 'lowerLetter'), 'a');
      expect(formatWordNumber(1, 'upperLetter'), 'A');
    });

    test('ספרות רומיות', () {
      expect(formatWordNumber(4, 'lowerRoman'), 'iv');
      expect(formatWordNumber(4, 'upperRoman'), 'IV');
    });

    test('אותיות עבריות — שני הפורמטים', () {
      expect(formatWordNumber(1, 'hebrew1'), 'א');
      expect(formatWordNumber(15, 'hebrew1'), 'טו');
      expect(formatWordNumber(15, 'hebrew2'), 'טו');
    });

    // סדרת Word: *, †, ‡, § ואחר כך כפולים.
    test('chicago', () {
      expect(formatWordNumber(1, 'chicago'), '*');
      expect(formatWordNumber(4, 'chicago'), '§');
      expect(formatWordNumber(5, 'chicago'), '**');
      expect(formatWordNumber(9, 'chicago'), '***');
    });

    test('none מחזיר מחרוזת ריקה — הקורא מחליט מה לעשות', () {
      expect(formatWordNumber(3, 'none'), '');
    });

    test('פורמט לא מוכר נופל לספרות', () {
      expect(formatWordNumber(5, 'aiueo'), '5');
    });
  });

  group('wordNumFmtForMsonfc', () {
    test('הקודים הנפוצים', () {
      expect(wordNumFmtForMsonfc(0), 'decimal');
      expect(wordNumFmtForMsonfc(1), 'upperRoman');
      expect(wordNumFmtForMsonfc(2), 'lowerRoman');
      expect(wordNumFmtForMsonfc(3), 'upperLetter');
      expect(wordNumFmtForMsonfc(4), 'lowerLetter');
      expect(wordNumFmtForMsonfc(9), 'chicago');
      expect(wordNumFmtForMsonfc(22), 'decimalZero');
      expect(wordNumFmtForMsonfc(23), 'bullet');
      expect(wordNumFmtForMsonfc(255), 'none');
    });

    // 46 ו-48 שביניהם הם פורמטים ערביים, ולכן הרשימה אינה רצף.
    test('שני פורמטי האותיות העבריות', () {
      expect(wordNumFmtForMsonfc(45), 'hebrew1');
      expect(wordNumFmtForMsonfc(47), 'hebrew1');
    });

    test('null וקוד לא מוכר נופלים לספרות', () {
      expect(wordNumFmtForMsonfc(null), 'decimal');
      expect(wordNumFmtForMsonfc(12), 'decimal');
    });
  });
}
