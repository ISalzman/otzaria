import 'package:flutter_test/flutter_test.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:otzaria/tools/calendar/helpers/omer_counting_helpers.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
  });

  group('buildOmerDisplayData', () {
    test('עובר ליום הראשון של העומר אחרי שקיעה גם אם התאריך הנבחר הוא ערב החג',
        () {
      final firstOmerDay = _gregorianForJewishDate(5786, 1, 16);
      final erevFirstOmer = firstOmerDay.subtract(const Duration(days: 1));

      final expected = buildOmerDisplayData(
        selectedDate: DateTime(
          firstOmerDay.year,
          firstOmerDay.month,
          firstOmerDay.day,
        ),
        cityName: 'ירושלים',
        dailyTimes: const {
          'sunset': '18:00',
          'tzais': '18:30',
          'omerCounting': '18:30',
        },
        now: DateTime(
          firstOmerDay.year,
          firstOmerDay.month,
          firstOmerDay.day,
          12,
        ),
      );

      final actual = buildOmerDisplayData(
        selectedDate: DateTime(
          erevFirstOmer.year,
          erevFirstOmer.month,
          erevFirstOmer.day,
        ),
        cityName: 'ירושלים',
        dailyTimes: const {
          'sunset': '18:00',
          'tzais': '18:30',
        },
        now: DateTime(
          erevFirstOmer.year,
          erevFirstOmer.month,
          erevFirstOmer.day,
          18,
          1,
        ),
      );

      expect(actual, isNotNull);
      expect(actual!.day, expected!.day);
      expect(actual.text, expected.text);
      expect(actual.timeLabel, '18:30');
    });

    test('לפני שקיעה נשארים באותו יום עומר', () {
      final secondOmerDay = _gregorianForJewishDate(5786, 1, 17);

      final expected = buildOmerDisplayData(
        selectedDate: DateTime(
          secondOmerDay.year,
          secondOmerDay.month,
          secondOmerDay.day,
          12,
        ),
        cityName: 'ירושלים',
        dailyTimes: const {
          'sunset': '18:00',
          'tzais': '18:30',
          'omerCounting': '18:30',
        },
        now: DateTime(
          secondOmerDay.year,
          secondOmerDay.month,
          secondOmerDay.day,
          12,
        ),
      );

      final actual = buildOmerDisplayData(
        selectedDate: DateTime(
          secondOmerDay.year,
          secondOmerDay.month,
          secondOmerDay.day,
        ),
        cityName: 'ירושלים',
        dailyTimes: const {
          'sunset': '18:00',
          'tzais': '18:30',
          'omerCounting': '18:30',
        },
        now: DateTime(
          secondOmerDay.year,
          secondOmerDay.month,
          secondOmerDay.day,
          17,
          59,
        ),
      );

      expect(actual, isNotNull);
      expect(actual!.day, expected!.day);
      expect(actual.text, expected.text);
    });

    test('תאריך עבר ללא שעה מפורשת לא מתקדם לפי השעה הנוכחית של היום', () {
      final firstOmerDay = _gregorianForJewishDate(5786, 1, 16);
      final laterDay = firstOmerDay.add(const Duration(days: 3));

      final expected = buildOmerDisplayData(
        selectedDate: DateTime(
          firstOmerDay.year,
          firstOmerDay.month,
          firstOmerDay.day,
          12,
        ),
        cityName: 'ירושלים',
        dailyTimes: const {
          'sunset': '18:00',
          'tzais': '18:30',
          'omerCounting': '18:30',
        },
        now: DateTime(
          firstOmerDay.year,
          firstOmerDay.month,
          firstOmerDay.day,
          12,
        ),
      );

      final actual = buildOmerDisplayData(
        selectedDate: DateTime(
          firstOmerDay.year,
          firstOmerDay.month,
          firstOmerDay.day,
        ),
        cityName: 'ירושלים',
        dailyTimes: const {
          'sunset': '18:00',
          'tzais': '18:30',
          'omerCounting': '18:30',
        },
        now: DateTime(
          laterDay.year,
          laterDay.month,
          laterDay.day,
          21,
        ),
      );

      expect(actual, isNotNull);
      expect(actual!.day, expected!.day);
      expect(actual.text, expected.text);
    });
  });
}

DateTime _gregorianForJewishDate(int year, int month, int day) {
  final jewishDate = JewishDate()..setJewishDate(year, month, day);
  return jewishDate.getGregorianCalendar();
}
