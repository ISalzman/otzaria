import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:otzaria/tools/calendar/services/google_calendar_service.dart';

void main() {
  group('GoogleCalendarService scopes', () {
    test('כולל הרשאת אירועים לסנכרון', () {
      expect(
        GoogleCalendarService.scopes,
        contains(cal.CalendarApi.calendarEventsScope),
      );
    });

    // בלי scope לרשימת היומנים calendarList.list מחזיר 403 ובחירת
    // היומנים מציגה תמיד "לא נמצאו לוחות שנה" (issue #1075)
    test('כולל הרשאת קריאה לרשימת היומנים', () {
      expect(
        GoogleCalendarService.scopes,
        contains(cal.CalendarApi.calendarCalendarlistReadonlyScope),
      );
    });
  });
}
