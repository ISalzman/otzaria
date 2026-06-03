import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/core/http_client_registry.dart';
import 'package:otzaria/plugins/services/plugin_file_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('plugin_dl_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  bool allowAll(Uri _) => true;

  PluginFileDownloadService serviceReturning(
    List<int> body, {
    int status = 200,
  }) {
    final client = MockClient((request) async {
      return http.Response.bytes(body, status);
    });
    return PluginFileDownloadService(client: client);
  }

  test('מוריד קובץ לתיקיית היעד ומחזיר נתיב ושם', () async {
    final service = serviceReturning([1, 2, 3, 4]);
    final result = await service.downloadToDownloads(
      Uri.parse('https://github.com/Owner/Repo/releases/latest/download/a.zip'),
      isAllowed: allowAll,
      targetDir: tempDir,
    );

    expect(result.filename, 'a.zip');
    expect(p.basename(result.path), 'a.zip');
    final file = File(result.path);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
  });

  test('שם הקובץ נגזר מה-URL כשלא סופק filename', () async {
    final service = serviceReturning([9]);
    final result = await service.downloadToDownloads(
      Uri.parse('https://github.com/Owner/Repo/releases/latest/download/x.zip'),
      isAllowed: allowAll,
      targetDir: tempDir,
    );
    expect(result.filename, 'x.zip');
  });

  test('filename מפורש גובר על שם ה-URL', () async {
    final service = serviceReturning([9]);
    final result = await service.downloadToDownloads(
      Uri.parse('https://github.com/Owner/Repo/releases/latest/download/x.zip'),
      isAllowed: allowAll,
      filename: 'custom.zip',
      targetDir: tempDir,
    );
    expect(result.filename, 'custom.zip');
  });

  test('אינו דורס קובץ קיים — מוסיף סיומת מספרית', () async {
    await File(p.join(tempDir.path, 'a.zip')).writeAsBytes([0]);
    final service = serviceReturning([1, 2]);
    final result = await service.downloadToDownloads(
      Uri.parse('https://github.com/Owner/Repo/releases/latest/download/a.zip'),
      isAllowed: allowAll,
      targetDir: tempDir,
    );
    expect(result.filename, 'a (1).zip');
    expect(await File(p.join(tempDir.path, 'a.zip')).readAsBytes(), [0]);
  });

  test('שם קובץ עם תווי נתיב מנוקה למניעת path traversal', () async {
    final service = serviceReturning([7]);
    final result = await service.downloadToDownloads(
      Uri.parse('https://github.com/Owner/Repo/releases/latest/download/a.zip'),
      isAllowed: allowAll,
      filename: '../../evil.zip',
      targetDir: tempDir,
    );
    // basename בלבד — בלי רכיבי ../
    expect(result.filename, 'evil.zip');
    expect(p.dirname(result.path), tempDir.path);
  });

  test('זורק שגיאה בקוד סטטוס שאינו 2xx', () async {
    final service = serviceReturning([], status: 404);
    expect(
      () => service.downloadToDownloads(
        Uri.parse(
            'https://github.com/Owner/Repo/releases/latest/download/a.zip'),
        isAllowed: allowAll,
        targetDir: tempDir,
      ),
      throwsA(isA<Exception>()),
    );
  });

  // isAllowed המדמה את הרשימה הגלובלית: רק github.com מורשה ישירות (ה-CDN
  // אינו ברשימה הגלובלית בכוונה).
  bool globalAllowsGithubOnly(Uri uri) => uri.host == 'github.com';

  // isRedirectAllowed המדמה את isGithubReleaseRedirectAllowed: מתיר redirect
  // ל-CDN רק כש-hop הקודם הוא github.com.
  bool redirectAllowsCdnFromGithub(Uri previous, Uri target) =>
      target.host == 'release-assets.githubusercontent.com' &&
      (previous.host == 'github.com' ||
          previous.host == 'release-assets.githubusercontent.com');

  test('עוקב אחרי redirect ל-CDN מותר (רק כיעד redirect) ומוריד', () async {
    const cdn =
        'https://release-assets.githubusercontent.com/abc/a.zip?token=x';
    final client = MockClient((request) async {
      if (request.url.host == 'github.com') {
        return http.Response('', 302, headers: {'location': cdn});
      }
      return http.Response.bytes([5, 6, 7], 200);
    });
    final service = PluginFileDownloadService(client: client);

    final result = await service.downloadToDownloads(
      Uri.parse('https://github.com/Owner/Repo/releases/latest/download/a.zip'),
      isAllowed: globalAllowsGithubOnly,
      isRedirectAllowed: redirectAllowsCdnFromGithub,
      targetDir: tempDir,
    );

    expect(await File(result.path).readAsBytes(), [5, 6, 7]);
    // שם הקובץ נגזר מה-URL ההתחלתי, לא מיעד ה-CDN.
    expect(result.filename, 'a.zip');
  });

  test('חוסם redirect ליעד שאינו ב-allowlist (לא עוקף את ה-allowlist)',
      () async {
    var hitEvil = false;
    final client = MockClient((request) async {
      if (request.url.host == 'github.com') {
        return http.Response('', 302,
            headers: {'location': 'https://evil.example.com/a.zip'});
      }
      hitEvil = true;
      return http.Response.bytes([0], 200);
    });
    final service = PluginFileDownloadService(client: client);

    await expectLater(
      service.downloadToDownloads(
        Uri.parse(
            'https://github.com/Owner/Repo/releases/latest/download/a.zip'),
        isAllowed: globalAllowsGithubOnly,
        isRedirectAllowed: redirectAllowsCdnFromGithub,
        targetDir: tempDir,
      ),
      throwsA(isA<Exception>()),
    );
    // ודא שהבקשה ליעד האסור מעולם לא יצאה.
    expect(hitEvil, isFalse);
  });

  test('חוסם גישה ישירה ל-CDN ככתובת התחלתית (ללא redirect)', () async {
    var hit = false;
    final client = MockClient((request) async {
      hit = true;
      return http.Response.bytes([0], 200);
    });
    final service = PluginFileDownloadService(client: client);

    await expectLater(
      service.downloadToDownloads(
        Uri.parse('https://release-assets.githubusercontent.com/abc/a.zip'),
        isAllowed: globalAllowsGithubOnly,
        isRedirectAllowed: redirectAllowsCdnFromGithub,
        targetDir: tempDir,
      ),
      throwsA(isA<Exception>()),
    );
    // ה-CDN אינו נגיש ישירות — isRedirectAllowed חל רק על יעדי redirect.
    expect(hit, isFalse);
  });

  test('dispose מסיר את ה-closer מ-HttpClientRegistry', () async {
    final service = serviceReturning([1]);
    final before = HttpClientRegistry.registeredCount;
    service.dispose();
    expect(HttpClientRegistry.registeredCount, before - 1);
  });
}
