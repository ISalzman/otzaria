import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

/// המימוש הקודם של נרמול טקסט לחיפוש ספרים — שרשרת replaceAll. משמש כאן
/// כמימוש-ייחוס: המעבר היחיד שהחליף אותו חייב להסכים איתו על כל קלט.
final RegExp _nonSearchableChars = RegExp(r'[^a-zA-Z0-9֐-׿\s]');
final RegExp _whitespaceRun = RegExp(r'\s+');

String referenceNormalize(String input) {
  var cleaned = removeTeamim(removeVolwels(input));
  cleaned = cleaned.replaceAll('"', '').replaceAll("'", '');
  cleaned = cleaned.replaceAll('״', '').replaceAll('׳', '');
  cleaned = cleaned.replaceAll(_nonSearchableChars, ' ');
  return cleaned.toLowerCase().replaceAll(_whitespaceRun, ' ').trim();
}

void main() {
  group('שקילות הנרמול למימוש הקודם', () {
    test('כל תווי ה-BMP, בכל מיקום במחרוזת', () {
      final mismatches = <String>[];
      for (var cp = 0; cp <= 0xFFFF; cp++) {
        final ch = String.fromCharCode(cp);
        final templates = <String>[
          ch,
          'אב$ch',
          '$chגד',
          'א$ch'
              'ב',
          ' $ch ',
          'abc${ch}def',
          '12$ch'
              '34',
        ];
        for (final t in templates) {
          final expected = referenceNormalize(t);
          final actual = normalizeBookSearchTextForTesting(t);
          if (expected != actual) {
            mismatches.add(
              'cp=0x${cp.toRadixString(16)} template=${t.codeUnits} '
              'expected=${expected.codeUnits} actual=${actual.codeUnits}',
            );
          }
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason:
            'נמצאו ${mismatches.length} אי-התאמות; '
            'ראשונות: ${mismatches.take(5).join(" | ")}',
      );
    });

    test('תווים מעל ה-BMP וחצאי surrogate בגבולות המחרוזת', () {
      // ה-regex הישן פעל על code units ללא דגל unicode, ולכן הפך כל חצי
      // surrogate בנפרד לרווח; המעבר החדש חייב להתכווץ לאותו רווח יחיד.
      const astral = <String>[
        '😀',
        '𐀀',
        '𝐀',
        '\u{10FFFF}',
        '\u{2F800}',
        '🇦',
      ];
      final cases = <String>[];
      for (final a in astral) {
        cases.addAll([
          a,
          '$a ספר',
          'ספר$a',
          'ספר$a'
              'תורה',
          '$a'
              '$a',
          'א$a ב',
        ]);
      }
      // חצאי surrogate בודדים, כולל בקצוות ובצמידות
      cases.addAll([
        '\uD83D',
        '\uDE00',
        '\uD83Dספר',
        'ספר\uDE00',
        '\uD83Dספר\uDE00',
        '\uD800\uD800',
        '\uDC00א\uD800',
      ]);
      for (final c in cases) {
        expect(
          normalizeBookSearchTextForTesting(c),
          referenceNormalize(c),
          reason: 'קלט: ${c.codeUnits}',
        );
      }
    });

    test('זוגות surrogate, רווחים מרובים ומקרי קצה', () {
      const cases = <String>[
        '',
        ' ',
        '   ',
        '\t\n\r',
        'רמב"ם',
        "רש'י",
        'רמב״ם',
        'ש׳ס',
        'בְּרֵאשִׁית',
        'וַיְדַבֵּ֥ר',
        'מקף־מחבר',
        'פסק׀כאן',
        'צינור|כאן',
        '😀ספר😀',
        'ABC def',
        'Book 12 — פרק ג',
        '   מרווח   בהתחלה ובסוף   ',
        'אׇ֑ב',
      ];
      for (final c in cases) {
        expect(
          normalizeBookSearchTextForTesting(c),
          referenceNormalize(c),
          reason: 'קלט: ${c.codeUnits}',
        );
      }
    });
  });
}
