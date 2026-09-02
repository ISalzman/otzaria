/// This is the main entry point for the Otzaria application.
///
/// The application is a Flutter-based digital library system that supports
/// RTL (Right-to-Left) languages, particularly Hebrew.
/// It includes features for dark mode, customizable themes, and local storage management.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show FrameCallback;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/app.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_bloc.dart';
import 'package:otzaria/bookmarks/repository/bookmark_repository.dart';
import 'package:otzaria/find_ref/bloc/find_ref_bloc.dart';
import 'package:otzaria/find_ref/repository/find_ref_factory.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/history_repository.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/services/release_index_builder_cli.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/settings/services/custom_folders/bloc/custom_folders_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/navigation/navigation_repository.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/tabs_repository.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';
import 'package:otzaria/workspaces/bloc/workspace_event.dart';
import 'package:otzaria/workspaces/workspace_repository.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:otzaria/app_bloc_observer.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/cache_database_holder.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/empty_library/bloc/empty_library_bloc.dart';
import 'package:otzaria/library_update/bloc/library_update_bloc.dart';
import 'package:otzaria/library_update/repository/library_update_repository.dart';
import 'package:otzaria/library_update/services/companion_assets_service.dart';
import 'package:otzaria/library_update/services/startup_recovery_check.dart';
import 'package:seforim_library_updater/seforim_library_updater.dart';
import 'package:zstandard/zstandard.dart';
import 'package:otzaria/work_status/work_status_cubit.dart';
import 'package:otzaria/printing/export_restriction_service.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_updates_cubit.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/declarative/services/declarative_library_book_access.dart';
import 'package:otzaria/plugins/services/plugin_reader_actions.dart';
import 'package:otzaria/plugins/declarative/services/declarative_plugin_host_service.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';

import 'package:otzaria_search_engine/otzaria_search_engine.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/core/data_root_writability_warning.dart';
import 'package:otzaria/core/cli_command.dart';
import 'package:otzaria/core/error_log_file.dart';
import 'package:otzaria/core/update_check_frequency.dart';
import 'package:otzaria/core/info/app_info_cli.dart';
import 'package:otzaria/core/info/app_install_timeline.dart';
import 'package:otzaria/core/external_activation_queue.dart';
import 'package:otzaria/core/portable_paths.dart';
import 'package:otzaria/core/window_listener.dart';
import 'package:otzaria/core/window_persistence.dart';
import 'package:otzaria/core/windowing/app_window_scope.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/core/windowing/window_bus_host.dart';
import 'package:otzaria/core/windowing/window_role.dart';
import 'package:otzaria/core/windowing/window_manager_app_window_controller.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_data_provider.dart';
import 'package:otzaria/tools/shamor_zachor/providers/shamor_zachor_progress_provider.dart';
import 'package:otzaria/settings/services/backup_service.dart';
import 'package:otzaria/core/http_client_registry.dart';
import 'package:otzaria/plugins/services/plugin_report_service.dart';
import 'package:otzaria/services/direct_error_report_service.dart';
import 'package:otzaria/data/cache/books_cache.dart';
import 'package:otzaria/data/cache/acronyms_cache.dart';
import 'package:otzaria/data/cache/generation_cache.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';
import 'package:otzaria/tools/dictionary/repository/dictionary_lookup_repository.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:otzaria/tools/calendar/services/notification_service.dart';
import 'package:otzaria/plugins/database/plugin_database_bootstrap.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:otzaria/theme/app_fonts.dart';
import 'package:otzaria/widgets/misc/app_cursors.dart';
import 'package:otzaria/widgets/misc/restart_widget.dart';
import 'package:otzaria/core/splash_screen.dart';
import 'package:otzaria/plugins/services/plugin_crash_guard.dart';
import 'package:otzaria/plugins/services/plugin_background_policy.dart';
import 'package:otzaria/plugins/services/plugin_install_report_service.dart';
import 'package:otzaria/plugins/services/plugin_packager_cli.dart';
import 'package:otzaria/plugins/services/plugin_store_link_parser.dart';
import 'package:otzaria/plugins/services/plugin_protocol_registration_service.dart';
import 'package:otzaria/plugins/utils/plugin_dev_tools_mode.dart';
import 'package:otzaria/plugins/view/webview_environment_holder.dart';
import 'package:otzaria/core/sentry_event_filter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Updated automatically by version update scripts - do not edit manually
const int _latestReleasedBuildNumber = 90960;

// Global reference to window listener for cleanup
/// החלון היחיד של התהליך. מקור אמת אחד לכל מי שצריך אותו כאן: ה-listener,
/// [WindowPersistence] ו-[AppWindowScope] מקבלים את אותו מופע.
const _appWindow = WindowManagerAppWindowController();

AppWindowListener? _appWindowListener;
const ExternalActivationQueue _externalActivationQueue =
    ExternalActivationQueue();

// מושלם כשהחלון הראשי נחשף ([presentMainWindow]). חימומי המטמון ממתינים לו
// כדי שלא יתחרו בטעינת תוכן הספר הפעיל על ה-main isolate ועל seforim.db.
final _mainWindowRevealedCompleter = Completer<void>();

void _markMainWindowRevealed() {
  if (!_mainWindowRevealedCompleter.isCompleted) {
    _mainWindowRevealedCompleter.complete();
  }
}

/// Getter for accessing the window listener from other parts of the app
AppWindowListener? get appWindowListener => _appWindowListener;

void _appendUnhandledErrorToLocalLog({
  required String title,
  required Object error,
  StackTrace? stackTrace,
  Map<String, String?> details = const {},
}) {
  try {
    ErrorLogFile.append(
      title: title,
      error: error,
      stackTrace: stackTrace,
      details: details,
    );
  } catch (writeError, writeStackTrace) {
    final formattedMessage = ErrorLogFile.formatEntry(
      title: title,
      error: error,
      stackTrace: stackTrace,
      details: details,
    );
    stderr.writeln(
      'Failed to write error log to ${ErrorLogFile.resolvePath()}: $writeError',
    );
    stderr.writeln(writeStackTrace);
    stderr.writeln(formattedMessage);
  }
}

Map<String, String?> _flutterErrorDetailsForLog(FlutterErrorDetails details) {
  final informationCollector = details.informationCollector;
  final collectedInformation = informationCollector == null
      ? null
      : informationCollector()
            .map((node) => node.toDescription())
            .where((description) => description.trim().isNotEmpty)
            .join('\n');

  return {
    'Library': details.library,
    'Context': details.context?.toString(),
    'Information': collectedInformation,
  };
}

String _formatAppVersion(PackageInfo packageInfo) {
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();

  if (version.isEmpty) {
    return buildNumber.isEmpty ? 'unknown' : buildNumber;
  }

  if (buildNumber.isEmpty || version.endsWith('+$buildNumber')) {
    return version;
  }

  return '$version+$buildNumber';
}

Future<void> _initializeDataRootForEarlyLogging() async {
  try {
    await AppPaths.getDataRootPath();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Failed to resolve app data root early: $error\n$stackTrace');
    }
  }
}

const String _kLastSeenVersion = 'last_seen_app_version';

void _clearErrorLogOnVersionChange() {
  final currentVersion = ErrorLogFile.appVersion;
  final lastSeen = Settings.getValue<String>(_kLastSeenVersion);
  if (lastSeen != null && lastSeen != currentVersion) {
    try {
      final logFile = ErrorLogFile.resolveFile();
      if (logFile.existsSync()) {
        logFile.deleteSync();
      }
    } catch (error) {
      // ניקוי לא-קריטי: הלוג הישן יישאר, אבל שלא בשקט מוחלט.
      if (kDebugMode) {
        debugPrint('Failed to clear old error log: $error');
      }
    }
  }
  Settings.setValue(_kLastSeenVersion, currentVersion);
}

Future<void> _initializeLogMetadata() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    ErrorLogFile.setAppVersion(_formatAppVersion(packageInfo));
  } catch (error, stackTrace) {
    ErrorLogFile.setAppVersion('unknown');
    if (kDebugMode) {
      debugPrint('Failed to load app version for logs: $error\n$stackTrace');
    }
  }
}

void _logNonFatalInitializationError(
  String component,
  Object error,
  StackTrace stackTrace,
) {
  if (kDebugMode) {
    debugPrint(
      'Non-fatal initialization error in $component: $error\n$stackTrace',
    );
    return;
  }

  _appendUnhandledErrorToLocalLog(
    title: 'Initialization Warning',
    error: error,
    stackTrace: stackTrace,
    details: {
      'Phase': 'initialize',
      'Component': component,
    },
  );
}

bool _isIgnorableHardwareKeyboardAssertion(String errorString) {
  return errorString.contains('!_pressedKeys.containsKey(event.physicalKey)') ||
      errorString.contains(
        'A KeyDownEvent is dispatched, but the state shows that the physical key is already pressed',
      ) ||
      errorString.contains(
        'A KeyUpEvent is dispatched, but the state shows that the physical key is not pressed',
      );
}

