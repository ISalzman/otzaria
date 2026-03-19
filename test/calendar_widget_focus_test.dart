import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:otzaria/tools/calendar/services/google_calendar_service.dart';
import 'package:otzaria/tools/calendar/services/notification_service.dart';
import 'package:otzaria/tools/calendar/ulits/calendar_cubit.dart';
import 'package:otzaria/tools/calendar/ulits/calendar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
    await Settings.init();
  });

  group('CalendarWidget focus refresh', () {
    late CalendarCubit calendarCubit;
    late FocusNode outsideFocusNode;

    setUp(() {
      calendarCubit = CalendarCubit(
        notificationService: _FakeNotificationService(),
        googleCalendarService: _FakeGoogleCalendarService(),
      );
      outsideFocusNode = FocusNode(debugLabel: 'outside-focus');
    });

    tearDown(() {
      outsideFocusNode.dispose();
      calendarCubit.close();
    });

    testWidgets('arrow navigation resumes after requesting focus again',
        (tester) async {
      final calendarKey = GlobalKey<CalendarWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: calendarCubit,
              child: Column(
                children: [
                  Expanded(
                    child: CalendarWidget(key: calendarKey),
                  ),
                  Focus(
                    focusNode: outsideFocusNode,
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialDate = calendarCubit.state.selectedGregorianDate;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      final dateAfterFirstArrow = calendarCubit.state.selectedGregorianDate;
      expect(dateAfterFirstArrow, isNot(initialDate));

      outsideFocusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      final dateWithoutCalendarFocus = calendarCubit.state.selectedGregorianDate;
      expect(dateWithoutCalendarFocus, dateAfterFirstArrow);

      calendarKey.currentState!.requestKeyboardFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      final dateAfterRefocus = calendarCubit.state.selectedGregorianDate;
      expect(dateAfterRefocus, isNot(dateWithoutCalendarFocus));
    });
  });
}

class _FakeNotificationService implements NotificationService {
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get hasPermissions => true;

  @override
  Future<void> init() async {
    _initialized = true;
  }

  @override
  Future<bool> checkPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> forceRequestPermissions() async => true;

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime eventDate,
    required int reminderMinutes,
    bool soundEnabled = true,
  }) async {}

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeGoogleCalendarService extends GoogleCalendarService {
  @override
  Future<bool> isSignedIn() async => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<GoogleCalendarApiClient?> getApiClient({
    bool interactive = false,
  }) async => null;
}