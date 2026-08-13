import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_in_book_search_service.dart';

void main() {
  group('provider ownership', () {
    late PluginInBookSearchService service;
    late Map<String, dynamic> request;

    setUp(() {
      service = PluginInBookSearchService.forTesting(
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
        externalId: 1,
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
          pages: const [3, 7],
          query: 'שלום',
        ),
        isTrue,
      );
      final matches = await search;
      expect(matches.pages, [3, 7]);
    });

    test('הסרת תוסף מפנה את הספק ומכשילה בקשה פעילה', () async {
      service.register('hebrewbooks', 'owner');
      final search = service.search(
        provider: 'hebrewbooks',
        externalId: 1,
        query: 'שלום',
      );
      final expectation = expectLater(search, throwsStateError);

      service.removePlugin('owner');

      await expectation;
      expect(service.hasProvider('hebrewbooks'), isFalse);
    });
  });
}