/// Application entry point that initializes necessary components and launches the app.
///
/// This function performs the following initialization steps:
/// 1. Sets up custom error handlers
/// 2. Initializes Sentry for error tracking
/// 3. Ensures Flutter bindings are initialized
/// 4. Calls [initialize] to set up required services and configurations
/// 5. Launches the main application widget
void main(List<String> args) async {
  // debugPrint פזור במאות נקודות קריאה בלי עטיפת kDebugMode; ב-release הפלט
  // עדיין מפורמט ונשלח ל-stdout שאיש לא רואה — מנוטרל כאן במרוכז לכל התוכנה.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // טיפול בפקודות CLI שאינן דורשות אתחול GUI (כגון אריזת תוסף).
  // חייב לרוץ לפני SentryWidgetsFlutterBinding.ensureInitialized() כדי שלא
  // ייפתח חלון Flutter ולא יתבצע אתחול מסד נתונים מיותר.
  if (await _maybeRunCliCommand(args)) {
    return;
  }

  PluginDevToolsMode.initFromArgs(args);

  SentryWidgetsFlutterBinding.ensureInitialized();

  // אישור קבלה מוקדם לאתר החנות עבור קישורי התקנת תוסף שהגיעו כארגומנטים —
  // נורה כאן, לפני כל אתחול כבד ולפני עליית החלון, כדי שדף החנות יידע תוך
  // שנייה-שתיים שאוצריא קיבלה את הבקשה (גם בעלייה קרה). במופע משני (כשאוצריא
  // כבר רצה) ההמתנה לסיום נעשית לפני exit ב-_runAppBootstrap.
  _sendEarlyInstallAcks(args);

  // מנטרל את ההבהוב המובנה (הפרטי ב-EditableTextState) כדי ש-RtlTextField
  // ינהל אותו בעצמו. ראו "ניהול הבהוב הסמן" ב-rtl_text_field.dart.
  EditableText.debugDeterministicCursor = true;

  unawaited(AppCursors.ensureInitialized());

  await _initializeDataRootForEarlyLogging();
  await _initializeLogMetadata();
  hierarchicalLoggingEnabled = true;
  await _enqueueExternalActivationArgs(args);

  // Set up custom error handlers before Sentry initialization
  // Sentry will automatically wrap these handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorString = details.exceptionAsString();

    // Flutter's desktop accessibility bridge can report stale AXTree nodes.
    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
        isFlutterAccessibilityNoise(errorString)) {
      return; // Silently ignore these errors
    }

    // Skip HardwareKeyboard assertion error - happens when window loses focus while
    // a key is held down; onWindowFocus releases stuck keys but filter as fallback
    if (_isIgnorableHardwareKeyboardAssertion(errorString)) {
      return; // Silently ignore - stuck keys are released on window focus
    }

    // Log all other errors normally
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    } else {
      _appendUnhandledErrorToLocalLog(
        title: 'FlutterError',
        error: details.exceptionAsString(),
        stackTrace: details.stack,
        details: _flutterErrorDetailsForLog(details),
      );
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final errorString = error.toString();

    // Flutter's desktop accessibility bridge can report stale AXTree nodes.
    if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
        isFlutterAccessibilityNoise(errorString)) {
      return true; // Silently ignore these errors
    }

    // Skip HardwareKeyboard assertion error - stuck keys are released on window focus
    if (_isIgnorableHardwareKeyboardAssertion(errorString)) {
      return true; // Silently ignore
    }

    // Log all other errors normally
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
        ),
      );
    } else {
      _appendUnhandledErrorToLocalLog(
        title: 'Unhandled Error',
        error: error,
        stackTrace: stack,
      );
    }
    return true;
  };

  if (!kDebugMode) {
    try {
      ErrorLogFile.ensureExists();
    } catch (error, stackTrace) {
      stderr.writeln(
        'Failed to prepare error log file at ${ErrorLogFile.resolvePath()}: $error',
      );
      stderr.writeln(stackTrace);
    }
  }

  // Start Sentry in parallel to avoid blocking app startup.
  unawaited(_initializeSentry());

  await _runAppBootstrap();
}

Future<void> _initializeSentry() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber.trim()) ?? 0;

    await SentryFlutter.init(
      (options) {
        // Use environment variable for DSN, with fallback to default
        options.dsn = const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue:
              'https://79d3003f822fa62bce0c928656308121@o4510914530902016.ingest.us.sentry.io/4510914532868096',
        );
        options.release = '${info.appName}@${info.version}+${info.buildNumber}';
        // Privacy: Do not collect IP addresses and request headers
        options.sendDefaultPii = false;
        // Sentry משמש לדיווח שגיאות בלבד; עסקאות ביצועים אינן נשלחות.
        options.tracesSampleRate = 0.0;

        options.beforeSend = (event, hint) {
          return shouldReportSentryEvent(
                event: event,
                currentBuild: currentBuild,
                latestReleasedBuildNumber: _latestReleasedBuildNumber,
              )
              ? event
              : null;
        };
      },
    );
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Sentry initialization failed: $error\n$stackTrace');
    }
  }
}

Future<void> _runAppBootstrap() async {
  // Check for single instance - skip on Apple platforms (macOS/iOS) due to sandbox restrictions
  if (!Platform.isMacOS && !Platform.isIOS) {
    // שם התהליך משמש רק לשם קובץ ה-pid. בלעדיו החבילה מריצה tasklist/ps
    // באופן חוסם לפני runApp — במחשב שסוכן סינון מאט בו יצירת תהליכים זה
    // עיכב את העלייה בעשרות שניות (issue #989). חייב לגזור אותו כמו החבילה
    // (שם ה-EXE בלי סיומת), אחרת מופע ישן וחדש לא יזהו זה את זה.
    FlutterSingleInstance.processName ??= Platform.resolvedExecutable
        .split(Platform.pathSeparator)
        .last
        .replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');
    FlutterSingleInstance flutterSingleInstance = FlutterSingleInstance();
    bool isFirstInstance = await flutterSingleInstance.isFirstInstance();
    if (!isFirstInstance) {
      // אם נשלח ack מוקדם לאתר החנות — ממתינים לסיומו לפני היציאה, אחרת
      // התהליך מת לפני שהבקשה יוצאת (לשירות יש timeout פנימי של 10 שניות).
      final ackFuture = _earlyInstallAckFuture;
      if (ackFuture != null) {
        try {
          await ackFuture;
        } catch (_) {}
      }
      exit(0);
    }
  }

  Bloc.observer = AppBlocObserver();

  if (kDebugMode) {
    Logger.root.level = Level.ALL;
    Logger('fwfh').level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '${record.level.name}: ${record.loggerName}: ${record.message}',
      );
    });
  }

  // הגדרת window_manager לפני runApp.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    // נשאר על ה-singleton: אתחול ה-backend קודם לקיומו של כל חלון.
    await windowManager.ensureInitialized();
    WindowPersistence.splashMode = true;
    // WindowPersistence היא static ואין לה BuildContext — היא מקבלת את
    // אותו מופע שנכנס ל-AppWindowScope, כדי שיהיה מקור אמת אחד.
    WindowPersistence.bindWindow(
      controller: _appWindow,
      geometry: _appWindow,
    );

    _appWindowListener = AppWindowListener(window: _appWindow);
    // TODO(T-1.3): רישום listener ו-setPreventClose הם מצב פר-חלון שמנוהל
    // ב-AppWindowRegistry, שטרם קיים.
    windowManager.addListener(_appWindowListener!);
    await windowManager.setPreventClose(true);

    // ה-splash נייטיבי ב-runner והחלון הראשי נשאר מוסתר עד presentMainWindow,
    // שם הוא נחשף ישר בגבולותיו הסופיים — לכן אין כאן waitUntilReadyToShow.
  }

  // ה-scope עוטף את כל העץ כדי שכל widget יוכל להגיע לחלון שהוא יושב בו
  // בלי לפנות ל-singleton גלובלי. היום יש חלון אחד, ולכן הבקר הוא של
  // החלון הראשי; ריבוי חלונות יזריק כאן בקר אחר לכל עץ.
  _maybeScheduleDebugSecondWindow();

  runApp(
    AppWindowScope(
      controller: _appWindow,
      geometry: _appWindow,
      child: SentryWidget(
        child: RestartWidget(
          child: const AppBootstrap(),
        ),
      ),
    ),
  );
}

/// ערוץ לסגירת חלון ה-splash הנייטיב (ראה windows/linux/macos runner). נתמך בכל
/// פלטפורמות הדסקטופ.
const MethodChannel _splashChannel = MethodChannel('otzaria/splash');

Future<void> _closeNativeSplash() async {
  if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }
  try {
    await _splashChannel.invokeMethod<void>('close');
  } catch (_) {
    // לא קריטי — חלון ה-splash ייהרס ממילא עם התהליך.
  }
}

/// חשיפת החלון הראשי: מציג את החלון המוסתר (שכבר בגבולותיו הסופיים, עם
/// התוכן שצויר), ממקסם אם נדרש, וסוגר את ה-splash הנייטיב באותו רגע — כך החלון
/// מופיע בבת אחת עם תוכן והסמל הצף מתפוגג, ללא קפיצה וללא פער. נקרא אחרי שהתוכן
/// נחשף ונצבע.
Future<void> presentMainWindow() async {
  if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    _markMainWindowRevealed();
    return;
  }
  try {
    // show/maximize זורקים את ה-swapchain (חלון שקוף עד פריים חדש) — תחת cloak
    // זה בלתי-נראה; החשיפה היא ביטול ה-cloak הנייטיבי ב-flutter_window.cpp.
    if (!kIsWeb && Platform.isWindows && !await _appWindow.isVisible()) {
      try {
        await _splashChannel.invokeMethod<void>('cloak');
      } catch (_) {
        // לא קריטי — בלי cloak נשארת ההתנהגות הקודמת (חשיפה לא-אטומית).
      }
    }
    await _appWindow.show();
    await _appWindow.focus();
    // ⚠️ חלון משני נוצר מוסתר, ו-`show()` על חלון מוסתר אינו מפעיל אותו:
    // הוא נחשף **מאחורי** החלון שפתח אותו, וזה נראה כאילו החלון הראשון
    // "תמיד עליון". `focus()` לבדו לא הספיק, ולכן העלאה מפורשת בנייטיב.
    if (isSecondaryWindow) {
      await const MultiWindowService().raiseSelf();
      final startup = _secondaryWindowStartup;
      if (startup != null && startup.isRunning) {
        startup.stop();
        // נמדד ולא משוער: כל צעד שמדולג בחלון משני צריך להיראות כאן.
        debugPrint(
          '[window] חלון משני עלה תוך ${startup.elapsedMilliseconds}ms',
        );
      }
    }
    // maximize חייב לקרות *אחרי* show (show מבצע restore לגודל הקודם).
    await WindowPersistence.applyPendingMaximize();
    // חייב אחרי show (setFullScreen על חלון מוסתר מאבד WS_VISIBLE) ואחרי
    // maximize (כדי שיציאה ממסך מלא תחזיר את החלון למצבו הממוקסם).
    await WindowPersistence.applyPendingFullscreen();
    // מכאן והלאה מותר לשמור את גודל החלון.
    WindowPersistence.splashMode = false;
  } catch (error, stackTrace) {
    _logNonFatalInitializationError('Present main window', error, stackTrace);
  } finally {
    // הסגירה מבצעת בצד הנייטיבי את ה-uncloak; חייבת לרוץ גם אם שלב הצגה
    // נכשל — אחרת החלון נשאר cloaked (בלתי-נראה) לתמיד.
    await _closeNativeSplash();
    // משחרר את חימומי המטמון הדחויים גם אם אחת מפעולות החלון נכשלה.
    _markMainWindowRevealed();
  }
}

