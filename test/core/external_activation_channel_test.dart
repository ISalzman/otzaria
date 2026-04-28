import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/external_activation_channel.dart';

void main() {
  group('ExternalActivationChannel', () {
    test('normalizeUriStrings returns a single trimmed URI string', () {
      expect(
        ExternalActivationChannel.normalizeUriStrings(
          ' otzaria://plugin/install?url=https://example.com/plugin.otzplugin ',
        ),
        [
          'otzaria://plugin/install?url=https://example.com/plugin.otzplugin',
        ],
      );
    });

    test('normalizeUriStrings filters empty and non-string list entries', () {
      expect(
        ExternalActivationChannel.normalizeUriStrings(
          <Object?>[
            'otzaria://plugin/install?url=https://example.com/one.otzplugin',
            '   ',
            null,
            12,
            'otzaria://plugin/install?url=https://example.com/two.otzplugin',
          ],
        ),
        [
          'otzaria://plugin/install?url=https://example.com/one.otzplugin',
          'otzaria://plugin/install?url=https://example.com/two.otzplugin',
        ],
      );
    });

    test('normalizeUriStrings ignores unsupported payloads', () {
      expect(
        ExternalActivationChannel.normalizeUriStrings(
          <String, String>{'uri': 'otzaria://plugin/install'},
        ),
        isEmpty,
      );
    });
  });
}
