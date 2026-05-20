import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_manifest_validator.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PluginManifestValidator', () {
    test('accepts current app version with prerelease suffix', () async {
      final tempDir = await Directory.systemTemp.createTemp('plugin_validator_');
      addTearDown(() => tempDir.delete(recursive: true));
      await File(p.join(tempDir.path, 'index.html')).writeAsString('<html></html>');

      final manifest = PluginManifest(
        schemaVersion: 1,
        id: 'test.validator.prerelease',
        name: 'Validator Plugin',
        version: '1.0.0',
        description: '',
        author: '',
        homepage: '',
        entrypoint: 'index.html',
        minAppVersion: '1.0.0',
        sdkVersion: '1.x',
        permissions: const [],
        networkEnabled: false,
        networkAllowlist: const [],
        toolTabTitle: 'Validator Plugin',
        toolTabOrder: 900,
        defaultPinned: false,
        publishedDataTypes: const [],
      );

      await expectLater(
        PluginManifestValidator.validateManifest(
          manifest: manifest,
          directoryPath: tempDir.path,
          currentAppVersion: '1.0.0-beta',
        ),
        completes,
      );
    });
  });
}
