// טסטים ל-calculateDailyTimes: וידוא שהמפתחות שברישום מוחזרים בפועל,
// יחסי הזמנים נכונים, וזמנים תלויי-יום (תענית) מופיעים רק כשרלוונטי.

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:otzaria/tools/calendar/helpers/zmanim_helpers.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
  });

  // אמצע יוני — בקיץ ההפרש בין שעות שוות לזמניות בולט (היום ארוך מ-12
  // שעות), ולכן קצה טוב להבחנה בין שיטות החישוב.
  final summerDate = DateTime(2026, 6, 15);
  const city = 'ירושלים';

  group('calculateDailyTimes — מפתחות עיקריים', () {
    test('מחזיר את כל וריאנטי עלות השחר (מעלות / שוות / זמניות, 72/90)', () {
      final times = calculateDailyTimes(summerDate, city);

      expect(times['alos72Degrees'], isNotNull);
      expect(times['alos90Degrees'], isNotNull);
      expect(times['alos72Shavos'], isNotNull);
      expect(times['alos90Shavos'], isNotNull);
      expect(times['alos72Zmanis'], isNotNull);
      expect(times['alos90Zmanis'], isNotNull);
    });

    test('מחזיר את משיכיר 10.2° (זמן ציצית ותפילין)', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['misheyakir10point2'], isNotNull);
      expect(times['misheyakir10point2'], isNot(equals('')));
    });

    test('מחזיר את ר"ת בדקות שוות ובמעלות', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['rt72Shavos'], isNotNull);
      expect(times['rt72Degrees'], isNotNull);
    });

    test('מחזיר את שקיעה מישורית (sea level) לצד שקיעה רגילה', () {
      final times = calculateDailyTimes(summerDate, city);

      expect(times['sunset'], isNotNull);
      expect(times['seaLevelSunset'], isNotNull);
      // בירושלים (754 מ׳) — השקיעה המתוקנת-גובה מאוחרת מהמישורית.
      expect(times['seaLevelSunset']!.compareTo(times['sunset']!), lessThan(0),
          reason: 'שקיעה מישורית צריכה להיות מוקדמת משקיעה מתוקנת-גובה');
    });
  });

  group('calculateDailyTimes — פורמט וחוקיות', () {
    test('כל הזמנים בפורמט HH:MM (למעט קידוש לבנה שמציג תאריך עברי)', () {
      final times = calculateDailyTimes(summerDate, city);
      final pattern = RegExp(r'^\d{2}:\d{2}$');
      // קידוש לבנה מוצג עם ליל-שבוע ותאריך עברי, לא כ-HH:MM בלבד.
      const hebrewDateKeys = {
        'tchilasKidushLevana3',
        'tchilasKidushLevana7',
        'sofKidushLevanaMoldos',
        'sofKidushLevana15',
      };
      for (final entry in times.entries) {
        if (hebrewDateKeys.contains(entry.key)) continue;
        expect(pattern.hasMatch(entry.value), isTrue,
            reason: 'הזמן ${entry.key} = "${entry.value}" אינו בפורמט HH:MM');
      }
    });

    test('עלות זמניות מוקדם מעלות שוות בקיץ (היום ארוך מ-12 שעות)', () {
      final times = calculateDailyTimes(summerDate, city);
      final shavos72 = times['alos72Shavos']!;
      final zmanis72 = times['alos72Zmanis']!;
      expect(zmanis72.compareTo(shavos72), lessThan(0),
          reason: 'בקיץ עלות 72 זמניות מוקדם מ-72 שוות. '
              'zmanis=$zmanis72 shavos=$shavos72');
    });

    test('עלות 90 מוקדם מעלות 72 (בכל השיטות)', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['alos90Shavos']!.compareTo(times['alos72Shavos']!),
          lessThan(0));
      expect(times['alos90Zmanis']!.compareTo(times['alos72Zmanis']!),
          lessThan(0));
      expect(times['alos90Degrees']!.compareTo(times['alos72Degrees']!),
          lessThan(0));
    });

    test('ר"ת מאוחר מהשקיעה', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['rt72Degrees']!.compareTo(times['sunset']!), greaterThan(0));
      expect(times['rt72Shavos']!.compareTo(times['sunset']!), greaterThan(0));
    });
  });

  group('calculateDailyTimes — יציאת הצום (תלוי-יום)', () {
    // י"ז בתמוז 5786 = 2026-07-02 (תענית קלה).
    final fastDate = DateTime(2026, 7, 2);

    test('בתאריך תענית — מחזיר את וריאנטי יציאת הצום', () {
      final times = calculateDailyTimes(fastDate, city);
      expect(times['fastEndTikLenient'], isNotNull);
      expect(times['fastEndItimLenient'], isNotNull);
      expect(times['fastEndTikStringent'], isNotNull);
      expect(times['fastEndItimStringent'], isNotNull);
    });

    test('סדר הזמנים: קולא לפני חומרא; 18 דק׳ זהה בין השיטות', () {
      final times = calculateDailyTimes(fastDate, city);
      final tikLenient = times['fastEndTikLenient']!; // 13.5 דק׳
      final itimLenient = times['fastEndItimLenient']!; // 18 דק׳
      final tikStringent = times['fastEndTikStringent']!; // 18 דק׳
      final itimStringent = times['fastEndItimStringent']!; // 22 דק׳

      expect(tikLenient.compareTo(itimLenient), lessThan(0));
      expect(itimLenient, equals(tikStringent));
      expect(tikStringent.compareTo(itimStringent), lessThan(0));
    });

    test('ביום רגיל (לא תענית) — זמני יציאת הצום לא קיימים', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['fastEndTikLenient'], isNull);
      expect(times['fastEndItimLenient'], isNull);
    });
  });

  group('calculateDailyTimes — קידוש לבנה', () {
    test('זמני קידוש לבנה זמינים בכל יום (לא תלויי-יום)', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['tchilasKidushLevana3'], isNotNull);
      expect(times['sofKidushLevanaMoldos'], isNotNull);
    });

    test('הערך כולל ליל-שבוע, יום-חודש עברי ושעה', () {
      final times = calculateDailyTimes(summerDate, city);
      final value = times['tchilasKidushLevana3']!;
      // למשל: "ליל שני ט"ו לחודש 20:02"
      expect(value, startsWith('ליל '));
      expect(value, matches(RegExp(r'לחודש \d{2}:\d{2}$')));
    });
  });

  group('calculateDailyTimes — חצות לילה אסטרונומי', () {
    test('מחזיר ערך תקין לחצות לילה', () {
      final times = calculateDailyTimes(summerDate, city);
      expect(times['chatzosLayla'], isNotNull);
      expect(times['chatzosLayla'], matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('חצות לילה סביב חצות (00:00-02:00 בקיץ ירושלים)', () {
      final times = calculateDailyTimes(summerDate, city);
      final hour = int.parse(times['chatzosLayla']!.split(':')[0]);
      expect(hour, anyOf(equals(0), equals(1)),
          reason: 'חצות לילה בקיץ בין 00:00 ל-02:00 '
              '(התקבל: ${times['chatzosLayla']})');
    });
  });
}
