import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/plugins/services/plugin_download_service.dart';

void main() {
  group('PluginDownloadService.downloadPluginArchive', () {
    late List<Uri> requested;

    setUp(() => requested = []);

    PluginDownloadService serviceReturning(
      List<http.Response> responses,
    ) {
      var index = 0;
      return PluginDownloadService(
        client: MockClient((request) async {
          requested.add(request.url);
          return responses[index++];
        }),
      );
    }

    test('asks the store for a version matching the running app', () async {
      final service = serviceReturning([http.Response('archive-bytes', 200)]);

      final path = await service.downloadPluginArchive(
        Uri.parse('https://otzaria.org/api/plugins/abc123/download'),
        appVersion: '0.9.96',
      );
      addTearDown(() => service.cleanupDownloadedArchive(path));

      expect(requested.single.queryParameters['appVersion'], '0.9.96');
      expect(await File(path).readAsString(), 'archive-bytes');
    });

    test('falls back to the latest version when none is compatible', () async {
      // 404 מהחנות = אין גרסה תואמת. הנסיגה מורידה את הגרסה האחרונה כדי
      // שבדיקת המניפסט תסביר למשתמש את דרישת התאימות.
      final service = serviceReturning([
        http.Response('{"error":"No plugin version supports..."}', 404),
        http.Response('latest-bytes', 200),
      ]);

      final path = await service.downloadPluginArchive(
        Uri.parse('https://otzaria.org/api/plugins/abc123/download'),
        appVersion: '0.9.96',
      );
      addTearDown(() => service.cleanupDownloadedArchive(path));

      expect(requested, hasLength(2));
      expect(requested.last.queryParameters.containsKey('appVersion'), isFalse);
      expect(await File(path).readAsString(), 'latest-bytes');
    });

    test('does not retry when no app version was added', () async {
      final service = serviceReturning([http.Response('missing', 404)]);

      await expectLater(
        service.downloadPluginArchive(
          Uri.parse('https://example.com/plugin.otzplugin'),
          appVersion: '0.9.96',
        ),
        throwsA(isA<Exception>()),
      );
      expect(requested, hasLength(1));
    });
  });
}
