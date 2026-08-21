import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/connectivity_status_service.dart';
import 'package:otzaria/settings/tabs/about_settings_tab.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';

/// קולט את הכתובות שנשלחו לדפדפן, במקום לפתוח אותן באמת.
class _RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = [];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  const donationUrl = 'https://nedar.im/ezOd';
  final originalService = ConnectivityStatusService.instance;
  late _RecordingUrlLauncher launcher;

  setUp(() {
    launcher = _RecordingUrlLauncher();
    final previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);
  });

  tearDown(() => ConnectivityStatusService.instance = originalService);

  void useConnectivity({
    required bool offlineMode,
    required bool hasNetwork,
    Future<bool> Function()? networkProbe,
  }) {
    ConnectivityStatusService.instance = ConnectivityStatusService(
      offlineModeReader: () => offlineMode,
      networkProbe: networkProbe ?? () async => hasNetwork,
    );
  }

  Future<void> tapDonate(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutSettingsTab())),
    );
    final donateButton = find.text('נדרים+');
    await tester.ensureVisible(donateButton);
    await tester.pumpAndSettle();
    await tester.tap(donateButton);
    await tester.pumpAndSettle();
  }

  group('כפתור התרומה בנדרים+', () {
    testWidgets('בלי חיבור לאינטרנט — מציג את הוראות התרומה', (tester) async {
      useConnectivity(offlineMode: false, hasNetwork: false);

      await tapDonate(tester);

      expect(find.text('תרומה בנדרים+'), findsOneWidget);
      expect(find.text('ניתן לתרום מכל מכשיר בנדרים+'), findsOneWidget);
      expect(find.text('קרן צרכי הרבים - קרנות'), findsOneWidget);
      expect(find.text('7001976'), findsOneWidget);
      expect(find.text('אוצריא - מאגר תורני חינמי (146)'), findsOneWidget);
      expect(find.text(donationUrl), findsOneWidget);
      expect(find.text('העתק פרטים'), findsOneWidget);
      expect(launcher.launched, isEmpty);
    });

    testWidgets('לחיצה על הקישור בחלונית פותחת את דף התרומה', (tester) async {
      useConnectivity(offlineMode: false, hasNetwork: false);

      await tapDonate(tester);
      await tester.tap(find.text(donationUrl));
      await tester.pumpAndSettle();

      expect(launcher.launched, [donationUrl]);
    });

    testWidgets('במצב "ללא גישה לאינטרנט" בהגדרות — אותן הוראות', (
      tester,
    ) async {
      useConnectivity(offlineMode: true, hasNetwork: true);

      await tapDonate(tester);

      expect(find.text('תרומה בנדרים+'), findsOneWidget);
      expect(find.text('7001976'), findsOneWidget);
    });

    testWidgets('עם חיבור לאינטרנט — נפתח דף התרומה בלי חלונית', (
      tester,
    ) async {
      useConnectivity(offlineMode: false, hasNetwork: true);

      await tapDonate(tester);

      expect(find.text('תרומה בנדרים+'), findsNothing);
      expect(launcher.launched, [donationUrl]);
    });

    testWidgets('בדיקת רשת חדשה מונעת פתיחת דפדפן אחרי נפילת חיבור', (
      tester,
    ) async {
      var hasNetwork = true;
      useConnectivity(
        offlineMode: false,
        hasNetwork: true,
        networkProbe: () async => hasNetwork,
      );
      await ConnectivityStatusService.instance.snapshot();
      hasNetwork = false;

      await tapDonate(tester);

      expect(find.text('תרומה בנדרים+'), findsOneWidget);
      expect(launcher.launched, isEmpty);
    });
  });
}
