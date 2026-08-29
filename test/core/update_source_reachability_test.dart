import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/core/update_source_reachability.dart';

void main() {
  group('isUpdateSourceReachable', () {
    test('תשובה עם חתימת GitHub — נגיש', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{}',
          200,
          headers: {
            'x-github-request-id': 'ABC',
          },
        ),
      );
      expect(await isUpdateSourceReachable(client: client), isTrue);
    });

    // דף החסימה של רשת מסוננת מוחזר כ-200 תקין למראה — בלי בדיקת החתימה הוא
    // נספר כ"יש רשת" והכשל מוצג למשתמש כשגיאה של אוצריא (issue #1027).
    test('דף חסימה ללא חתימת GitHub — לא נגיש', () async {
      final client = MockClient(
        (_) async => http.Response('<html>חסום</html>', 200),
      );
      expect(await isUpdateSourceReachable(client: client), isFalse);
    });

    test('הגבלת קצב של GitHub נחשבת נגישה — לא כשל רשת', () async {
      final client = MockClient(
        (_) async => http.Response(
          '{}',
          403,
          headers: {
            'x-github-request-id': 'ABC',
          },
        ),
      );
      expect(await isUpdateSourceReachable(client: client), isTrue);
    });

    test('כשל רשת — לא נגיש', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('אין רשת'),
      );
      expect(await isUpdateSourceReachable(client: client), isFalse);
    });

    test('תקיעה נחתכת ב-timeout ואינה משאירה את הקורא ממתין', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      expect(
        await isUpdateSourceReachable(
          client: client,
          timeout: const Duration(milliseconds: 20),
        ),
        isFalse,
      );
    });
  });
}