/// אתחול כבד שרץ בזמן שה-splash מוצג.
Future<void> _initializeProcessSingletons() async {
  // שרשרת ההגדרות/חלון חייבת להישאר סדרתית: WindowPersistence קורא את גבולות
  // החלון השמורים מ-Settings.
  Future<void> initSettingsAndWindow() async {
    try {
      await Settings.init(cacheProvider: HiveCache());
    } catch (error, stackTrace) {
      // ה-fallback משנה את מקור ההגדרות; קוד אחר (גיבוי, טיוטות) ניגש
      // ישירות ל-Hive box ויקבל ריק — חובה שהכשל יהיה גלוי בלוג.
      _logNonFatalInitializationError(
        'Settings.init with HiveCache',
        error,
        stackTrace,
      );
      await Settings.init(cacheProvider: SharePreferenceCache());
    }

    // ⚠️ פר-תהליך, לא פר-חלון. ניקוי יומן השגיאות בשינוי גרסה ורישום
    // ההפעלה מתארים את **התהליך**; חלון נוסף שרושם "הפעלה" מזייף את
    // הנתונים, וניקוי היומן פעם שנייה עלול למחוק שגיאות שנרשמו בינתיים.
    if (!isSecondaryWindow) {
      _clearErrorLogOnVersionChange();
      await AppInstallTimelineStore.recordLaunch(ErrorLogFile.appVersion);
    }

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // ⚠️ חלון משני אינו משחזר גבולות שמורים.
      //
      // הגבולות השמורים הם של החלון הראשי, ובדרך כלל ממוקסמים — ולכן כל
      // חלון נוסף נפתח על מסך מלא ובאותו מקום בדיוק, ומכסה את הקודם.
      // ה-runner כבר יצר אותו בגודל ובהיסט סבירים, וזה מה שצריך להישאר.
      if (!isSecondaryWindow) {
        await WindowPersistence.restoreIfAny();
      }
      // מחילים את הגבולות הסופיים כאן — מוקדם, בזמן שה-splash הנייטיב מוצג
      // והחלון הראשי עדיין מוסתר — ולא ברגע החשיפה. החלון נוצר ב-(10,10) על
      // המסך הראשי; אם הגבולות השמורים נמצאים על מסך עם DPI שונה, ה-setBounds
      // משגר WM_DPICHANGED. בכך שמחילים אותו כאן (ולא frame אחד לפני show),
      // המנוע מספיק לעבד את שינוי ה-DPI ולצייר מחדש ב-devicePixelRatio הנכון
      // הרבה לפני שהחלון נחשף — מונע מצב שבו כל הממשק מופיע "מוגדל" כי הוצג
      // לפני שה-DPR התעדכן.
      if (!isSecondaryWindow) {
        await WindowPersistence.applyRestoredBounds();
      }
      // גם מסגרת החלון מוגדרת כאן — מוקדם, בעוד החלון מוסתר — ולא ברגע
      // החשיפה: הסתרת ה-title bar (החלון נוצר ב-runner עם WS_OVERLAPPEDWINDOW)
      // משנה את גודל אזור-הלקוח, מה שמאתחל את ה-swapchain של המנוע וזורק את
      // כל התוכן שכבר צויר. כשזה רץ ברגע החשיפה, show() הציג חלון ריק לשבריר
      // שנייה עד שפריים חדש הספיק להתרסטר. כאן השינוי קורה לפני שפריים התוכן
      // הראשון מצויר בכלל — והוא נצבע ישר במסגרת ובגודל הסופיים.
      await _appWindow.setMinimumSize(WindowPersistence.minSize);
      // windowButtonVisibility ברירת מחדל true — חובה false מפורש כדי להסתיר
      // את כפתורי המערכת של macOS (traffic lights) שאחרת יופיעו כפול לצד
      // הכפתורים המותאמים.
      await _appWindow.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
    }
  }

  // RustLib (טעינת FFI) ו-loadCerts (קריאת asset קטן) אינם תלויים בהגדרות
  // ולא זה בזה — רצים במקביל לשרשרת ההגדרות/חלון במקום בזה אחר זה.
  await _timedPhase('rustlib+certs+settings', () async {
    await Future.wait([
      RustLib.init(),
      loadCerts(),
      initSettingsAndWindow(),
    ]);
  });

  await _timedPhase('initHive', initHive);
  // מצב נייד: אם תיקיית הנתונים זזה (אות כונן אחרת / מיקום אחר), הנתיבים
  // האבסולוטיים השמורים משוכתבים לפני שכל קוד אחר צורך אותם. חייב לרוץ
  // אחרי Settings.init ואחרי initHive (ה-boxes פתוחים), ולפני
  // SqliteDataProvider ו-FileSystemData שקוראים את נתיב הספרייה.
  // ⚠️ פר-תהליך. המיגרציה משכתבת נתיבים אבסולוטיים בהגדרות המשותפות;
  // החלון הראשון כבר ביצע אותה, וחלון משני שיריץ אותה שוב יעבוד על
  // ה-Hive הפרטי שלו ולא על המשותף — כלומר בזבוז במקרה הטוב.
  if (!isSecondaryWindow) {
    await PortablePaths.migrateIfMoved();
  }

  // נתיב הספרייה נרשם לקובץ טקסט שה-uninstaller קורא; ההגדרות עצמן
  // ב-Hive בינארי שאינו נגיש לו (issue #1020).
  unawaited(AppPaths.recordLibraryPathForUninstaller());

  // שירות ההתראות (לוח השנה) ושירות דיווחי השגיאות אינם חיוניים להצגת
  // המסך הראשי. tz.initializeTimeZones + plugin init של flutter_local_notifications
  // יכולים לקחת מאות מילי-שניות ב-Windows, ודיווחי השגיאות הם רק Timer.periodic.
  // ⚠️ פר-תהליך, לא פר-חלון. שירות ההתראות רושם התראות מערכת, ושטיפת
  // דיווחי השגיאות שולחת את אותו תור — חלון משני שמריץ אותם שוב מייצר
  // התראות כפולות ודיווחים כפולים.
  if (!isSecondaryWindow) {
    unawaited(_runDeferredNotificationService());
    unawaited(_runDeferredErrorReportFlush());
  }
}

/// משחזר עדכון ספרייה שנקטע (marker+backup) לפני פתיחת ה-DB.
Future<void> _recoverInterruptedLibraryUpdate() {
  return StartupRecoveryCheck(
    readPref: Settings.getValue<String>,
    writePref: (key, value) => Settings.setValue(key, value),
    logError: (title, message) => _appendUnhandledErrorToLocalLog(
      title: title,
      error: message,
      details: const {'Phase': 'initialize', 'Component': 'Library recovery'},
    ),
  ).run(DatabaseConstants.getDatabasePath());
}

/// seforim.db שהוזז לגיבוי זמני בעדכון ספרייה שנהרג באמצע חוזר לספרייה —
/// אחרת היא נראית ריקה והמשתמש מוריד הכול מחדש, על גבי הגיבוי שנשאר.
Future<void> _recoverOrphanedDbBackup() async {
  final libraryPath = Settings.getValue<String>(
    SettingsRepository.keyLibraryPath,
  );
  if (libraryPath == null || libraryPath.isEmpty) return;
  try {
    await EmptyLibraryBloc.recoverOrphanedDbBackup(
      DatabaseConstants.getDatabaseDirectoryPath(),
    );
  } catch (error, stackTrace) {
    _logNonFatalInitializationError(
      'Orphaned DB backup recovery',
      error,
      stackTrace,
    );
  }
}

Future<void> _initializeRestartableRuntime() async {
  // השחזורים נוגעים בקובצי הספרייה המשותפים, ולכן רצים רק בחלון הראשי.
  if (!isSecondaryWindow) {
    await _recoverInterruptedLibraryUpdate();
    await _recoverOrphanedDbBackup();
  }

  // initHive נקרא כבר ב-_initializeProcessSingletons. הקריאה הכפולה כאן
  // הייתה no-op (Hive.openBox מחזיר box קיים), אבל בכל זאת חוסכת קצת זמן
  // בקריאה הראשונה. ב-restart אין צורך לפתוח שוב — boxes לא נסגרים.
  await _timedPhase('sqlite', SqliteDataProvider.instance.initialize);

  // הגדרת cache של pdfrx — לא חיונית להצגת המסך הראשי. PDF הראשון יקבל
  // cache ברירת מחדל אם זה עוד לא הוגדר.
  unawaited(_runDeferredPdfrxCacheInit());

  // initPluginDatabaseSources היא רישום סינכרוני קצר (in-memory only) של
  // המקורות שהאפליקציה מציעה לתוספים. חייב לרוץ לפני שתוסף יקרא ל-
  // database.listSources — אחרת תוסף שנפתח מוקדם יראה את כל המקורות
  // כלא-זמינים (regression: ראה PluginDatabaseService._registry.getSource).
  await _timedPhase('pluginDbSources', initPluginDatabaseSources);

  // PluginCrashGuard.ensureInitialized חייב להסתיים לפני שטעינת תוסף מתחילה.
  // PluginTabPage.markLoadAttemptSync דורש state אתחל (אחרת ה-canary לא נשמר
  // והתוסף לא ייכנס ל-quarantine אם יקרוס), ו-PluginCrashGuard.isBlocked
  // מחזיר false כל עוד _blocked הוא null. הקריאה זולה (קריאת JSON קטן).
  await PluginCrashGuard.ensureInitialized().catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _logNonFatalInitializationError(
      'Plugin crash guard initialization',
      error,
      stackTrace,
    );
  });

  // גיבוי אוטומטי ורישום פרוטוקול אינם נחוצים להצגת ה-UI הראשי (טאבים,
  // ספרים, ניווט). הם מועברים ל-unawaited כדי שלא יעכבו את ה-bootstrap —
  // אחרת ב-Windows רישום הפרוטוקול לבדו מריץ 10 תת-תהליכי reg.exe סדרתית,
  // מה שמוסיף כמה שניות עד שהטאבים השמורים נטענים. ראה
  // _runDeferredAutoBackup ו-_runDeferredProtocolRegistration למטה.
  unawaited(_runDeferredAutoBackup());
  unawaited(_runDeferredProtocolRegistration());
  unawaited(_logJobObjectContainmentFailure());
  unawaited(_runDeferredDataRootWritabilityWarning());

  // מסלול התאימות הישן זקוק ל-WebView מיד; החימום רץ ברקע ואינו מעכב bootstrap.
  unawaited(_preWarmWebViewEnvironment());
}

