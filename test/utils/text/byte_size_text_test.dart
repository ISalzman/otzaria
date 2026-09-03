import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text/byte_size_text.dart';

const String lri = '\u2066';
const String pdi = '\u2069';

void main() {
  group('formatMegabytesLtr', () {
    test('מעצב מגה-בייט ועוטף את המספר והיחידה בבידוד LTR אחד', () {
      final text = formatMegabytesLtr(91876000);

      expect(text, '${lri}87.6 MB$pdi');
    });

    test('היחידה נשארת בתוך הבידוד — לא אחריו', () {
      final text = formatMegabytesLtr(91876000);

      expect(text.endsWith('MB$pdi'), isTrue);
      expect(text.indexOf('MB'), lessThan(text.indexOf(pdi)));
    });

    test('מספר ספרות עשרוניות ניתן לשליטה', () {
      expect(formatMegabytesLtr(1 << 20, fractionDigits: 0), '${lri}1 MB$pdi');
    });
  });

  group('formatMegabytesProgressHebrew', () {
    test('כל ערך מבודד בנפרד ו"מתוך" נשאר מחוץ לבידוד', () {
      final text = formatMegabytesProgressHebrew(91876000, 1908932608);

      expect(text, '${lri}87.6 MB$pdi מתוך ${lri}1820.5 MB$pdi');
    });

    test('שני בידודים סגורים — אחד לכל ערך', () {
      final text = formatMegabytesProgressHebrew(1, 2);

      expect(lri.allMatches(text).length, 2);
      expect(pdi.allMatches(text).length, 2);
    });
  });

  group('ltrIsolate', () {
    test('עוטף ערך גולמי', () {
      expect(ltrIsolate('1820MB'), '${lri}1820MB$pdi');
    });
  });
}
