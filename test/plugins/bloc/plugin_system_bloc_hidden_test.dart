import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';

PluginManifest _manifest(String id) {
  return PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': id,
    'name': id,
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'contributes': {
      'toolTab': {'title': id},
    },
  });
}

InstalledPlugin _plugin({
  required String id,
  bool hiddenFromTools = false,
}) {
  return InstalledPlugin(
    pluginId: id,
    name: id,
    version: '1.0.0',
    installPath: '/x/$id',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: true,
    hiddenFromTools: hiddenFromTools,
    manifest: _manifest(id),
    installedAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

/// Fake repo: tracks hidden writes and simulates them in subsequent reads.
class _FakeRepo implements PluginRegistryRepository {
  List<InstalledPlugin> plugins;
  final List<({String pluginId, bool hidden})> hiddenCalls = [];

  _FakeRepo(this.plugins);

  @override
  Future<void> updateHiddenState(String pluginId, bool hiddenFromTools) async {
    hiddenCalls.add((pluginId: pluginId, hidden: hiddenFromTools));
    // הדמיית הזרימה הנכונה: ה-DB מקבל את העדכון וקריאה הבאה ל-getAllPlugins
    // מחזירה את התוסף עם הדגל החדש.
    plugins = plugins
        .map((p) => p.pluginId == pluginId
            ? p.copyWith(hiddenFromTools: hiddenFromTools)
            : p)
        .toList();
  }

  @override
  Future<List<InstalledPlugin>> getAllPlugins() async => List.of(plugins);

  @override
  Future<List<InstalledPlugin>> getDevelopmentPlugins() async => [];

  @override
  Future<InstalledPlugin?> getPlugin(String id) async => null;

  @override
  Future<List<PluginPermissionGrant>> getPluginPermissions(String id) async =>
      [];

  @override
  Future<bool?> getPermission(String id, String perm) async => null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('PluginSystemBloc SetPluginHiddenRequested handler', () {
    test('forwards (pluginId, true) to repository.updateHiddenState', () async {
      final repo = _FakeRepo([_plugin(id: 'p1'), _plugin(id: 'p2')]);
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      bloc.add(const SetPluginHiddenRequested(
        pluginId: 'p1',
        hidden: true,
      ));

      await expectLater(
          bloc.stream, emitsThrough(isA<PluginSystemLoaded>()));

      expect(repo.hiddenCalls, hasLength(1));
      expect(repo.hiddenCalls.single.pluginId, 'p1');
      expect(repo.hiddenCalls.single.hidden, isTrue);
    });

    test('forwards (pluginId, false) — the "show again" direction', () async {
      final repo = _FakeRepo([_plugin(id: 'p1', hiddenFromTools: true)]);
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      bloc.add(const SetPluginHiddenRequested(
        pluginId: 'p1',
        hidden: false,
      ));

      await expectLater(
          bloc.stream, emitsThrough(isA<PluginSystemLoaded>()));

      expect(repo.hiddenCalls.single.hidden, isFalse);
    });

    test(
        'after the event, the next PluginSystemLoaded reflects hiddenFromTools '
        'in the visible/pinned/nav-rail getters', () async {
      final repo = _FakeRepo([
        _plugin(id: 'visible'),
        _plugin(id: 'will-hide'),
      ]);
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      bloc.add(const SetPluginHiddenRequested(
        pluginId: 'will-hide',
        hidden: true,
      ));

      // ה-handler מפעיל LoadPlugins פנימי — אנו ממתינים ל-Loaded הסופי
      // *אחרי* שהדגל כבר משוקף ב-state.
      PluginSystemLoaded? lastLoaded;
      await for (final s in bloc.stream) {
        if (s is PluginSystemLoaded) {
          lastLoaded = s;
          // ה-handler גורם לטעינה אחת בלבד אחרי hidden-update
          if (!s.plugins.any((p) =>
              p.pluginId == 'will-hide' && !p.hiddenFromTools)) {
            break;
          }
        }
      }

      expect(lastLoaded, isNotNull);
      expect(
        lastLoaded!.visiblePlugins.map((p) => p.pluginId),
        equals(['visible']),
        reason: 'hidden plugin must drop out of visiblePlugins',
      );
      expect(
        lastLoaded.pinnedPlugins.map((p) => p.pluginId),
        equals(['visible']),
        reason: 'hidden plugin must drop out of pinnedPlugins (tools tabs)',
      );
    });

    test(
        'toggling the same plugin twice writes both directions in order',
        () async {
      final repo = _FakeRepo([_plugin(id: 'p1')]);
      final bloc = PluginSystemBloc(repository: repo);
      addTearDown(bloc.close);

      bloc.add(const SetPluginHiddenRequested(pluginId: 'p1', hidden: true));
      bloc.add(const SetPluginHiddenRequested(pluginId: 'p1', hidden: false));

      // מחכים ש-bloc יתעצב — שני events ⇒ שתי טעינות לפחות, אבל אנחנו
      // רק רוצים לוודא ששתי כתיבות בוצעו לפי הסדר.
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repo.hiddenCalls.length, 2);
      expect(repo.hiddenCalls[0].hidden, isTrue);
      expect(repo.hiddenCalls[1].hidden, isFalse);
    });
  });
}