/// כשקונטיינמנט ה-Job Object לא הוקם, תהליכי msedgewebview2.exe שורדים את
/// סגירת התוכנה ונועלים את פרופיל ה-WebView2 (תוספים ריקים) — נרשם ל-errors.txt.
Future<void> _logJobObjectContainmentFailure() async {
  if (kIsWeb || !Platform.isWindows || kDebugMode) return;
  try {
    final status = await AppWindowListener.jobObjectStatus();
    if (status.ready) return;
    _appendUnhandledErrorToLocalLog(
      title: 'Job Object containment unavailable',
      error: status.failure ?? 'unknown failure',
      details: const {
        'Phase': 'initialize',
        'Component': 'Job Object (WebView2 process containment)',
      },
    );
  } catch (error, stackTrace) {
    _logNonFatalInitializationError('Job Object status', error, stackTrace);
  }
}

Future<void> _runDeferredNotificationService() async {
  try {
    await NotificationService().init();
  } catch (error, stackTrace) {
    _logNonFatalInitializationError('Notification service', error, stackTrace);
  }
}

Future<void> _runDeferredErrorReportFlush() async {
  try {
    // המופע הארוך-טווח: רץ עם Timer.periodic של 5 דקות, מחזיק http.Client
    // עם connection pool שעלול לתקוע את היציאה ב-Windows admin install.
    // רק המופע הזה נרשם ב-HttpClientRegistry; מופעים קצרי-טווח אחרים שנוצרים
    // לפי דרישה (בדיאלוגים/הגדרות) אינם נרשמים כדי למנוע memory leak.
    final reportService = DirectErrorReportService();
    HttpClientRegistry.register(reportService.closeHttpClient);
    await reportService.startAutomaticFlush();
    // תור דיווחי התוספים משתמש ב-client סטטי שכבר רשום ב-HttpClientRegistry.
    await PluginReportService().startAutomaticFlush();
  } catch (error, stackTrace) {
    _logNonFatalInitializationError(
      'Direct error report queue',
      error,
      stackTrace,
    );
  }
}

Future<void> _runDeferredPdfrxCacheInit() async {
  try {
    final cacheDir = await getTemporaryDirectory();
    Pdfrx.cacheDirectoryPath = cacheDir.path;
    debugPrint('Pdfrx cache directory set to: ${cacheDir.path}');
  } catch (error, stackTrace) {
    _logNonFatalInitializationError('Pdfrx cache directory', error, stackTrace);
  }
}

Future<void> _runDeferredAutoBackup() async {
  try {
    if (await BackupService.shouldPerformAutoBackup()) {
      await BackupService.performAutoBackup();
    }
  } catch (error, stackTrace) {
    _logNonFatalInitializationError('Automatic backup', error, stackTrace);
  }
}

/// אזהרה על שורש נתונים חסום-לכתיבה. ממתינה לחשיפת החלון — דיאלוג לפניה
/// אינו מוצג כי עדיין אין Navigator.
Future<void> _runDeferredDataRootWritabilityWarning() async {
  try {
    await _mainWindowRevealedCompleter.future.timeout(
      const Duration(seconds: 15),
    );
  } on TimeoutException {
    // ממשיכים בכל זאת — אם ה-Navigator עדיין חסר, ההצגה תדולג בשקט.
  }
  await DataRootWritabilityWarning.showIfNeeded();
}

Future<void> _runDeferredProtocolRegistration() async {
  try {
    await PluginProtocolRegistrationService().ensureRegistered();
  } catch (error, stackTrace) {
    _logNonFatalInitializationError(
      'Plugin protocol registration',
      error,
      stackTrace,
    );
  }
}

/// חימומי מטמון שאינם חיוניים להצגת המסך הראשי (איתור מקורות, מילון, גופני
/// מערכת, היברובוקס מקומי). ממתינים לחשיפת החלון ([presentMainWindow]) לפני
/// שמתחילים — אחרת השאילתות הכבדות על seforim.db והעיבוד על ה-main isolate
/// (BooksCache/AcronymsCache סורקים עשרות אלפי שורות) מתחרים בטעינת תוכן
/// הספר הפעיל ומעכבים את הופעתו. ה-timeout הוא רשת ביטחון בלבד: בזרימה רגילה
/// החשיפה קורית תוך שניות (כולל failsafe של 8 שניות ב-MainWindowScreen).
Future<void> _runDeferredCacheWarmups() async {
  try {
    await _mainWindowRevealedCompleter.future.timeout(
      const Duration(seconds: 15),
    );
  } on TimeoutException {
    // ממשיכים בכל זאת — עדיף חימום מאוחר מאשר אף פעם.
  }
  // כיווץ cache.db — ה-prune-ים של מטמוני ה-docx/PDF משחררים דפים במהלך
  // הסשן אך לא מקטינים את הקובץ. רץ *לפני* החימומים ולא במקביל להם, כי
  // ה-warmUp של ReferenceBooksCache מנקה את מטמון ה-PDF מול אותו קובץ —
  // וכתיבה שנתקלת ב-VACUUM נחסמת סינכרונית עד ל-busy_timeout.
  await CacheDatabaseHolder.instance.compactIfFragmented().catchError((
    Object e,
  ) {
    if (kDebugMode) debugPrint('Failed to compact cache.db: $e');
    return false;
  });
  unawaited(
    DictionaryLookupRepository.instance.ensureLoaded().catchError((e) {
      if (kDebugMode) debugPrint('Failed to warm up dictionary: $e');
    }),
  );
  unawaited(
    ExportRestrictionService.ensureLoaded().catchError((e) {
      if (kDebugMode) debugPrint('Failed to load export restrictions: $e');
    }),
  );
  unawaited(
    BooksCache.instance.warmUp().catchError((e) {
      if (kDebugMode) debugPrint('Failed to warm up BooksCache: $e');
    }),
  );
  unawaited(
    AcronymsCache.instance.warmUp().catchError((e) {
      if (kDebugMode) debugPrint('Failed to warm up AcronymsCache: $e');
    }),
  );
  unawaited(
    GenerationCache.instance.warmUp().catchError((e) {
      if (kDebugMode) debugPrint('Failed to warm up GenerationCache: $e');
    }),
  );
  unawaited(
    AppFonts.warmUpSystemFontsCache().catchError((e) {
      if (kDebugMode) debugPrint('Failed to warm up system fonts: $e');
    }),
  );
  unawaited(
    ReferenceBooksCache.instance.warmUp().catchError((e) {
      if (kDebugMode) {
        debugPrint('Failed to warm up ReferenceBooksCache: $e');
      }
    }),
  );
  // פרי-וורם של ספרי היברובוקס המקומיים (אם הוגדרה תיקייה): סריקת
  // התיקייה וטעינת המטא-דאטה מהקטלוג מבוצעות ברקע כדי שהחיפוש הראשון
  // לא ישלם עבורן. כשאין תיקייה — הקריאה מתקצרת מיד ללא עלות.
  unawaited(() async {
    try {
      await DataRepository.instance.localHebrewBooks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to warm up local HebrewBooks: $e');
      }
    }
  }());
}

Future<void> _preWarmWebViewEnvironment() async {
  if (kIsWeb || !Platform.isWindows) return;
  try {
    // תוסף דקלרטיבי נשאר עצל גם אם אושרה לו הפעלה ברקע.
    final installed = await PluginRegistryRepository().getAllPlugins();
    final hasStartupRunner = installed.any(usesLegacyStartupRunner);
    if (!hasStartupRunner) {
      if (kDebugMode) {
        debugPrint('WebView2 pre-warm skipped: no startup plugins');
      }
      return;
    }
    // אם WebView2 Runtime אינו מותקן, אתחול הסביבה ייכשל ממילא. מדלגים כדי
    // לא לזרוק חריגה מיותרת ולא להצמיח תהליכי Edge חלקיים.
    if (!await WebViewEnvironmentHolder.isRuntimeAvailable()) {
      if (kDebugMode) {
        debugPrint('WebView2 pre-warm skipped: runtime not installed');
      }
      return;
    }
    await WebViewEnvironmentHolder.initialize();
  } catch (error, stackTrace) {
    _logNonFatalInitializationError(
      'WebView2 environment pre-warm',
      error,
      stackTrace,
    );
  }
}

Future<void>? _processInitializationFuture;

Future<void> _ensureBootstrapInitialized() {
  return (_processInitializationFuture ??= _initializeProcessSingletons()).then(
    (_) => _initializeRestartableRuntime(),
  );
}

