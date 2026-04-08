import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_installer_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

class FakePluginRegistryRepository extends Mock
    implements PluginRegistryRepository {
  @override
  Future<InstalledPlugin?> getPlugin(String id) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'Otzaria',
    packageName: 'com.otzaria.app',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  group('PluginInstallerService', () {
    late Directory tempDir;
    late PluginInstallerService installer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('otzaria_installer_test_');
      installer = PluginInstallerService(
        repository: FakePluginRegistryRepository(),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('prepareInstall accepts app.user_email.read permission', () async {
      final archivePath = p.join(tempDir.path, 'plugin.zip');
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'schemaVersion': 1,
              'id': 'test.user.email.plugin',
              'version': '1.0.0',
              'name': 'User Email Plugin',
              'entrypoint': 'index.html',
              'permissions': ['app.user_email.read'],
            }),
          ),
        )
        ..addFile(ArchiveFile.string('index.html', '<html></html>'));

      final zipData = ZipEncoder().encode(archive);
      expect(zipData, isNotNull);
      File(archivePath).writeAsBytesSync(zipData);

      final preparedInstall = await installer.prepareInstall(archivePath);

      expect(preparedInstall.manifest.permissions, ['app.user_email.read']);
      await Directory(preparedInstall.tempDirPath).delete(recursive: true);
    });
  });
}
