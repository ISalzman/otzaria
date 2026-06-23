import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/tools/calendar/services/notification_service.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// --- Mocks ---

/// Mock שמחזיר תשובות מוגדרות מראש לפי סדר הקריאה.
/// כל תשובה היא Future — אפשר להשתמש ב-Future.delayed כדי להאט קריאה.
class _SequencedPluginAdapter implements CalendarPluginSource {
  final List<Future<List<CustomEvent>>> _responses;
  int _call = 0;

  _SequencedPluginAdapter(this._responses);

  @override
  Future<List<CustomEvent>> loadAndMergePluginEvents(
    List<CustomEvent> existingEvents, {
    String? currentWorkspaceId,
    String? currentBookId,
  }) async {
    final idx = _call < _responses.length ? _call : _responses.length - 1;
    _call++;
    final pluginEvents = await _responses[idx];
    return [...existingEvents, ...pluginEvents];
  }
}

class _FakeNotificationService implements NotificationService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<bool> checkPermissions() async => false;

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// SettingsRepository מינימלי בזיכרון — שומר ערכים שכתבנו וחושף אותם
/// דרך getters לאסרציות בטסטים.
class _InMemorySettingsRepository implements SettingsRepository {
  String calendarZmanAlertsJson = '{}';
  String calendarEnabledZmanim = '';

  @override
  Future<Map<String, dynamic>> loadSettings() async {
    return {
      'calendarType': 'combined',
      'selectedCity': 'ירושלים',
      'calendarEvents': '[]',
      'calendarNotificationsEnabled': false,
      'calendarNotificationTime': 60,
      'calendarNotificationSound': false,
      'calendarZmanAlerts': calendarZmanAlertsJson,
      'calendarEnabledZmanim': calendarEnabledZmanim,
      'calendarDayTransition': 'sunset',
      'googleCalendarEnabled': false,
      'googleCalendarSelectedIds': 'primary',
      'googleCalendarSyncPastDays': 60,
      'googleCalendarSyncFutureDays': 365,
      'googleCalendarLastSync': 0,
    };
  }

  @override
  Future<void> updateCalendarZmanAlertsJson(String json) async {
    calendarZmanAlertsJson = json;
  }

  @override
  Future<void> updateCalendarEnabledZmanim(String json) async {
    calendarEnabledZmanim = json;
  }

  @override
  String getCalendarEventNotificationIdsJson() => '[]';

  @override
  Future<void> updateCalendarEventNotificationIdsJson(String json) async {}

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// SettingsRepository עם אירוע שמור + עיכוב מלאכותי ב-loadSettings.
///
/// העיכוב מבטיח שה-_initializeCalendar יסיים את האתחול שלו
/// רק אחרי ש-refreshPluginEvents כבר תפס את state.events הראשוני
/// (הריק). כך ה-race condition שתוקן נבדק באופן אמין.
class _SlowSettingsWithStoredEvents implements SettingsRepository {
  final String eventsJson;

  _SlowSettingsWithStoredEvents({required this.eventsJson});

  @override
  Future<Map<String, dynamic>> loadSettings() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return {
      'calendarType': 'combined',
      'selectedCity': 'ירושלים',
      'calendarEvents': eventsJson,
      'calendarNotificationsEnabled': false,
      'calendarNotificationTime': 60,
      'calendarNotificationSound': false,
      'calendarZmanAlerts': '{}',
      'calendarEnabledZmanim': '',
      'calendarDayTransition': 'sunset',
      'googleCalendarEnabled': false,
      'googleCalendarSelectedIds': 'primary',
      'googleCalendarSyncPastDays': 60,
      'googleCalendarSyncFutureDays': 365,
      'googleCalendarLastSync': 0,
    };
  }

  @override
  String getCalendarEventNotificationIdsJson() => '[]';

  @override
  Future<void> updateCalendarEventNotificationIdsJson(String json) async {}

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

CustomEvent _buildUserEvent({String id = 'user-event-1'}) {
  final date = DateTime(2026, 5, 15);
  final jewish = JewishDate.fromDateTime(date);
  return CustomEvent(
    id: id,
    title: 'אירוע בדיקה',
    description: '',
    createdAt: DateTime(2026, 5, 1),
    baseGregorianDate: date,
    baseJewishYear: jewish.getJewishYear(),
    baseJewishMonth: jewish.getJewishMonth(),
    baseJewishDay: jewish.getJewishDayOfMonth(),
    recurrenceType: RecurrenceType.none,
  );
}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('CalendarCubit Jewish month navigation', () {
    test('next month handles Adar I -> Adar II and no year rollover to Nissan',
        () {
      // Create a JewishDate for a known leap year at Adar I (month 12)
      final jewish = JewishDate();
      // 5784 is a leap year in the 19-year cycle
      jewish.setJewishDate(5784, 12, 15); // Middle of Adar I

      expect(jewish.isJewishLeapYear(), isTrue);
      expect(jewish.getJewishMonth(), 12);

      final next = computeNextJewishMonth(jewish);
      expect(next.getJewishYear(), 5784);
      expect(next.getJewishMonth(), 13,
          reason: 'Should move to Adar II same year');

      final afterAdarII = computeNextJewishMonth(next);
      expect(afterAdarII.getJewishYear(), 5784,
          reason: 'After Adar II go to Nissan in same Jewish year');
      expect(afterAdarII.getJewishMonth(), 1);
    });

    test('previous month handles Nissan -> last Adar in same year', () {
      // Nissan of a leap year
      final nissan = JewishDate();
      nissan.setJewishDate(5784, 1, 7);
      expect(nissan.isJewishLeapYear(), isTrue);
      expect(nissan.getJewishMonth(), 1);

      final prev = computePreviousJewishMonth(nissan);
      expect(prev.getJewishYear(), 5784,
          reason: 'Nissan -> Adar stays in same Jewish year');
      expect(prev.getJewishMonth(), 13,
          reason: '5784 is leap; previous month is Adar II');
    });

    test('previous month handles Adar II -> Adar I within leap year', () {
      final adarII = JewishDate();
      adarII.setJewishDate(5784, 13, 3);
      expect(adarII.isJewishLeapYear(), isTrue);
      final prev = computePreviousJewishMonth(adarII);
      expect(prev.getJewishMonth(), 12);
      expect(prev.getJewishYear(), 5784);
    });
  });