@visibleForTesting
void scheduleAfterTwoFrames(
  VoidCallback action, {
  WidgetsBinding? binding,
  void Function(FrameCallback callback)? scheduleFrameCallback,
}) {
  final schedule =
      scheduleFrameCallback ??
      (binding ?? WidgetsBinding.instance).addPostFrameCallback;
  schedule((_) {
    schedule((_) {
      action();
    });
  });
}

/// ה-ack המוקדם שנשלח מ-[_sendEarlyInstallAcks] — נשמר כדי שמופע משני יוכל
/// להמתין לסיומו לפני exit(0) (אחרת התהליך מת לפני שהבקשה יוצאת).
Future<void>? _earlyInstallAckFuture;

/// סורק את ארגומנטי ההפעלה אחר קישורי `otzaria://plugin/install` עם token,
/// ושולח לכל אחד אישור קבלה (fire-and-forget). האישור נשלח שוב גם מה-bloc
/// בעת הטיפול בבקשה — השרת אידמפוטנטי לכך.
void _sendEarlyInstallAcks(List<String> args) {
  final futures = <Future<void>>[];
  for (final raw in args) {
    final arg = raw.trim();
    if (!arg.toLowerCase().startsWith('otzaria:')) continue;
    final uri = Uri.tryParse(arg);
    if (uri == null) continue;
    final reportContext = PluginStoreLinkParser.parseUri(uri)?.reportContext;
    if (reportContext != null) {
      futures.add(PluginInstallReportService.acknowledge(reportContext));
    }
  }
  if (futures.isNotEmpty) {
    _earlyInstallAckFuture = Future.wait(futures);
  }
}

Future<void> _enqueueExternalActivationArgs(List<String> args) async {
  final activationUris = <String>[];

  for (final raw in args) {
    final arg = raw.trim();
    if (arg.isEmpty) continue;

    if (arg.toLowerCase().startsWith('otzaria:')) {
      activationUris.add(arg);
      continue;
    }

    // לחיצה כפולה על קובץ `.otzplugin` משויך — המערכת מעבירה את הנתיב כארגומנט.
    // ב-Linux/macOS, ה-desktop entry משתמש ב-‎%u (URL), כך שהמערכת מעבירה
    // ‎file:///abs/path. ממירים ל-נתיב מקומי לפני שמירה בתור.
    final localPath = _resolveLocalPluginPath(arg);
    if (localPath != null) {
      activationUris.add(_buildLocalPluginInstallUri(localPath));
    }
  }

  for (final uriString in activationUris) {
    try {
      await _externalActivationQueue.enqueueUriString(uriString);
    } catch (error, stackTrace) {
      _appendUnhandledErrorToLocalLog(
        title: 'External Activation Queue Error',
        error: error,
        stackTrace: stackTrace,
        details: {
          'Uri': uriString,
        },
      );
    }
  }
}

/// מחזירה נתיב קובץ מקומי `.otzplugin` אם הארגומנט הוא כזה — או null אחרת.
/// תומך גם ב-`file://` URIs (Linux/macOS) וגם בנתיב גולמי (Windows).
@visibleForTesting
String? resolveLocalPluginPathForTesting(String arg) =>
    _resolveLocalPluginPath(arg);

String? _resolveLocalPluginPath(String arg) {
  String candidate = arg;
  if (arg.toLowerCase().startsWith('file:')) {
    try {
      final uri = Uri.parse(arg);
      if (uri.scheme == 'file') {
        candidate = uri.toFilePath();
      }
    } catch (_) {
      // לא URI תקני — נמשיך עם הערך המקורי.
    }
  }

  if (candidate.toLowerCase().endsWith('.otzplugin')) {
    return candidate;
  }
  return null;
}

String _buildLocalPluginInstallUri(String filePath) {
  final encoded = Uri.encodeQueryComponent(filePath);
  return 'otzaria://plugin/install-local?path=$encoded';
}

/// מזהה ארגומנטים של ממשק שורת פקודה (CLI). אם זוהתה פקודה — מריצה
/// אותה ומחזירה `true` (האפליקציה צריכה לעצור מיד ולא להעלות GUI).
///
/// פקודות נתמכות:
///   `otzaria.exe pack-plugin [path] [--force] [--output <file>]`
///       אורז תיקיית תוסף לקובץ `.otzplugin`. אם `path` חסר — נעשה
///       שימוש בתיקייה הנוכחית.
///   `otzaria.exe pack-plugin --help` / `-h` — הצגת מסך עזרה.
///   `otzaria build-release-index --library <dir> --index <dir> --data <dir>`
///       בונה אינדקס חיפוש מבודד עבור חבילת ההפצה המלאה.
///   `otzaria info [<נושא>] [--limit=<n>] [--compact] [--out=<path>]`
///       מדפיס דוח JSON על ההתקנה ל-stdout (ראה [AppInfoCli]).
///
/// הלוגיקה עצמה ב-[PluginPackagerCli.run] כדי לשתף בדיוק את אותו הקוד
/// עם `tool/plugins/package_plugin.dart`.
Future<bool> _maybeRunCliCommand(List<String> args) async {
  if (args.isEmpty) return false;

  final normalized = normalizeCliCommand(args.first);

  if (normalized == 'pack-plugin') {
    final exitCode = await PluginPackagerCli.run(args.skip(1).toList());
    await stdout.flush();
    await stderr.flush();
    exit(exitCode);
  }

  if (normalized == 'build-release-index') {
    final exitCode = await ReleaseIndexBuilderCli.run(args.skip(1).toList());
    await stdout.flush();
    await stderr.flush();
    exit(exitCode);
  }

  if (normalized == 'info') {
    final exitCode = await AppInfoCli.run(args.skip(1).toList());
    await stdout.flush();
    await stderr.flush();
    exit(exitCode);
  }

  return false;
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  Object? _error;
  HistoryRepository? _historyRepository;
  SettingsRepository? _settingsRepository;

  @override
  void initState() {
    super.initState();
    _ensureBootstrapInitialized()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _historyRepository = HistoryRepository();
            _settingsRepository = SettingsRepository();
            _ready = true;
          });
          unawaited(_runDeferredCacheWarmups());
        })
        .catchError((Object error, StackTrace stackTrace) {
          _appendUnhandledErrorToLocalLog(
            title: 'Bootstrap Error',
            error: error,
            stackTrace: stackTrace,
          );
          if (!mounted) return;
          setState(() {
            _error = error;
            _ready = true;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashApp();

    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text(
              'שגיאת אתחול: $_error',
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      );
    }

    final historyRepository = _historyRepository!;
    final settingsRepository = _settingsRepository!;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FocusRepository>(
          create: (_) => FocusRepository(),
        ),
        RepositoryProvider<SettingsRepository>(
          create: (_) => settingsRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(
              repository: settingsRepository,
            )..add(LoadSettings()),
          ),
          BlocProvider<LibraryBloc>(
            // ה-LoadLibrary אינו נשלח כאן יותר: בניית הקטלוג (~300ms CPU על
            // ה-main thread) הייתה חונקת את שאילתת תוכן הספר הפעיל ומעכבת את
            // הופעתו. ההפעלה עברה ל-MainWindowScreen._revealMainWindowOnce,
            // שמעדיף את טעינת הספר הפעיל ורק אז מתחיל את בניית הקטלוג.
            create: (_) => LibraryBloc(),
          ),
          BlocProvider<CustomFoldersBloc>(
            create: (context) => CustomFoldersBloc(
              addLibraryEvent: (event) =>
                  context.read<LibraryBloc>().add(event),
            )..add(const LoadCustomFolders()),
          ),
          BlocProvider<IndexingBloc>(
            create: (_) => IndexingBloc.create(),
          ),
          BlocProvider<HistoryBloc>(
            create: (_) => HistoryBloc(historyRepository),
          ),
          BlocProvider<TabsBloc>(
            create: (_) {
              final bloc = TabsBloc(repository: TabsRepository())
                ..add(LoadTabs());
              // חלון שנפתח עם מטען מקבל את הכרטיסיה שהועברה אליו. `LoadTabs`
              // נשלח קודם כדי שסדר האירועים יהיה זהה לחלון רגיל — הכרטיסיה
              // המועברת נכנסת אחריו, ולכן היא זו שתהיה פעילה.
              // הפענוח כאן ולא בנקודת הכניסה: בשלב הזה `Settings` כבר
              // מאותחל, ו-`TextBookTab.fromJson` תלוי בו.
              final payload = secondaryWindowPayload;
              secondaryWindowPayload = null;
              final transferred = MultiWindowService.decodePayload(payload);
              if (transferred != null) {
                bloc.add(AddTab(transferred));
              }
              return bloc;
            },
          ),
          BlocProvider<NavigationBloc>(
            create: (context) {
              final nav = NavigationBloc(
                repository: NavigationRepository(),
                tabsRepository: TabsRepository(),
                // "חיפוש" ו"עיון" הם אותו עמוד טאבים; היישור לפי החלונית
                // הפעילה שומר שהאייקון המודגש בסרגל יתאים למה שמוצג בפועל.
                activePaneStream: context
                    .read<TabsBloc>()
                    .stream
                    .map((tabsState) => tabsState.activePane)
                    .distinct(),
              )..add(const CheckLibrary());
              // ⚠️ אחרי `CheckLibrary` ולא במקומו. `CheckLibrary` מחליט
              // לאן לנווט לפי מצב הספרייה, ובחלון שנפתח עם כרטיסיה מועברת
              // ההחלטה שגויה: הוא היה נשאר במסך הספרייה בעוד הכרטיסיה
              // פתוחה מאחוריו — בדיוק מה שנצפה. הניווט נשלח אחריו ולכן
              // גובר עליו.
              if (WindowRole.openedWithTab) {
                nav.add(const NavigateToScreen(Screen.reading));
              }
              return nav;
            },
          ),
          BlocProvider<FindRefBloc>(
            create: (_) => FindRefBloc(
              findRefRepository: buildFindRefRepository(),
            ),
          ),
          BlocProvider<PersonalNotesBloc>(
            create: (_) => PersonalNotesBloc(),
          ),
          BlocProvider<BookmarkBloc>(
            create: (_) => BookmarkBloc(BookmarkRepository()),
          ),
          BlocProvider<WorkspaceBloc>(
            create: (context) {
              final tabsBloc = context.read<TabsBloc>();
              return WorkspaceBloc(
                repository: WorkspaceRepository(),
                onWorkspaceTabsChanged:
                    (
                      List<OpenedTab> tabs,
                      int activeIndex,
                      String? activePane,
                    ) async {
                      final replaced = tabsBloc.stream.firstWhere(
                        (state) =>
                            identical(state.tabs, tabs) &&
                            state.currentTabIndex == activeIndex,
                      );
                      tabsBloc.add(
                        ReplaceAllTabs(
                          tabs,
                          activeIndex,
                          activePane: activePane,
                        ),
                      );
                      await replaced;
                    },
              )..add(LoadWorkspaces());
            },
          ),
          ChangeNotifierProvider<ShamorZachorDataProvider>(
            lazy: true,
            create: (_) => ShamorZachorDataProvider(),
          ),
          ChangeNotifierProvider<ShamorZachorProgressProvider>(
            lazy: true,
            create: (_) => ShamorZachorProgressProvider(),
          ),
          BlocProvider<WorkStatusCubit>(
            create: (_) => WorkStatusCubit(),
          ),
          BlocProvider<LibraryUpdateBloc>(
            lazy: true,
            create: (context) => LibraryUpdateBloc(
              repository: LibraryUpdateRepository(
                discovery: LibraryUpdateDiscovery(
                  client: GithubLibraryReleaseClient(),
                ),
                downloader: PatchDownloader(
                  decompress: (bytes) => Zstandard().decompress(bytes),
                ),
              ),
              companionAssets: CompanionAssetsService(),
              isOfflineMode: () =>
                  Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ??
                  false,
              // ⚠️ חלון משני לעולם אינו בודק עדכונים. עדכון ספרייה הוא
              // פעולה פר-תהליך: שני חלונות ששאלו את GitHub במקביל קיבלו
              // 403, והמשתמש ראה "שגיאה בקבלת רשימת ה-releases" בכל
              // פתיחת חלון.
              areUpdatesEnabled: () =>
                  !isSecondaryWindow &&
                  (Settings.getValue<bool>(
                        SettingsRepository.keySoftwareAndBookUpdatesEnabled,
                      ) ??
                      true),
              // עדכוני ספרייה תמיד ליציב בלבד — מנותק מערוץ הפיתוח, שמשפיע רק
              // על עדכוני התוכנה.
              allowPrerelease: () => false,
              onCheckSucceeded: () => recordSuccessfulUpdateCheck(
                SettingsRepository.keyLastLibraryUpdateCheck,
              ),
            ),
          ),
          BlocProvider<PluginUpdatesCubit>(
            lazy: true,
            create: (_) => PluginUpdatesCubit(),
          ),
          BlocProvider<PluginSystemBloc>(
            create: (context) {
              final repository = PluginRegistryRepository();
              final tabsBloc = context.read<TabsBloc>();
              final coordinator = BookOpenCoordinator(
                tabsBloc: tabsBloc,
                historyBloc: context.read<HistoryBloc>(),
                navigationBloc: context.read<NavigationBloc>(),
              );
              final bookAccess = DeclarativeLibraryBookAccess.otzaria(
                coordinator,
              );
              final host = DeclarativePluginHostService(
                loadPlugin: repository.getPlugin,
                loadPermissions: (pluginId) async =>
                    (await repository.getGrantedPermissionNames(
                      pluginId,
                    )).toSet(),
                bookResolver: bookAccess,
                bookOpener: bookAccess,
                parallelEditionsFinder: bookAccess.parallelEditionsForIdentity,
                readerScroller: PluginDeclarativeReaderScroller(
                  tabsBloc: tabsBloc,
                ),
                searchOpener: PluginDeclarativeSearchOpener(coordinator),
                onError: (pluginId, error, stackTrace) => debugPrint(
                  'Declarative plugin host [$pluginId]: $error\n$stackTrace',
                ),
              );
              return PluginSystemBloc(
                  repository: repository,
                  declarativeHost: host,
                  readerStates: tabsBloc.stream,
                  initialReaderState: tabsBloc.state,
                )
                ..add(const SeedBundledPlugins())
                ..add(LoadPlugins());
            },
          ),
        ],
        // מתחת לכל ה-blocs: האפיק עונה על בקשות מחלונות אחרים, ושתי
        // הבקשות הנתמכות — "תאר את עצמך" ו"קלוט כרטיסיה" — זקוקות
        // ל-TabsBloc ול-NavigationBloc.
        child: const WindowBusHost(child: App()),
      ),
    );
  }
}

