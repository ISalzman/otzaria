import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('רכיב WebView של Linux נפתר מאותו checkout כמו ממשק הפלטפורמה', () {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(configFile.readAsStringSync()) as Map;
    final packages = (config['packages'] as List).cast<Map>();

    Uri checkoutOf(String name) {
      final package = packages.singleWhere((entry) => entry['name'] == name);
      return configFile.uri
          .resolve(package['rootUri'] as String)
          .resolve('../');
    }

    expect(
      checkoutOf('flutter_inappwebview_linux'),
      checkoutOf('flutter_inappwebview_platform_interface'),
      reason: 'גרסת pub.dev חסרה את תיקוני WPE שבמאגר Otzaria',
    );
  });
}
