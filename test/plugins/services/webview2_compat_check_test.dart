import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/webview2_compat_check.dart';

void main() {
  group('WebView2CompatCheck.parseMajor', () {
    test('returns major from standard version string', () {
      expect(WebView2CompatCheck.parseMajor('143.0.3650.139'), 143);
      expect(WebView2CompatCheck.parseMajor('148.0.3967.70'), 148);
      expect(WebView2CompatCheck.parseMajor('150.1.2.3'), 150);
    });

    test('returns major from version without dots', () {
      expect(WebView2CompatCheck.parseMajor('143'), 143);
    });

    test('returns null for empty or null', () {
      expect(WebView2CompatCheck.parseMajor(null), null);
      expect(WebView2CompatCheck.parseMajor(''), null);
    });

    test('returns null for non-numeric prefix', () {
      expect(WebView2CompatCheck.parseMajor('abc.0.0.0'), null);
    });
  });

  group('WebView2CompatCheck.parseWindowsBuild', () {
    test('parses "Build NNNN" form', () {
      expect(
        WebView2CompatCheck.parseWindowsBuild('Windows 10 10.0 (Build 19045)'),
        19045,
      );
      expect(
        WebView2CompatCheck.parseWindowsBuild('Windows 11 10.0 (Build 22631)'),
        22631,
      );
    });

    test('parses dotted "10.0.NNNNN" form', () {
      expect(WebView2CompatCheck.parseWindowsBuild('10.0.18362'), 18362);
      expect(WebView2CompatCheck.parseWindowsBuild('10.0.22000'), 22000);
    });

    test('prefers explicit Build over dotted', () {
      // אם גם וגם — Build הוא הפורמט המהימן יותר
      expect(
        WebView2CompatCheck.parseWindowsBuild(
            '10.0.18362 (Build 19045)'),
        19045,
      );
    });

    test('returns null for unrecognized string', () {
      expect(WebView2CompatCheck.parseWindowsBuild('Linux 5.10'), null);
      expect(WebView2CompatCheck.parseWindowsBuild(''), null);
    });
  });

  group('WebView2CompatCheck.evaluate', () {
    test('supports modern Windows with old WebView2 (v143)', () {
      // המקרה ש-P2 הצביע עליו: לא לחסום מכונות חדשות עם v143
      final r = WebView2CompatCheck.evaluate(
        version: '143.0.3650.139',
        windowsBuild: 22631, // Windows 11
      );
      expect(r.supported, true);
      expect(r.reason, WebView2CompatReason.modernWindows);
    });

    test('supports modern Windows with old WebView2 even at threshold', () {
      final r = WebView2CompatCheck.evaluate(
        version: '143.0.3650.139',
        windowsBuild: 19041, // Win10 2004 exactly
      );
      expect(r.supported, true);
    });

    test('blocks old Windows + old WebView2 (the crashing combo)', () {
      // המקרה שאומת בלוגים: Win10 1903 + WebView2 v143
      final r = WebView2CompatCheck.evaluate(
        version: '143.0.3650.139',
        windowsBuild: 18362, // Win10 1903
      );
      expect(r.supported, false);
      expect(r.reason, WebView2CompatReason.oldWindowsAndOldWebView2);
      expect(r.majorVersion, 143);
      expect(r.windowsBuild, 18362);
    });

    test('supports old Windows when WebView2 is recent (v144+)', () {
      final r = WebView2CompatCheck.evaluate(
        version: '148.0.3967.70',
        windowsBuild: 18362,
      );
      expect(r.supported, true);
      expect(r.reason, WebView2CompatReason.oldWindowsButRecentWebView2);
    });

    test('blocks when WebView2 not installed', () {
      final r1 = WebView2CompatCheck.evaluate(
        version: null,
        windowsBuild: 22631,
      );
      expect(r1.supported, false);
      expect(r1.reason, WebView2CompatReason.webView2NotInstalled);

      final r2 = WebView2CompatCheck.evaluate(
        version: '',
        windowsBuild: 19045,
      );
      expect(r2.supported, false);
      expect(r2.reason, WebView2CompatReason.webView2NotInstalled);
    });

    test('treats unknown Windows build as modern (fail-open)', () {
      // עדיף לא לחסום מכונה שאיננו יודעים את ה-build שלה
      final r = WebView2CompatCheck.evaluate(
        version: '143.0.3650.139',
        windowsBuild: null,
      );
      expect(r.supported, true);
      expect(r.reason, WebView2CompatReason.modernWindows);
    });

    test('exactly at boundary: v144 on old Windows is allowed', () {
      final r = WebView2CompatCheck.evaluate(
        version: '144.0.0.0',
        windowsBuild: 18363, // Win10 1909
      );
      expect(r.supported, true);
    });

    test('exactly at boundary: v143 on Win10 1909 is blocked', () {
      final r = WebView2CompatCheck.evaluate(
        version: '143.99.99.99',
        windowsBuild: 18363,
      );
      expect(r.supported, false);
      expect(r.reason, WebView2CompatReason.oldWindowsAndOldWebView2);
    });
  });

  group('WebView2CompatResult.reasonForUser', () {
    test('produces meaningful message for not-installed', () {
      const r = WebView2CompatResult(
        supported: false,
        version: null,
        majorVersion: null,
        windowsBuild: 22631,
        reason: WebView2CompatReason.webView2NotInstalled,
      );
      expect(r.reasonForUser, contains('Microsoft Edge WebView2 Runtime'));
    });

    test('produces meaningful message for the crashing combo', () {
      const r = WebView2CompatResult(
        supported: false,
        version: '143.0.3650.139',
        majorVersion: 143,
        windowsBuild: 18362,
        reason: WebView2CompatReason.oldWindowsAndOldWebView2,
      );
      final msg = r.reasonForUser;
      expect(msg, contains('143.0.3650.139'));
      expect(msg, contains('18362'));
    });

    test('produces meaningful message when probe failed', () {
      const r = WebView2CompatResult(
        supported: false,
        version: null,
        majorVersion: null,
        windowsBuild: 18362,
        reason: WebView2CompatReason.probeFailed,
        error: 'IPC timeout',
      );
      final msg = r.reasonForUser;
      expect(msg, contains('IPC timeout'));
    });
  });
}