Future<void> initHive() async {
  // ⚠️ `hiveRootPath` ולא `getDataRootPath`: בחלון משני קובצי ה-Hive
  // יושבים בתיקייה נפרדת, אבל שאר שורש הנתונים — תוספים, WebView2,
  // מסדי נתונים — נשאר משותף. ראו `configureHiveRootForWindow`.
  Hive.init(await hiveRootPath());
  // כל box הוא קובץ נפרד ועצמאי — הפתיחות רצות במקביל במקום בזו אחר זו.
  await Future.wait([
    Hive.openBox<dynamic>('tabs'),
    Hive.openBox<dynamic>('workspaces'),
    Hive.openBox<dynamic>('history'),
    Hive.openBox<dynamic>('bookmarks'),
    Hive.openBox<dynamic>(DirectErrorReportService.queueBoxName),
    Hive.openBox<dynamic>(PluginReportService.queueBoxName),
  ]);
}

Future<void> loadCerts() async {
  final certs = ['assets/ca/netfree_cas.pem'];
  for (var cert in certs) {
    final certBytes = await rootBundle.load(cert);
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      certBytes.buffer.asUint8List(),
    );
  }
}

/// Clean up resources when the app is closing
void cleanup() {
  _appWindowListener?.dispose();

  // Clear shared book/acronym caches
  BooksCache.instance.clear();
  AcronymsCache.instance.clear();
  GenerationCache.instance.clear();
}

// Note: TOC parsing helper moved to lib/utils/toc_parser.dart for reuse

// ═══════════════════════════════════════════════════════════════════════
// ספייק P-0 שלב 2 — אינו מיועד ל-main.
//
// נקודת כניסה לתהליך broker: מנוע Flutter **בלי `FlutterViewController`**.
// השאלה הנמדדת: האם Dart רץ בכלל במנוע חסר-view — טיימרים, microtasks,
// I/O ו-`rootBundle` — או שהמנוע מצפה ל-view כדי להתקדם.
//
// זו הליבה של מודל C1, וגם של ה-host במודל A (T-G2.0). המדידה כותבת
// שורות ל-`%TEMP%\otzaria_broker_probe.log` ויוצאת; אין UI ואין ערוצים.
// ═══════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════
// חלון אוצריא נוסף.
//
// רץ ב-isolate נפרד משלו, על thread ייעודי, באותו תהליך — מודל A
// (docs/P-0-stage3-result.md). זו **אינה** `main()`: אין בדיקת מופע יחיד
// (היא הייתה סוגרת את החלון מיד), אין splash נייטיב, ואין תור הפעלות
// חיצוניות — כל אלה שייכים לתהליך, וכבר רצו בחלון הראשון.
//
// ⚠️ שורש נתונים פרטי. `hive_ce` נועל את קובצי ה-`.lock` בלעדית, ונמדד
// שהנעילה היא פר-handle ולא פר-תהליך: שני isolates באותו תהליך נכשלים
// באותו errno 33 כמו שני תהליכים (docs/P-0-stage3-result.md §7). עד
// שפרק 3 ינתב את Hive ו-Settings ל-host, כל חלון מקבל תיקיית נתונים
// משלו. הספרייה עצמה — הספרים, SQLite ואינדקס Tantivy — משותפת, כי
// אלה **כן** נפתחים פעמיים בהצלחה.
//
// המשמעות היום: להעדפות ולהיסטוריה של חלון נוסף אין שיתוף עם הראשון.
// זו הגבלה ידועה של ה-MVP, לא תכנון סופי.
@pragma('vm:entry-point')
void secondaryWindowMain(List<String> args) async {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  isSecondaryWindow = true;
  WindowRole.isSecondary = true;
  _secondaryWindowStartup = Stopwatch()..start();
  SentryWidgetsFlutterBinding.ensureInitialized();
  EditableText.debugDeterministicCursor = true;

  try {
    // ⚠️ **רק** הפניית קובצי ה-Hive נעשית כאן.
    //
    // את כל שאר האתחול — `RustLib.init`, `Settings.init`, `initHive`,
    // `SqliteDataProvider`, `windowManager.ensureInitialized` — מבצע
    // `AppBootstrap` דרך `_initializeProcessSingletons`, בדיוק כמו בחלון
    // הראשון. שכפול שלהם כאן נכשל ב-"Should not initialize
    // flutter_rust_bridge twice": `RustLib` שומר את מצבו על
    // `RustLib.instance`, שהוא סטטי פר-isolate, ולכן שתי קריאות **באותו**
    // isolate הן שגיאה — גם אם החלון חדש.
    //
    // הכלל: נקודת הכניסה של חלון משני קובעת רק מה **שונה** בו. כל השאר
    // עובר במסלול היחיד והמשותף.
    final sharedRoot = await AppPaths.getDataRootPath();
    final windowRoot = p.join(
      sharedRoot,
      'windows',
      DateTime.now().microsecondsSinceEpoch.toRadixString(36),
    );
    await Directory(windowRoot).create(recursive: true);
    // ⚠️ Hive בלבד, ולא `configureDataRootPathForProcess`. הפניית שורש
    // הנתונים כולו רוקנה את `<dataRoot>/plugins` — תפריט הכלים בחלון
    // משני היה ריק, וכרטיסיית תוסף נעלמה מהמקור במקום להיפתח ביעד.
    configureHiveRootForWindow(windowRoot);

    // זריעת ההעדפות של החלון שפתח אותנו.
    //
    // ⚠️ חייבת לקרות **לפני** ש-`AppBootstrap` מריץ את `Settings.init`,
    // אחרת החלון יעלה בלי נתיב ספרייה ויציג את מסך ההתחלה כאילו זו התקנה
    // חדשה. הכתיבה היא ל-box של שורש הנתונים הפרטי, ולכן אין התנגשות
    // נעילה; `Settings.init` יפתח מאוחר יותר את אותו box הפתוח ויראה את
    // הערכים.
    final seed = MultiWindowService.decodePreferences(
      args.isEmpty ? null : args.first,
    );
    if (seed.isNotEmpty) {
      Hive.init(windowRoot);
      final box = await Hive.openBox<dynamic>(
        HiveCache.keyName,
        path: windowRoot,
      );
      await box.putAll(seed);
    }
  } catch (e, st) {
    debugPrint('secondaryWindowMain: data root setup failed: $e\n$st');
  }

  Bloc.observer = AppBlocObserver();
  unawaited(AppCursors.ensureInitialized());

  // ⚠️ המטען נשמר **גולמי** ומפוענח מאוחר יותר, ב-`TabsBloc`.
  //
  // `TextBookTab.fromJson` קורא ל-`Settings.getValue('key-splited-view')`,
  // ו-`Settings` מאותחל רק בתוך `AppBootstrap`. פענוח כאן זרק, נתפס והחזיר
  // null — הכרטיסיה נעלמה מהחלון המקורי ולא נפתחה בחדש. `ToolTab.fromJson`
  // אינו נוגע ב-Settings, ולכן דווקא כלים עברו בהצלחה והבאג נראה אקראי.
  secondaryWindowPayload = args.isEmpty || args.first.isEmpty
      ? null
      : args.first;
  WindowRole.openedWithTab = MultiWindowService.payloadHasTab(
    secondaryWindowPayload,
  );

  // ⚠️ נדרש לפני `runApp`: בלעדיו `setTitleBarStyle(hidden)` שב-bootstrap
  // אינו נתפס, והחלון עולה עם מסגרת Windows סטנדרטית **מעל** סרגל הכותרת
  // המותאם של האפליקציה — "חלון בתוך חלון". החלון הראשון עושה זאת
  // ב-`main()`, ולכן הבעיה לא נראתה בו.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
    } catch (e) {
      debugPrint('secondaryWindowMain: windowManager init failed: $e');
    }
  }

  runApp(
    AppWindowScope(
      controller: _appWindow,
      geometry: _appWindow,
      child: SentryWidget(
        child: RestartWidget(
          child: const AppBootstrap(),
        ),
      ),
    ),
  );
}

