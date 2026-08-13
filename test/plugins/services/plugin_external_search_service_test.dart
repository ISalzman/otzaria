import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_external_search_service.dart';

void main() {
  group('sanitizeIndex', () {
    final service = PluginExternalSearchService.instance;

    test('מקבל רשומות [id, hits] ו-[id, hits, category]', () {
      final entries = service.sanitizeIndexForTesting([
        [43558, 7, '/שו"ת'],
        [12, 0],
      ])!;
      expect(entries, hasLength(2));
      expect(entries[0].id, 43558);
      expect(entries[0].hits, 7);
      expect(entries[0].categoryPath, '/שו"ת');
      expect(entries[1].categoryPath, isNull);
    });

    test('זורק רשומות פגומות ומנקה נתיבים לא תקינים', () {
      final entries = service.sanitizeIndexForTesting([
        'לא רשומה',
        [0, 5],
        [5, -1],
        [5],
        [5, 1, 2, 3],
        [7, 3, 'בלי לוכסן'],
        [8, 3, '/'],
        [9, 3, '/הלכה\u0000'],
      ])!;
      expect(entries.map((e) => e.id), [7, 8, 9]);
      expect(entries[0].categoryPath, isNull);
      expect(entries[1].categoryPath, isNull);
      expect(entries[2].categoryPath, '/הלכה');
    });

    test('null נשאר null — עדכון בלי אינדקס אינו מוחק אינדקס קודם', () {
      expect(service.sanitizeIndexForTesting(null), isNull);
      expect(service.sanitizeIndexForTesting(const []), isEmpty);
    });
  });

  group('provider ownership', () {
    late PluginExternalSearchService service;
    late Map<String, dynamic> request;

    setUp(() {
      service = PluginExternalSearchService.forTesting(
        (pluginId, topic, payload, {preferBackground = false}) async {
          request = payload;
        },
      );
    });

    test('תוסף אחר אינו יכול לדרוס ספק רשום', () {
      service.register('hebrewbooks', 'owner');

      expect(
        () => service.register('hebrewbooks', 'attacker'),
        throwsStateError,
      );
      expect(service.hasProvider('hebrewbooks'), isTrue);
    });

    test('רק בעל הספק יכול לענות לבקשה', () async {
      service.register('hebrewbooks', 'owner');
      final search = service.search(
        provider: 'hebrewbooks',
        query: 'שלום',
      );
      await Future<void>.delayed(Duration.zero);
      final requestId = request['requestId'] as String;
      var completed = false;
      unawaited(search.then((_) => completed = true));

      expect(service.respond('attacker', requestId), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      expect(
        service.respond(
          'owner',
          requestId,
          results: const [
            {'title': 'ספר', 'externalId': 1},
          ],
          totalBooks: 1,
        ),
        isTrue,
      );
      final page = await search;
      expect(page.results.single.title, 'ספר');
    });

    test('הסרת תוסף מפנה את הספק ומכשילה בקשה פעילה', () async {
      service.register('hebrewbooks', 'owner');
      final search = service.search(
        provider: 'hebrewbooks',
        query: 'שלום',
      );
      final expectation = expectLater(search, throwsStateError);

      service.removePlugin('owner');

      await expectation;
      expect(service.hasProvider('hebrewbooks'), isFalse);
    });
  });
}
