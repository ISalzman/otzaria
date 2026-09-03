import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/widgets/plugin_webview_focus_restorer.dart';

/// בחזרה לחלון (Alt-Tab) המערכת מוסרת את המקלדת לחלון Flutter ולא ל-WebView
/// של התוסף. העוטף מבקש שחזור — ורק כשהפוקוס של Flutter יושב בתוך ה-WebView.
void main() {
  late TestWidgetsFlutterBinding binding;

  setUp(() {
    binding = TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  Future<void> leaveAndReturn(WidgetTester tester) async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  Widget host({
    required FocusNode inside,
    required FocusNode outside,
    required VoidCallback onRestore,
  }) {
    return MaterialApp(
      home: Column(
        children: [
          Focus(focusNode: outside, child: const SizedBox(height: 10)),
          PluginWebViewFocusRestorer(
            onRestore: onRestore,
            child: Focus(focusNode: inside, child: const SizedBox(height: 10)),
          ),
        ],
      ),
    );
  }

  testWidgets('הפוקוס בתוך ה-WebView — חזרה לחלון מבקשת שחזור', (tester) async {
    final inside = FocusNode();
    final outside = FocusNode();
    addTearDown(inside.dispose);
    addTearDown(outside.dispose);
    var restores = 0;

    await tester.pumpWidget(
      host(inside: inside, outside: outside, onRestore: () => restores++),
    );
    inside.requestFocus();
    await tester.pump();

    await leaveAndReturn(tester);

    expect(restores, 1);
  });

  testWidgets('הפוקוס מחוץ ל-WebView — אין גזילת מקלדת', (tester) async {
    final inside = FocusNode();
    final outside = FocusNode();
    addTearDown(inside.dispose);
    addTearDown(outside.dispose);
    var restores = 0;

    await tester.pumpWidget(
      host(inside: inside, outside: outside, onRestore: () => restores++),
    );
    outside.requestFocus();
    await tester.pump();

    await leaveAndReturn(tester);

    expect(restores, 0);
  });

  testWidgets('עזיבת החלון לבדה אינה מבקשת שחזור', (tester) async {
    final inside = FocusNode();
    final outside = FocusNode();
    addTearDown(inside.dispose);
    addTearDown(outside.dispose);
    var restores = 0;

    await tester.pumpWidget(
      host(inside: inside, outside: outside, onRestore: () => restores++),
    );
    inside.requestFocus();
    await tester.pump();

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(restores, 0);
  });

  testWidgets('חזרה נוספת לחלון מבקשת שחזור נוסף', (tester) async {
    final inside = FocusNode();
    final outside = FocusNode();
    addTearDown(inside.dispose);
    addTearDown(outside.dispose);
    var restores = 0;

    await tester.pumpWidget(
      host(inside: inside, outside: outside, onRestore: () => restores++),
    );
    inside.requestFocus();
    await tester.pump();

    await leaveAndReturn(tester);
    await leaveAndReturn(tester);

    expect(restores, 2);
  });
}
