import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_dev_watch_service.dart';

class _FakePluginRegistryRepository extends PluginRegistryRepository {
  @override
  Future<List<InstalledPlugin>> getAllPlugins() async => const [];

  @override
  Future<List<InstalledPlugin>> getDevelopmentPlugins() async => const [];

  @override
  Future<InstalledPlugin?> getPlugin(String pluginId) async => null;

  @override
  Future<void> setPermission(
    String pluginId,
    String permission,
    bool granted,
  ) async {}

  @override
  Future<List<PluginPermissionGrant>> getPluginPermissions(
    String pluginId,
  ) async =>
      const [];
}

class _TestPluginDevWatchService extends PluginDevWatchService {
  final StreamController<PluginDevFsChange> controller =
      StreamController<PluginDevFsChange>.broadcast();

  @override
  Stream<PluginDevFsChange> get events => controller.stream;

  @override
  void syncWatchers(List<InstalledPlugin> devPlugins) {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('לא מנסה להוסיף אירוע חדש אחרי סגירת PluginSystemBloc', () async {
    final watchService = _TestPluginDevWatchService();
    final bloc = PluginSystemBloc(
      repository: _FakePluginRegistryRepository(),
      devWatchService: watchService,
    );

    Object? asyncError;

    await runZonedGuarded(() async {
      watchService.controller.add(
        PluginDevFsChange(
          pluginId: 'dev.plugin',
          manifestChanged: true,
          changedPaths: const {'manifest.json'},
        ),
      );

      await bloc.close();
      await Future<void>.delayed(Duration.zero);
    }, (error, stackTrace) {
      asyncError = error;
    });

    expect(asyncError, isNull);
    await watchService.controller.close();
  });
}
