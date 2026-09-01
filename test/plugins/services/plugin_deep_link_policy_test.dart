import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_deep_link_policy.dart';

NavigationAction _action({
  NavigationType? type,
  bool? hasGesture,
  String uri = 'otzaria://open/book/5',
}) {
  return NavigationAction(
    request: URLRequest(url: WebUri(uri)),
    isForMainFrame: true,
    navigationType: type,
    hasGesture: hasGesture,
  );
}

void main() {
  group('isUserActivated', () {
    test('לחיצה על קישור — LINK_ACTIVATED (Windows/macOS/iOS)', () {
      expect(
        PluginDeepLinkPolicy.isUserActivated(
          _action(type: NavigationType.LINK_ACTIVATED),
        ),
        isTrue,
      );
    });

    test('מחווה ב-Android — hasGesture', () {
      expect(
        PluginDeepLinkPolicy.isUserActivated(_action(hasGesture: true)),
        isTrue,
      );
    });

    test('ניווט יזום-סקריפט נחסם', () {
      expect(
        PluginDeepLinkPolicy.isUserActivated(
          _action(type: NavigationType.OTHER, hasGesture: false),
        ),
        isFalse,
      );
    });

    test('בהיעדר מידע על מקור הניווט — נחסם', () {
      expect(PluginDeepLinkPolicy.isUserActivated(_action()), isFalse);
    });
  });

  group('resolveDispatchUri', () {
    test('פתיחת ספר מותרת', () {
      expect(
        PluginDeepLinkPolicy.resolveDispatchUri(
          Uri.parse('otzaria://open/book/12?index=3'),
        ),
        isNotNull,
      );
    });

    test('אינדוקס מחדש חסום', () {
      expect(
        PluginDeepLinkPolicy.resolveDispatchUri(
          Uri.parse('otzaria://library/reindex'),
        ),
        isNull,
      );
    });

    test('דוח מידע מערכת חסום', () {
      expect(
        PluginDeepLinkPolicy.resolveDispatchUri(Uri.parse('otzaria://info')),
        isNull,
      );
    });

    test('התקנה מקובץ מקומי חסומה', () {
      expect(
        PluginDeepLinkPolicy.resolveDispatchUri(
          Uri.parse(r'otzaria://plugin/install-local?path=C:\x\y.otzplugin'),
        ),
        isNull,
      );
    });

    test('כתובת שאינה מוכרת לראוטר מוחזרת כ-null', () {
      expect(
        PluginDeepLinkPolicy.resolveDispatchUri(
          Uri.parse('otzaria://nonsense/x'),
        ),
        isNull,
      );
    });
  });

  group('dispatchUriForUserNavigation', () {
    const installUri =
        'otzaria://plugin/install?url=https%3A%2F%2Fexample.com%2Fplugin.otzplugin';

    test('התקנת תוסף מרחוק מחייבת מחוות משתמש', () {
      expect(
        PluginDeepLinkPolicy.dispatchUriForUserNavigation(
          Uri.parse(installUri),
          _action(type: NavigationType.OTHER, hasGesture: false),
        ),
        isNull,
      );
    });

    test('התקנת תוסף מרחוק מותרת לאחר לחיצה', () {
      expect(
        PluginDeepLinkPolicy.dispatchUriForUserNavigation(
          Uri.parse(installUri),
          _action(type: NavigationType.LINK_ACTIVATED),
        ),
        Uri.parse(installUri),
      );
    });
  });
}
