// בדיקות ל-WebViewEnvironmentHolder.isRuntimeAvailable — נקודת ההחלטה
// המשותפת לכל המסלולים שמחליטים אם לבנות WebView2 (טאב תוסף, host רקע,
// pre-warm). הבדיקות מאמתות את ה-override hook שדרכו שאר המסלולים נשלטים
// בטסטים, שכן הקריאה האמיתית תלויה ב-platform channel שאינו זמין בטסט.

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/webview_environment_holder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => WebViewEnvironmentHolder.debugOverrideRuntimeAvailable(null));

  group('WebViewEnvironmentHolder.isRuntimeAvailable', () {
    test('override true → מחזיר true', () async {
      WebViewEnvironmentHolder.debugOverrideRuntimeAvailable(true);
      expect(await WebViewEnvironmentHolder.isRuntimeAvailable(), isTrue);
    });

    test('override false → מחזיר false', () async {
      WebViewEnvironmentHolder.debugOverrideRuntimeAvailable(false);
      expect(await WebViewEnvironmentHolder.isRuntimeAvailable(), isFalse);
    });

    test('איפוס override מחזיר את הבדיקה להתנהגות הרגילה', () async {
      WebViewEnvironmentHolder.debugOverrideRuntimeAvailable(false);
      WebViewEnvironmentHolder.debugOverrideRuntimeAvailable(null);
      // ללא override, על פלטפורמה שאינה Windows התוצאה היא true; ב-Windows
      // ללא platform channel הקריאה נכשלת ומוחזר false. בשני המקרים אסור
      // שהקריאה תזרוק חריגה.
      await expectLater(
        WebViewEnvironmentHolder.isRuntimeAvailable(),
        completes,
      );
    });
  });
}
