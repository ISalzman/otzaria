import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_store_link_parser.dart';

void main() {
  group('PluginStoreLinkParser', () {
    test('parses valid plugin install links', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse(
          'otzaria://plugin/install?url=https%3A%2F%2Fexample.com%2Fplugin.otzplugin',
        ),
      );

      expect(request, isNotNull);
      expect(
        request!.downloadUri.toString(),
        'https://example.com/plugin.otzplugin',
      );
      expect(request.forceOverwrite, isFalse);
    });

    test('parses overwrite flag from install links', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse(
          'otzaria://plugin/install?url=https%3A%2F%2Fexample.com%2Fplugin.otzplugin&overwrite=true',
        ),
      );

      expect(request, isNotNull);
      expect(request!.forceOverwrite, isTrue);
    });

    test('keeps a same-origin callback context', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse(
          'otzaria://plugin/install?url=https%3A%2F%2Fstore.example.com%2Fplugin.otzplugin&token=one-time&callback=https%3A%2F%2Fstore.example.com%2Fapi%2Finstall-result',
        ),
      );

      expect(request?.reportContext?.token, 'one-time');
      expect(
        request?.reportContext?.callbackUrl.toString(),
        'https://store.example.com/api/install-result',
      );
    });

    test('drops a callback from a different origin', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse(
          'otzaria://plugin/install?url=https%3A%2F%2Fstore.example.com%2Fplugin.otzplugin&token=one-time&callback=https%3A%2F%2Fevil.example.com%2Fcollect',
        ),
      );

      expect(request, isNotNull);
      expect(request!.reportContext, isNull);
    });

    test('rejects links without download url', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse('otzaria://plugin/install'),
      );

      expect(request, isNull);
    });

    test('rejects non-http download links', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse(
          'otzaria://plugin/install?url=file%3A%2F%2FC%3A%2Ftemp%2Fplugin.otzplugin',
        ),
      );

      expect(request, isNull);
    });

    test('rejects unrelated otzaria links', () {
      final request = PluginStoreLinkParser.parseUri(
        Uri.parse('otzaria://note?id=123'),
      );

      expect(request, isNull);
    });
  });

  group('PluginStoreLinkParser.appendAppVersion', () {
    Uri append(String url, String? version) =>
        PluginStoreLinkParser.appendAppVersion(Uri.parse(url), version);

    test('adds the app version to a store download link', () {
      expect(
        append(
          'https://otzaria.org/api/plugins/abc123/download',
          '0.9.96',
        ).toString(),
        'https://otzaria.org/api/plugins/abc123/download?appVersion=0.9.96',
      );
    });

    test('keeps existing query parameters', () {
      final result = append(
        'https://www.otzaria.org/api/plugins/abc123/download?it=token-value',
        '1.0',
      );

      expect(result.queryParameters['it'], 'token-value');
      expect(result.queryParameters['appVersion'], '1.0');
    });

    test('does not leak the app version to a non-store host', () {
      const url = 'https://example.com/api/plugins/abc123/download';

      expect(append(url, '0.9.96').toString(), url);
    });

    test('leaves a link that already pins an explicit version', () {
      const url = 'https://otzaria.org/api/plugins/abc123@1.2.0/download';

      expect(append(url, '0.9.96').toString(), url);
    });

    test('leaves a pending-preview link', () {
      const url = 'https://otzaria.org/api/plugins/abc123/download?pending=1';

      expect(append(url, '0.9.96').toString(), url);
    });

    test('leaves a link that is not a plugin download', () {
      const url = 'https://otzaria.org/api/plugins/abc123/image';

      expect(append(url, '0.9.96').toString(), url);
    });

    test('leaves the link when the app version is missing or malformed', () {
      const url = 'https://otzaria.org/api/plugins/abc123/download';

      expect(append(url, null).toString(), url);
      expect(append(url, '').toString(), url);
      expect(append(url, 'not-a-version').toString(), url);
    });

    test('accepts a prerelease app version', () {
      expect(
        append(
          'https://otzaria.org/api/plugins/abc123/download',
          '0.9.96-beta.1',
        ).queryParameters['appVersion'],
        '0.9.96-beta.1',
      );
    });
  });
}
