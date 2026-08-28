import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/plugin_tab_page.dart';

/// כשל היצירה מגיע ב-stream גלובלי, וכמה WebViewים נוצרים במקביל (מארח הרקע
/// וטאבים). הבדיקות מוודאות שכשל מנותב רק לטאב שביקש אותו URL.
void main() {
  const tabUrl = 'file:///plugins/a/index.html';
  const otherUrl = 'file:///plugins/b/index.html';

  group('shouldHandleCreationFailure', () {
    test('שתי יצירות מקבילות — רק בעל ה-URL התואם מגיב', () {
      // הטאב של תוסף A ממתין; הכשל שייך למופע של תוסף B.
      expect(
        shouldHandleCreationFailure(
          failureUrl: otherUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: false,
        ),
        isFalse,
      );

      expect(
        shouldHandleCreationFailure(
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: false,
        ),
        isTrue,
      );
    });

    test('טאב שה-WebView שלו כבר נוצר אינו מוחלף במסך שגיאה', () {
      expect(
        shouldHandleCreationFailure(
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: true,
          alreadyFailed: false,
        ),
        isFalse,
      );
    });

    test('כשל שכבר הוצג אינו מטופל שוב', () {
      expect(
        shouldHandleCreationFailure(
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: true,
        ),
        isFalse,
      );
    });

    test('אירוע בלי URL עדיין מטופל — אחרת החיווי היה נעלם', () {
      for (final unknown in <String?>[null, '']) {
        expect(
          shouldHandleCreationFailure(
            failureUrl: unknown,
            expectedUrl: tabUrl,
            isCreated: false,
            alreadyFailed: false,
          ),
          isTrue,
          reason: 'URL לא ידוע ($unknown) חייב להמשיך להציג את השגיאה',
        );
      }
    });
  });
}
