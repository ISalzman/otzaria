import 'package:kosher_dart/kosher_dart.dart';
import 'package:otzaria/tools/calendar/models/calendar_location.dart';
import 'package:timezone/timezone.dart' as tz;

/// נתוני תצוגה לספירת העומר בפאנל הזמנים.
class OmerDisplayData {
  final int day;
  final String text;
  final String timeLabel;

  const OmerDisplayData({
    required this.day,
    required this.text,
    required this.timeLabel,
  });
}

/// מחזירה את נתוני התצוגה של ספירת העומר לפי היום ההלכתי בעיר שנבחרה.
///
/// כאשר התאריך הנבחר אינו כולל שעה מפורשת, הפונקציה מתייחסת ליום עצמו
/// ולא ל-00:00. אם זהו היום הנוכחי בעיר, משתמשים בשעה הנוכחית בעיר כדי
/// לאפשר מעבר אוטומטי אחרי שקיעה; אחרת משתמשים ב-12:00 כדי לייצג את היום.
OmerDisplayData? buildOmerDisplayData({
  required DateTime selectedDate,
  required String cityName,
  required Map<String, String> dailyTimes,
  DateTime? now,
}) {
  final tzLocation = _resolveCityLocation(cityName);
  final selectedInCity = tz.TZDateTime.from(selectedDate, tzLocation);
  final nowInCity = now == null
      ? tz.TZDateTime.now(tzLocation)
      : tz.TZDateTime.from(now, tzLocation);
  final hasExplicitTime = _hasExplicitTime(selectedDate);
  final isTodayInCity = _isSameCivilDate(selectedInCity, nowInCity);

  final referenceDate = hasExplicitTime
      ? selectedInCity
      : isTodayInCity
          ? nowInCity
          : tz.TZDateTime(
              tzLocation,
              selectedInCity.year,
              selectedInCity.month,
              selectedInCity.day,
              12,
            );

  final sunset = _parseTimeLabelForDate(
    dailyTimes['sunset'],
    tzLocation: tzLocation,
    date: selectedInCity,
  );
  final afterSunset = sunset != null && !referenceDate.isBefore(sunset);
  final omerDate = afterSunset
      ? tz.TZDateTime(
          tzLocation,
          referenceDate.year,
          referenceDate.month,
          referenceDate.day + 1,
          12,
        )
      : referenceDate;

  final jewishCalendar = JewishCalendar.fromDateTime(omerDate);
  final omerDay = jewishCalendar.getDayOfOmer();
  if (omerDay == -1) {
    return null;
  }

  return OmerDisplayData(
    day: omerDay,
    text: _buildOmerCountingText(omerDay),
    timeLabel: _resolveOmerTimeLabel(
      dailyTimes: dailyTimes,
      afterSunset: afterSunset,
    ),
  );
}

tz.Location _resolveCityLocation(String cityName) {
  final cityData = getCityData(cityName);
  final timeZoneId = cityData?['timezone'] as String? ?? 'Asia/Jerusalem';
  return tz.getLocation(timeZoneId);
}

bool _hasExplicitTime(DateTime date) {
  return date.hour != 0 ||
      date.minute != 0 ||
      date.second != 0 ||
      date.millisecond != 0 ||
      date.microsecond != 0;
}

bool _isSameCivilDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

DateTime? _parseTimeLabelForDate(
  String? timeLabel, {
  required tz.Location tzLocation,
  required DateTime date,
}) {
  if (timeLabel == null || timeLabel.isEmpty || timeLabel == '--:--') {
    return null;
  }

  final parts = timeLabel.split(':');
  if (parts.length != 2) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }

  return tz.TZDateTime(
    tzLocation,
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  );
}

String _resolveOmerTimeLabel({
  required Map<String, String> dailyTimes,
  required bool afterSunset,
}) {
  final configuredTime = dailyTimes['omerCounting'];
  if (configuredTime != null && configuredTime.isNotEmpty) {
    return configuredTime;
  }

  if (afterSunset) {
    final tzais = dailyTimes['tzais'];
    if (tzais != null && tzais.isNotEmpty) {
      return tzais;
    }
  }

  return '--:--';
}

String _buildOmerCountingText(int day) {
  final totalDaysText = _buildOmerDayCountText(day);
  final weeks = day ~/ 7;
  final extraDays = day % 7;

  if (weeks == 0) {
    return 'היום $totalDaysText בעומר';
  }

  final weeksText = _buildOmerWeekCountText(weeks);
  if (extraDays == 0) {
    return 'היום $totalDaysText שהם $weeksText בעומר';
  }

  final extraDaysText = _buildOmerDayCountText(extraDays);
  return 'היום $totalDaysText שהם $weeksText ו$extraDaysText בעומר';
}

String _buildOmerDayCountText(int day) {
  const ones = [
    '',
    'יום אחד',
    'שני ימים',
    'שלשה ימים',
    'ארבעה ימים',
    'חמשה ימים',
    'ששה ימים',
    'שבעה ימים',
    'שמונה ימים',
    'תשעה ימים',
    'עשרה ימים',
    'אחד עשר יום',
    'שנים עשר יום',
    'שלשה עשר יום',
    'ארבעה עשר יום',
    'חמשה עשר יום',
    'ששה עשר יום',
    'שבעה עשר יום',
    'שמונה עשר יום',
    'תשעה עשר יום',
  ];
  const tens = ['', '', 'עשרים', 'שלשים', 'ארבעים'];
  const onesSimple = [
    '',
    'אחד',
    'שנים',
    'שלשה',
    'ארבעה',
    'חמשה',
    'ששה',
    'שבעה',
    'שמונה',
    'תשעה',
  ];

  if (day <= 0 || day > 49) {
    return 'יום $day';
  }

  if (day < 20) {
    return ones[day];
  }

  final tensText = tens[day ~/ 10];
  final onesValue = day % 10;
  if (onesValue == 0) {
    return '$tensText יום';
  }

  return '${onesSimple[onesValue]} ו$tensText יום';
}

String _buildOmerWeekCountText(int weeks) {
  const oneToNine = [
    '',
    'אחד',
    'שני',
    'שלשה',
    'ארבעה',
    'חמשה',
    'ששה',
    'שבעה',
    'שמונה',
    'תשעה',
  ];

  if (weeks <= 0) {
    return '';
  }
  if (weeks == 1) {
    return 'שבוע אחד';
  }
  if (weeks == 2) {
    return 'שני שבועות';
  }

  return '${oneToNine[weeks]} שבועות';
}