/// פותח חלון נוסף אחרי השהיה, לבדיקה מקצה לקצה בלי אינטראקציה ידנית.
///
/// עובר במסלול המלא — כולל צילום ההעדפות — ולכן הוא בודק את מה שהמשתמש
/// יקבל, ולא רק את הצד הנייטיב. מופעל רק כאשר `OTZARIA_DEBUG_OPEN_WINDOW_MS`
/// מוגדר.
void _maybeScheduleDebugSecondWindow() {
  final ms = int.tryParse(
    Platform.environment['OTZARIA_DEBUG_OPEN_WINDOW_MS'] ?? '',
  );
  if (ms == null || ms <= 0) return;
  Timer(Duration(milliseconds: ms), () async {
    final opened = await const MultiWindowService().openWindow();
    debugPrint('[debug] openWindow -> $opened');
  });
}

/// האם החלון הזה הוא חלון משני (נפתח מתוך חלון אחר).
///
/// ⚠️ משמש לחסימת שירותים שהם **פר-תהליך ולא פר-חלון**: בדיקת עדכוני
/// ספרייה, שירות ההתראות ושטיפת דיווחי השגיאות. בלי החסימה כל חלון הריץ
/// אותם בנפרד — שתי בקשות מקבילות ל-GitHub החזירו 403, והמשתמש קיבל
/// "שגיאה בקבלת רשימת ה-releases" בכל פתיחת חלון.
bool isSecondaryWindow = false;

/// מודד את זמן העלייה של חלון משני, מנקודת הכניסה ועד החשיפה.
Stopwatch? _secondaryWindowStartup;

/// מריץ שלב אתחול ומודד אותו — בחלון משני בלבד.
///
/// ⚠️ אין למדוד בחלון הראשון: שם השלבים רצים תחת ה-splash הנייטיב וזמנם
/// אינו מורגש, וההדפסות היו רק רעש בלוג.
Future<T> _timedPhase<T>(String name, Future<T> Function() body) async {
  if (!isSecondaryWindow) return body();
  final sw = Stopwatch()..start();
  try {
    return await body();
  } finally {
    debugPrint('[window-phase] $name: ${sw.elapsedMilliseconds}ms');
  }
}

/// המטען הגולמי שאיתו נפתח החלון, אם נפתח כחלון משני.
///
/// נצרך **פעם אחת** ביצירת `TabsBloc` ומתאפס שם, כדי ש-`RestartWidget`
/// לא יוסיף את הכרטיסיה שוב בהפעלה מחדש של העץ. הפענוח קורה שם ולא
/// כאן — ראו ההערה ב-[secondaryWindowMain].
String? secondaryWindowPayload;

int _probeThreadId() {
  try {
    return DynamicLibrary.open(
      'kernel32.dll',
    ).lookupFunction<Uint32 Function(), int Function()>(
      'GetCurrentThreadId',
    )();
  } catch (_) {
    return -1;
  }
}

void _probeLog(String tag, String step, Object? outcome) {
  debugPrint('[$tag] $step = $outcome');
}

int _probeRssMb() => (ProcessInfo.currentRss / (1024 * 1024)).round();

/// פותח את מחסנית הנתונים ומדווח על כל מאגר בנפרד.
///
/// זו **בדיקה 3 של P-2** ולב **בדיקה 9**. במודל A כל חלון הוא isolate נפרד
/// באותו תהליך, ולכן לכל אחד סינגלטון `TantivyDataProvider` משלו — כלומר
/// שתי פתיחות של אותו אינדקס. השאלה איזה מאגר סובל פתיחה שנייה ואיזה
/// דורש RPC ל-host היא בדיוק מה שקובע את היקף פרק 3.
Future<void> _probeOpenStack(String tag) async {
  WidgetsFlutterBinding.ensureInitialized();
  Future<void> step(String name, Future<void> Function() body) async {
    try {
      await body();
      _probeLog(tag, name, 'ok');
    } catch (e) {
      _probeLog(tag, name, 'FAILED: $e');
    }
  }

  await step('settings', () => Settings.init(cacheProvider: HiveCache()));
  await step('hive', () => initHive());
  await step('sqlite', () => SqliteDataProvider.instance.initialize());
  await step('rustlib', () => RustLib.init());
  try {
    final provider = TantivyDataProvider.instance;
    await provider.engine;
    final hits = await provider.countTexts('בראשית', const [], const []);
    _probeLog(tag, 'tantivy', 'ok ($hits hits)');
  } catch (e) {
    _probeLog(tag, 'tantivy', 'FAILED: $e');
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ספייק P-0 שלב 3 — האם מודל A נפגע מתחרות thread?
//
// נמדד קודם ש-`Default` **כן** ממזג platform ו-UI thread (בניגוד למה
// שה-header של Flutter מרמז), ושהדגל `RunOnSeparateThread` עובד אך
// המנוע מכריז שיוסר. השאלה שנשארה: אפשר להימנע מהתחרות **בלי** הדגל,
// פשוט ביצירת כל מנוע על thread ייעודי משלו עם לולאת הודעות משלו?
//
// המדידה: מנוע A על ה-thread הראשי שורף CPU 2 שניות ברצף, בזמן שמנוע B
// על thread אחר מתקתק טיימר כל 100ms. הפער המרבי בין תקתוקים הוא
// התשובה — ~100ms פירושו threads עצמאיים, ~2000ms פירושו תחרות.
// ═══════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════
// ספייק P-2 — שני חלונות אמיתיים עם view, כל אחד על thread משלו.
//
// המדידות הקודמות היו חסרות-view והוכיחו שאין תחרות בין ה-isolates
// (102ms מול 2092ms בבקרה). כאן אותו דבר, אבל **גלוי לעין**: כפתור
// "הקפא" בחלון אחד חוסם את ה-isolate שלו לשלוש שניות, והשעון בחלון
// השני ממשיך לרוץ. זו ההכרעה של מודל A על המסך.
// ═══════════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
void windowATest(List<String> args) => _runSpikeWindow('א', Colors.indigo);

@pragma('vm:entry-point')
void windowBTest(List<String> args) => _runSpikeWindow('ב', Colors.teal);

void _runSpikeWindow(String label, MaterialColor color) {
  WidgetsFlutterBinding.ensureInitialized();
  // `OTZARIA_SPIKE_EXIT_MS` סוגר את התהליך אוטומטית. קיים כדי שמבחן
  // העומס על הקריסה חוצת-ה-threads (docs/P-2-two-windows.md §3) יוכל
  // להריץ מאות איטרציות — בלי זה כל איטרציה ממתינה ל-timeout.
  //
  // ⚠️ רק חלון ב' סוגר. בגרסה הראשונה **שני** החלונות קראו ל-`exit(0)`
  // בו-זמנית, ואז נמדדו 2 קריסות ב-200 איטרציות — אבל שני isolates
  // שסוגרים תהליך יחד הם תרחיש שההרנס יצר, לא האפליקציה. הפרדה זו היא
  // מה שמבחין בין באג ארכיטקטוני לארטיפקט של המדידה.
  final exitMs = int.tryParse(
    Platform.environment['OTZARIA_SPIKE_EXIT_MS'] ?? '',
  );
  if (exitMs != null && exitMs > 0 && label == 'ב') {
    Timer(Duration(milliseconds: exitMs), () => exit(0));
  }
  runApp(_SpikeWindowApp(label: label, color: color));
}

class _SpikeWindowApp extends StatelessWidget {
  const _SpikeWindowApp({required this.label, required this.color});

  final String label;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: color, useMaterial3: true),
      // בדיקה 6 של P-2: RTL אינו nice-to-have.
      locale: const Locale('he'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('he'), Locale('en')],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: _SpikeWindowBody(label: label),
      ),
    );
  }
}

