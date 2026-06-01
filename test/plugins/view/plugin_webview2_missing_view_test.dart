// בדיקות widget למסך ההכוונה שמופיע כש-WebView2 Runtime אינו מותקן.
//
// המסך מציג למשתמש הסבר, כפתור להורדת WebView2, וכפתור "בדוק שוב"
// שמריץ מחדש את בדיקת הזמינות (callback onRetry).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/plugin_webview2_missing_view.dart';

void main() {
  group('PluginWebView2MissingView', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('מציג כותרת והסבר על הצורך ב-WebView2', (tester) async {
      await tester.pumpWidget(
        wrap(PluginWebView2MissingView(onRetry: () {})),
      );

      expect(find.text('להפעלת התוסף נדרש רכיב WebView2'), findsOneWidget);
      expect(find.textContaining('WebView2 של Microsoft'), findsOneWidget);
    });

    testWidgets('מציג כפתור הורדה וכפתור בדיקה מחדש', (tester) async {
      await tester.pumpWidget(
        wrap(PluginWebView2MissingView(onRetry: () {})),
      );

      expect(find.text('הורד WebView2'), findsOneWidget);
      expect(find.text('בדוק שוב'), findsOneWidget);
    });

    testWidgets('לחיצה על "בדוק שוב" מפעילה את onRetry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        wrap(PluginWebView2MissingView(onRetry: () => retried = true)),
      );

      await tester.tap(find.text('בדוק שוב'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
