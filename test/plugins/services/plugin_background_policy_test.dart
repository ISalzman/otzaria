import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_background_policy.dart';

InstalledPlugin _plugin({
  bool enabled = true,
  bool granted = true,
  bool declarePermission = true,
  Map<String, dynamic>? startup,
}) {
  final manifest = PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': 'test.background',
    'name': 'Test',
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'permissions': [if (declarePermission) 'app.run_on_startup'],
    'contributes': {'startup': ?startup},
  });
  return InstalledPlugin(
    pluginId: manifest.id,
    name: manifest.name,
    version: manifest.version,
    installPath: '/plugins/test.background',
    entrypointPath: manifest.entrypoint,
    enabled: enabled,
    pinned: false,
    runOnStartupGranted: granted,
    manifest: manifest,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  test('legacy granted plugin uses the eager compatibility runner', () {
    expect(usesLegacyStartupRunner(_plugin()), isTrue);
  });

  test('declarative plugin never uses the eager compatibility runner', () {
    expect(
      usesLegacyStartupRunner(
        _plugin(
          startup: {
            'activationEvents': ['app.startup'],
          },
        ),
      ),
      isFalse,
    );
  });

  test('disabled, undeclared, or ungranted plugins are not eager', () {
    expect(usesLegacyStartupRunner(_plugin(enabled: false)), isFalse);
    expect(usesLegacyStartupRunner(_plugin(granted: false)), isFalse);
    expect(
      usesLegacyStartupRunner(_plugin(declarePermission: false)),
      isFalse,
    );
  });
}