  group('Calendar day transition', () {
    test('sunset moves the calendar day before midnight', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');

      final beforeSunset = resolveCalendarDayForTransition(
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 18),
        city: 'ירושלים',
        transition: CalendarDayTransition.sunset,
      );
      expect(beforeSunset, DateTime(2026, 4, 20));

      final afterSunset = resolveCalendarDayForTransition(
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 20, 30),
        city: 'ירושלים',
        transition: CalendarDayTransition.sunset,
      );
      expect(afterSunset, DateTime(2026, 4, 21));
    });

    test('sunset uses the selected city date, not the computer timezone date',
        () {
      final newYork = tz.getLocation('America/New_York');

      final beforeNewYorkSunset = resolveCalendarDayForTransition(
        now: tz.TZDateTime(newYork, 2026, 4, 20, 18),
        city: 'ניו יורק',
        transition: CalendarDayTransition.sunset,
      );

      expect(beforeNewYorkSunset, DateTime(2026, 4, 20));
    });

    test('midnight preserves the civil date until midnight', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');

      final lateEvening = resolveCalendarDayForTransition(
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 23, 30),
        city: 'ירושלים',
        transition: CalendarDayTransition.midnight,
      );
      expect(lateEvening, DateTime(2026, 4, 20));
    });

    test('rabbeinu tam waits longer than regular sunset', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');

      final afterSunsetBeforeRabbeinuTam = resolveCalendarDayForTransition(
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 19, 45),
        city: 'ירושלים',
        transition: CalendarDayTransition.rabbeinuTam,
      );
      expect(afterSunsetBeforeRabbeinuTam, DateTime(2026, 4, 20));

      final afterRabbeinuTam = resolveCalendarDayForTransition(
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 21, 30),
        city: 'ירושלים',
        transition: CalendarDayTransition.rabbeinuTam,
      );
      expect(afterRabbeinuTam, DateTime(2026, 4, 21));
    });
  });

  group('Calendar header Ohr prefix', () {
    test('shows Ohr prefix before 90 minute alos on the current day', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');
      final date = DateTime(2026, 4, 20);
      final state = _buildCalendarState(date);

      final shouldShow = shouldShowOhrPrefixForCalendarHeader(
        state: state,
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 3),
      );

      expect(shouldShow, isTrue);
    });

    test('does not show Ohr prefix after 90 minute alos', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');
      final date = DateTime(2026, 4, 20);
      final state = _buildCalendarState(date);

      final shouldShow = shouldShowOhrPrefixForCalendarHeader(
        state: state,
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 5),
      );

      expect(shouldShow, isFalse);
    });

    test('does not show Ohr prefix when selected date is not current day', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');
      final selected = DateTime(2026, 4, 19);
      final today = DateTime(2026, 4, 20);
      final state = _buildCalendarState(selected, today: today);

      final shouldShow = shouldShowOhrPrefixForCalendarHeader(
        state: state,
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 3),
      );

      expect(shouldShow, isFalse);
    });

    test('next refresh is scheduled for alos when it is the next boundary', () {
      final jerusalem = tz.getLocation('Asia/Jerusalem');

      final nextRefresh = nextCalendarTodayRefreshTime(
        now: tz.TZDateTime(jerusalem, 2026, 4, 20, 3),
        city: 'ירושלים',
        transition: CalendarDayTransition.sunset,
      );

      final refreshInJerusalem = tz.TZDateTime.from(nextRefresh, jerusalem);
      expect(refreshInJerusalem.year, 2026);
      expect(refreshInJerusalem.month, 4);
      expect(refreshInJerusalem.day, 20);
      expect(refreshInJerusalem.hour, 4);
    });
  });

  group('refreshPluginEvents — race condition', () {
    // רגרסיה לבאג שנוצר ב-31af97e60: refreshPluginEvents קרא את state.events
    // לפני ה-await, כך שאם _initializeCalendar הסתיים ו-emit בזמן ה-await,
    // הוא היה דורס את האירועים בחזרה לרשימה ריקה.
    test('שומר אירועי משתמש מהאחסון כאשר נקרא במקביל ל-_initializeCalendar',
        () async {
      final userEvent = _buildUserEvent();
      final storedJson = '[${_encodeEvent(userEvent)}]';

      // loadSettings עם עיכוב כדי להבטיח שה-_initializeCalendar יסיים ויעשה
      // emit רק לאחר שה-refreshPluginEvents כבר התחיל ותפס state ראשוני ריק.
      final settings = _SlowSettingsWithStoredEvents(eventsJson: storedJson);
      final cubit = CalendarCubit(
        settingsRepository: settings,
        notificationService: _FakeNotificationService(),
      );

      // קריאה מיידית — מדמה את הקריאה מ-postFrameCallback לפני שה-init הסתיים.
      unawaited(cubit.refreshPluginEvents());

      // המתן לסיום שניהם.
      await Future.delayed(const Duration(milliseconds: 200));

      expect(
        cubit.state.events.any((e) => e.id == userEvent.id),
        isTrue,
        reason:
            'אירוע המשתמש חייב להישמר גם כאשר refreshPluginEvents רץ במקביל',
      );

      cubit.close();
    });

    test(
        'רק הקריאה האחרונה עושה emit — קריאה ישנה מבוטלת ע"י generation counter',
        () async {
      final userEvent = _buildUserEvent();
      final storedJson = '[${_encodeEvent(userEvent)}]';

      // קריאה ראשונה: מחזירה pluginA אך מתעכבת — מאפשרת לקריאה השנייה להתחיל ולסיים לפניה.
      final pluginA = _buildUserEvent(id: 'plugin:event-stale');
      // קריאה שנייה: מחזירה pluginB מיידית.
      final pluginB = _buildUserEvent(id: 'plugin:event-fresh');

      final adapter = _SequencedPluginAdapter([
        Future.delayed(const Duration(milliseconds: 80), () => [pluginA]),
        Future.value([pluginB]),
      ]);

      final settings = _SlowSettingsWithStoredEvents(eventsJson: storedJson);
      final cubit = CalendarCubit(
        settingsRepository: settings,
        notificationService: _FakeNotificationService(),
        pluginCalendarAdapter: adapter,
      );

      // המתן לאתחול מלא.
      await Future.delayed(const Duration(milliseconds: 200));

      // קריאה 1 (ישנה) מתחילה — מקבלת generation=N, ומתעכבת 80ms.
      // קריאה 2 (חדשה) מתחילה — מכניסה generation=N+1 ומבטלת את הראשונה.
      unawaited(cubit.refreshPluginEvents());
      unawaited(cubit.refreshPluginEvents());

      await Future.delayed(const Duration(milliseconds: 200));

      final ids = cubit.state.events.map((e) => e.id).toSet();
      // התוצאה הישנה (pluginA) לא אמורה להופיע — הגנרציה ביטלה אותה.
      expect(ids.contains(pluginA.id), isFalse,
          reason: 'תוצאת הקריאה הישנה לא אמורה להופיע ב-state הסופי');
      // התוצאה החדשה (pluginB) חייבת להופיע.
      expect(ids.contains(pluginB.id), isTrue,
          reason: 'תוצאת הקריאה החדשה חייבת להופיע ב-state הסופי');

      cubit.close();
    });
  });

  group('setZmanEnabled — הפעלה/כיבוי זמנים', () {
    test('הפעלה וכיבוי מעדכנים את ה-state ושומרים ל-prefs', () async {
      final settings = _InMemorySettingsRepository();
      final cubit = CalendarCubit(
        settingsRepository: settings,
        notificationService: _FakeNotificationService(),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      await cubit.setZmanEnabled('tzais', false);
      expect(cubit.state.enabledZmanim.contains('tzais'), isFalse);
      expect(settings.calendarEnabledZmanim, isNot(contains('tzais')));

      await cubit.setZmanEnabled('tzais', true);
      expect(cubit.state.enabledZmanim.contains('tzais'), isTrue);
      expect(settings.calendarEnabledZmanim, contains('tzais'));

      await cubit.close();
    });
  });
}

String _encodeEvent(CustomEvent e) => jsonEncode(e.toJson());

CalendarState _buildCalendarState(DateTime selectedDate, {DateTime? today}) {
  final selectedJewishDate = JewishDate.fromDateTime(selectedDate);
  final todayDate = today ?? selectedDate;
  final todayJewishDate = JewishDate.fromDateTime(todayDate);

  return CalendarState(
    selectedJewishDate: selectedJewishDate,
    selectedGregorianDate: selectedDate,
    selectedCity: 'ירושלים',
    dailyTimes: const {},
    currentJewishDate: todayJewishDate,
    currentGregorianDate: todayDate,
    todayGregorianDate: todayDate,
    calendarType: CalendarType.combined,
    calendarView: CalendarView.month,
    dayTransition: CalendarDayTransition.sunset,
    inIsrael: true,
  );
}
