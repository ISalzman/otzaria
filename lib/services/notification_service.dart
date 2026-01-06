import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _permissionsGranted = false;
  bool _isInitialized = false;

  Future<void> init() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    // Set default timezone to Israel
    tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'אוצריא',
      appUserModelId: 'com.otzaria.app',
      guid: 'a8c49f1f-9c5d-4d8e-8b1a-2e3f4a5b6c7d',
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            macOS: initializationSettingsIOS,
            linux: initializationSettingsLinux,
            windows: initializationSettingsWindows);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

    _isInitialized = true;

    // Request permissions
    await requestPermissions();
  }

  bool get isInitialized => _isInitialized;

  /// Request notification permissions (Android 13+ and iOS)
  ///
  /// This function handles the Android permission request issue where requesting
  /// both notification and exact alarm permissions simultaneously could cause
  /// the permission dialog to freeze. The fix includes:
  /// 1. Checking existing permissions before requesting
  /// 2. Adding delay between permission requests
  /// 3. Better error handling for each permission type
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        try {
          bool notificationGranted = true;
          bool exactAlarmGranted = true;

          // First, check if we can schedule exact notifications (this checks the permission)
          final canScheduleExact =
              await androidPlugin.canScheduleExactNotifications();
          if (kDebugMode) {
            debugPrint('Can schedule exact notifications: $canScheduleExact');
          }

          // Request notification permission for Android 13+ only if needed
          try {
            final notificationResult =
                await androidPlugin.requestNotificationsPermission();
            notificationGranted = notificationResult ?? true;

            if (kDebugMode) {
              debugPrint('Notification permission: $notificationGranted');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error requesting notification permission: $e');
            }
            notificationGranted = false;
          }

          // Add a small delay between permission requests to avoid conflicts
          await Future.delayed(const Duration(milliseconds: 500));

          // Request exact alarm permission for Android 12+ only if not already granted
          if (canScheduleExact != true) {
            try {
              final exactAlarmResult =
                  await androidPlugin.requestExactAlarmsPermission();
              exactAlarmGranted = exactAlarmResult ?? true;

              if (kDebugMode) {
                debugPrint('Exact alarm permission: $exactAlarmGranted');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error requesting exact alarm permission: $e');
              }
              exactAlarmGranted = false;
            }
          } else {
            exactAlarmGranted = true;
            if (kDebugMode) {
              debugPrint('Exact alarm permission already granted');
            }
          }

          _permissionsGranted = notificationGranted && exactAlarmGranted;

          if (kDebugMode) {
            debugPrint('All permissions granted: $_permissionsGranted');
          }

          return _permissionsGranted;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error requesting Android permissions: $e');
          }
          _permissionsGranted = false;
          return false;
        }
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      _permissionsGranted = granted ?? false;
      return _permissionsGranted;
    }

    // Windows and Linux don't require permissions
    _permissionsGranted = true;
    return true;
  }

  bool get hasPermissions => _permissionsGranted;

  /// Check current permission status without requesting
  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        try {
          // Check if exact alarm permission is granted
          final exactAlarmGranted =
              await androidPlugin.canScheduleExactNotifications();

          // For notification permission, we assume it's granted if we can check it
          // (there's no direct way to check notification permission status without requesting)

          _permissionsGranted = exactAlarmGranted ?? false;

          if (kDebugMode) {
            debugPrint(
                'Permission check - Can schedule exact: $exactAlarmGranted');
            debugPrint('Permissions granted: $_permissionsGranted');
          }

          return _permissionsGranted;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error checking Android permissions: $e');
          }
          return false;
        }
      }
    }

    return _permissionsGranted;
  }

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    // Handle notification tapped logic here
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime eventDate,
    required int reminderMinutes,
    bool soundEnabled = true,
  }) async {
    // Check if initialized before scheduling
    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint('Cannot schedule notification: service not initialized');
      }
      return;
    }

    // Check permissions before scheduling
    if (!_permissionsGranted) {
      if (kDebugMode) {
        debugPrint('Cannot schedule notification: permissions not granted');
      }
      return;
    }

    final scheduleTime = eventDate.subtract(Duration(minutes: reminderMinutes));

    // Ensure the notification is scheduled for the future
    if (scheduleTime.isBefore(DateTime.now())) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'calendar_channel',
      'התראות לוח שנה',
      channelDescription: 'התראות על אירועים בלוח השנה',
      importance: Importance.max,
      priority: Priority.high,
      playSound: soundEnabled,
      icon: '@mipmap/ic_launcher',
    );

    final iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundEnabled,
    );

    const windowsDetails = WindowsNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      macOS: iOSDetails,
      linux: const LinuxNotificationDetails(),
      windows: windowsDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduleTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    if (!_isInitialized) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to cancel notification $id: $e');
      }
    }
  }

  /// Test function to verify notifications are working
  /// This sends a test notification to verify system notifications work
  Future<void> sendTestNotification() async {
    if (!_isInitialized || !_permissionsGranted) {
      if (kDebugMode) {
        debugPrint(
            'Cannot send test notification: not initialized or no permissions');
      }
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'התראות בדיקה',
      channelDescription: 'התראות לבדיקת המערכת',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const windowsDetails = WindowsNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      macOS: iOSDetails,
      linux: LinuxNotificationDetails(),
      windows: windowsDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        999, // Test notification ID
        'בדיקת התראות',
        'התראה זו מוצגת במערכת ההפעלה, לא בתוך האפליקציה',
        notificationDetails,
      );

      if (kDebugMode) {
        debugPrint('Test notification sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to send test notification: $e');
      }
    }
  }
}
