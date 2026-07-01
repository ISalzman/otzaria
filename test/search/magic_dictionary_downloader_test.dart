import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/search/magic_dictionary_downloader.dart';

void main() {
  String latestJson({String tag = 'v0.3.0', bool withAsset = true}) {
    return jsonEncode({
      'tag_name': tag,
      'assets': [
        {
          'name': 'readme.txt',
          'browser_download_url':
              'https://github.com/kdroidFilter/SeforimMagicIndexer/releases/download/$tag/readme.txt',
          'size': 12,
        },
        if (withAsset)
          {
            'name': 'lexical.db',
            'browser_download_url':
                'https://github.com/kdroidFilter/SeforimMagicIndexer/releases/download/$tag/lexical.db',
            'size': 57122816,
          },
      ],
    });
  }

  test('fetchLatestRelease בוחר את נכס lexical.db ומחזיר תג וגודל', () async {
    final client = MockClient((request) async {
      expect(
          request.url.toString(), MagicDictionaryDownloader.latestReleaseApi);
      return http.Response(latestJson(), 200);
    });
    final dl = MagicDictionaryDownloader(client: client);
    addTearDown(dl.dispose);

    final release = await dl.fetchLatestRelease();
    expect(release.tag, 'v0.3.0');
    expect(release.downloadUrl.path, endsWith('/lexical.db'));
    expect(release.sizeBytes, 57122816);
  });

  test('fetchLatestRelease זורק כשאין נכס lexical.db', () async {
    final client = MockClient((request) async {
      return http.Response(latestJson(withAsset: false), 200);
    });
    final dl = MagicDictionaryDownloader(client: client);
    addTearDown(dl.dispose);

    expect(dl.fetchLatestRelease(), throwsA(isA<Exception>()));
  });

  test('fetchLatestRelease עוקב אחרי redirect', () async {
    var hop = 0;
    final client = MockClient((request) async {
      if (hop++ == 0) {
        return http.Response('', 302, headers: {
          'location': 'https://cdn.example/redirected-latest',
        });
      }
      return http.Response(latestJson(), 200);
    });
    final dl = MagicDictionaryDownloader(client: client);
    addTearDown(dl.dispose);

    final release = await dl.fetchLatestRelease();
    expect(release.tag, 'v0.3.0');
    expect(hop, 2); // ניגש פעמיים: המקור ואז יעד ה-redirect.
  });

  test('fetchLatestRelease זורק על קוד סטטוס שאינו 2xx', () async {
    final client =
        MockClient((request) async => http.Response('rate limited', 403));
    final dl = MagicDictionaryDownloader(client: client);
    addTearDown(dl.dispose);

    expect(dl.fetchLatestRelease(), throwsA(isA<Exception>()));
  });
}