class _SpikeWindowBody extends StatefulWidget {
  const _SpikeWindowBody({required this.label});

  final String label;

  @override
  State<_SpikeWindowBody> createState() => _SpikeWindowBodyState();
}

class _SpikeWindowBodyState extends State<_SpikeWindowBody> {
  late final Timer _clock;
  int _tenths = 0;
  bool _frozen = false;

  @override
  void initState() {
    super.initState();
    // שעון עשיריות שנייה. אם ה-isolate של החלון הזה נחסם — הוא ייעצר,
    // וזה בדיוק מה שאמורים לראות בחלון האחר.
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _tenths++);
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _freeze() {
    setState(() => _frozen = true);
    // חסימה סינכרונית מכוונת של ה-UI isolate של החלון הזה בלבד.
    final end = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(end)) {}
    if (mounted) setState(() => _frozen = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('חלון ${widget.label}'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              (_tenths / 10).toStringAsFixed(1),
              style: theme.textTheme.displayLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text('שניות מאז פתיחת החלון', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            Text(
              'thread ${_probeThreadId()}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _frozen ? null : _freeze,
              icon: const Icon(Icons.ac_unit),
              label: const Text('הקפא חלון זה ל-3 שניות'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 320,
              child: Text(
                'לחיצה תחסום את ה-isolate של החלון הזה בלבד. השעון כאן '
                'ייעצר — והשעון בחלון השני ימשיך לרוץ. זו ההוכחה '
                'שמנוע לכל thread מבטל את תחרות §3.3.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void engineATest(List<String> args) async {
  _probeLog('A', 'dart-thread-id', _probeThreadId());
  _probeLog('A', 'rss-mb-one-engine', _probeRssMb());

  // מנוע A הוא "החלון הראשון": פותח את המאגרים ראשון ותופס מה שנתפס.
  await _probeOpenStack('A');
  _probeLog('A', 'rss-mb-after-stack', _probeRssMb());

  // נותנים למנוע B להיטען לפני שמתחילים לשרוף.
  await Future<void>.delayed(const Duration(milliseconds: 1500));

  _probeLog('A', 'burn', 'start (2000ms sync)');
  final end = DateTime.now().add(const Duration(milliseconds: 2000));
  while (DateTime.now().isBefore(end)) {
    // חסימה סינכרונית מכוונת של ה-UI isolate.
  }
  _probeLog('A', 'burn', 'done');
}

@pragma('vm:entry-point')
void engineBTest(List<String> args) async {
  _probeLog('B', 'dart-thread-id', _probeThreadId());
  _probeLog('B', 'rss-mb-two-engines', _probeRssMb());

  // ⚠️ הלב של בדיקה 3. מנוע B הוא "החלון השני": מנסה לפתוח את אותם
  // מאגרים בזמן שמנוע A כבר מחזיק אותם, באותו תהליך. כל FAILED כאן הוא
  // מאגר שיחייב RPC ל-host בפרק 3, וכל ok הוא מאגר שאפשר לפתוח פר-חלון.
  // ממתינים די והותר כדי שמנוע A יסיים לפתוח הכול. התרחיש הנבדק הוא
  // "חלון ראשון עומד, המשתמש פותח שני" — לא מרוץ פתיחה מקבילי.
  await Future<void>.delayed(const Duration(seconds: 10));
  await _probeOpenStack('B');
  _probeLog('B', 'rss-mb-after-stack', _probeRssMb());

  var ticks = 0;
  var maxGapMs = 0;
  var last = DateTime.now();
  final done = Completer<void>();

  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    final now = DateTime.now();
    final gap = now.difference(last).inMilliseconds;
    if (gap > maxGapMs) maxGapMs = gap;
    last = now;
    ticks++;
    if (ticks >= 45) {
      timer.cancel();
      done.complete();
    }
  });

  await done.future;
  _probeLog('B', 'ticks', ticks);
  // ⚠️ המספר המכריע. ~100-150ms ⇒ ה-threads עצמאיים ומודל A שריד בלי
  // הדגל המיושן. ~2000ms ⇒ מנוע A חסם את מנוע B והתחרות אמיתית.
  _probeLog('B', 'max-gap-ms', maxGapMs);
  _probeLog('B', 'rss-mb-final', _probeRssMb());
  exit(0);
}

@pragma('vm:entry-point')
void brokerMain(List<String> args) async {
  final log = StringBuffer();
  void record(String step, Object? outcome) {
    final line = '[broker] $step = $outcome';
    log.writeln(line);
    debugPrint(line);
  }

  void flush() {
    try {
      final temp = Platform.environment['TEMP'] ?? r'C:\Users\Public';
      File(
        '$temp\\otzaria_broker_probe.log',
      ).writeAsStringSync(log.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  try {
    record('engine-alive', 'yes');

    // ⚠️ המדידה החשובה ביותר כאן. §3.3 של מפת הדרכים — הטיעון המרכזי נגד
    // מודל A — מבוסס על כך שב-3.44 ה-platform thread וה-UI thread ממוזגים,
    // ולכן N מנועים בתהליך אחד מתחרים על thread יחיד. ה-header של 3.47
    // אומר שברירת המחדל היא כבר thread נפרד. במקום להאמין לאחד מהם,
    // שואלים את מערכת ההפעלה: אם מזהה ה-thread של ה-Dart שונה מזה של
    // ה-thread שיצר את המנוע — הם אינם ממוזגים.
    try {
      final getCurrentThreadId = DynamicLibrary.open('kernel32.dll')
          .lookupFunction<Uint32 Function(), int Function()>(
            'GetCurrentThreadId',
          );
      record('dart-thread-id', getCurrentThreadId());
    } catch (e) {
      record('dart-thread-id', 'FAILED: $e');
    }

    // עלות המנוע לבדו, לפני שנפתח ולו מאגר אחד. ההפרש מול `rss-mb` בסוף
    // הוא עלות הנתונים. שני המספרים האלה הם מה שמכריע בין A ל-C1: ב-A
    // כל חלון נוסף עולה "מנוע", וב-C1 כל חלון נוסף עולה "תהליך".
    record(
      'rss-mb-engine-only',
      (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(0),
    );

    // 1. האם לולאת האירועים רצה בכלל בלי view.
    final timerDone = Completer<void>();
    Timer(const Duration(milliseconds: 50), () => timerDone.complete());
    await timerDone.future.timeout(const Duration(seconds: 5));
    record('timer', 'fired');

    await Future<void>.microtask(() {});
    record('microtask', 'ran');

    // 2. I/O — האם קריאת קובץ מסתיימת.
    final self = File(Platform.resolvedExecutable);
    record('file-io', '${await self.length()} bytes');

    // 3. rootBundle — ההכרעה בין C1 ל-C2. `tantivy_data_provider` תלוי בו,
    //    והוא זמין רק בתוך מנוע Flutter.
    WidgetsFlutterBinding.ensureInitialized();
    // שני נכסים: מניפסט בינארי שקיים בכל חבילה, ונכס אמיתי של האפליקציה.
    // שם נכס שגוי נכשל בדיוק כמו bundle שבור — ולכן בודקים שניים.
    try {
      final bin = await rootBundle.load('AssetManifest.bin');
      record('rootBundle:AssetManifest.bin', 'ok (${bin.lengthInBytes} bytes)');
    } catch (e) {
      record('rootBundle:AssetManifest.bin', 'FAILED: $e');
    }
    try {
      final changelog = await rootBundle.loadString('assets/יומן שינויים.md');
      record('rootBundle:app-asset', 'ok (${changelog.length} chars)');
    } catch (e) {
      record('rootBundle:app-asset', 'FAILED: $e');
    }

    // 4. מאגרי הנתונים — מה שה-broker אמור להחזיק בפועל.
    try {
      await Settings.init(cacheProvider: HiveCache());
      record('settings-init', 'ok');
    } catch (e) {
      record('settings-init', 'FAILED: $e');
    }
    try {
      await initHive();
      record('hive', 'ok');
    } catch (e) {
      record('hive', 'FAILED: $e');
    }
    try {
      await SqliteDataProvider.instance.initialize();
      record('sqlite', 'ok');
    } catch (e) {
      record('sqlite', 'FAILED: $e');
    }
    // מנוע החיפוש מגיע דרך FFI ודורש אתחול מפורש — `main()` עושה זאת
    // ב-`RustLib.init()`. בלעדיו הגישה לאינדקס נכשלת בהודעה שנראית כמו
    // כשל של המנוע חסר-view, ואינה כזו.
    try {
      await RustLib.init();
      record('rustlib-init', 'ok');
    } catch (e) {
      record('rustlib-init', 'FAILED: $e');
    }
    // אינדקס Tantivy — הרכיב האחרון שה-broker אמור להחזיק. הקונסטרוקטור
    // של TantivyDataProvider פותח את המנוע, ולכן עצם הגישה ל-`instance`
    // היא המדידה.
    try {
      final provider = TantivyDataProvider.instance;
      await provider.engine;
      final hits = await provider.countTexts('בראשית', const [], const []);
      record('tantivy', 'ok (engine open, $hits hits)');
    } catch (e) {
      record('tantivy', 'FAILED: $e');
    }
    record(
      'rss-mb',
      (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(0),
    );
  } catch (e, st) {
    record('fatal', '$e\n$st');
  } finally {
    flush();
    exit(0);
  }
}
