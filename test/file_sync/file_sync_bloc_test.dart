import 'dart:async';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/file_sync/bloc/file_sync_bloc.dart';
import 'package:otzaria/file_sync/bloc/file_sync_event.dart';
import 'package:otzaria/file_sync/repository/file_sync_repository.dart';
import 'package:otzaria/file_sync/bloc/file_sync_state.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/work_status/work_status_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
    await Settings.setValue<bool>(SettingsRepository.keyOfflineMode, false);
    await Settings.setValue<bool>(
      SettingsRepository.keySoftwareAndBookUpdatesEnabled,
      true,
    );
  });

  group('FileSyncBloc', () {
    test('StartSync בזמן syncing מתעלם מהאירוע השני', () async {
      final fetchStarted = Completer<void>();
      final fetchRelease = Completer<void>();
      final repo = _SlowRepository(
        onFetchStarted: fetchStarted,
        fetchRelease: fetchRelease,
      );
      final workCubit = WorkStatusCubit();
      final bloc = FileSyncBloc(repository: repo, workStatusCubit: workCubit);

      final states = <FileSyncState>[];
      final sub = bloc.stream.listen(states.add);

      // ריצה ראשונה — מתחילה ותיתקע על getCurrentLibraryVersion
      bloc.add(const StartSync());
      await fetchStarted.future;

      expect(bloc.state.status, FileSyncStatus.syncing,
          reason: 'הריצה הראשונה אמורה להיות בסטטוס syncing');

      final stateCountBeforeSecond = states.length;

      // ריצה שניה — אמורה להתעלם כי כבר syncing
      bloc.add(const StartSync());
      await Future.delayed(Duration.zero);

      expect(states.length, stateCountBeforeSecond,
          reason: 'StartSync נוסף בזמן syncing לא צריך לפלוט state חדש');
      expect(bloc.state.status, FileSyncStatus.syncing);

      // שחרור הריצה הראשונה
      fetchRelease.complete();
      await Future.delayed(const Duration(milliseconds: 30));

      await sub.cancel();
      await bloc.close();
      workCubit.close();
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SlowRepository extends FileSyncRepository {
  final Completer<void> onFetchStarted;
  final Completer<void> fetchRelease;

  _SlowRepository({
    required this.onFetchStarted,
    required this.fetchRelease,
  }) : super(githubOwner: 'test', repositoryName: 'test');

  @override
  Future<int> getCurrentLibraryVersion() async {
    onFetchStarted.complete();
    await fetchRelease.future;
    return 133;
  }

  @override
  Future<List<DiffReleaseAsset>> fetchAvailableDiffAssets() async => [];
}

class _MemoryCacheProvider extends CacheProvider {
  final Map<String, Object?> _values = {};

  @override
  Future<void> init() async {}

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Set getKeys() => _values.keys.toSet();

  @override
  bool? getBool(String key, {bool? defaultValue}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  double? getDouble(String key, {double? defaultValue}) =>
      _values[key] as double? ?? defaultValue;

  @override
  int? getInt(String key, {int? defaultValue}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key, {String? defaultValue}) =>
      _values[key] as String? ?? defaultValue;

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value is T) return value;
    return defaultValue;
  }

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> removeAll() async => _values.clear();

  @override
  Future<void> setBool(String key, bool? value) async => _values[key] = value;

  @override
  Future<void> setDouble(String key, double? value) async =>
      _values[key] = value;

  @override
  Future<void> setInt(String key, int? value) async => _values[key] = value;

  @override
  Future<void> setObject<T>(String key, T? value) async =>
      _values[key] = value;

  @override
  Future<void> setString(String key, String? value) async =>
      _values[key] = value;
}
