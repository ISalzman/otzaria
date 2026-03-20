import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/combined_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/tabs/tabs_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TabsBloc side-by-side', () {
    setUp(() async {
      await Settings.init(cacheProvider: _MemoryCacheProvider());
    });

    test('יוצר CombinedTab עם עותקים נפרדים של הטאבים', () async {
      final bloc = TabsBloc(repository: _FakeTabsRepository());
      final rightTab = _createTextTab('ספר ימין');
      final leftTab = _createTextTab('ספר שמאל');

      bloc.add(AddTab(rightTab));
      bloc.add(AddTab(leftTab));
      await Future<void>.delayed(Duration.zero);

      bloc.add(EnableSideBySideMode(rightTab: rightTab, leftTab: leftTab));
      await Future<void>.delayed(Duration.zero);

      final currentState = bloc.state;
      expect(currentState.tabs, hasLength(1));
      expect(currentState.currentTab, isA<CombinedTab>());

      final combinedTab = currentState.currentTab! as CombinedTab;
      expect(combinedTab.rightTab, isNot(same(rightTab)));
      expect(combinedTab.leftTab, isNot(same(leftTab)));

      final combinedRightTab = combinedTab.rightTab as TextBookTab;
      final combinedLeftTab = combinedTab.leftTab as TextBookTab;

      expect(combinedRightTab.scrollController,
          isNot(same(rightTab.scrollController)));
      expect(combinedLeftTab.scrollController,
          isNot(same(leftTab.scrollController)));

      await bloc.close();
      rightTab.dispose();
      leftTab.dispose();
    });

    test('פירוק CombinedTab מחזיר טאבים חדשים ולא את מופעי המשנה הישנים',
        () async {
      final bloc = TabsBloc(repository: _FakeTabsRepository());
      final rightTab = _createTextTab('ספר א');
      final leftTab = _createTextTab('ספר ב');

      bloc.add(AddTab(rightTab));
      bloc.add(AddTab(leftTab));
      await Future<void>.delayed(Duration.zero);

      bloc.add(EnableSideBySideMode(rightTab: rightTab, leftTab: leftTab));
      await Future<void>.delayed(Duration.zero);

      final combinedTab = bloc.state.currentTab! as CombinedTab;
      final combinedRightTab = combinedTab.rightTab;
      final combinedLeftTab = combinedTab.leftTab;

      bloc.add(const DisableSideBySideMode());
      await Future<void>.delayed(Duration.zero);

      final restoredState = bloc.state;
      expect(restoredState.tabs, hasLength(2));
      expect(restoredState.tabs[0], isNot(same(combinedRightTab)));
      expect(restoredState.tabs[1], isNot(same(combinedLeftTab)));

      await bloc.close();
      rightTab.dispose();
      leftTab.dispose();
    });
  });
}

TextBookTab _createTextTab(String title) {
  return TextBookTab(
    book: TextBook(title: title),
    index: 0,
  );
}

class _FakeTabsRepository extends TabsRepository {
  List<Map<String, dynamic>> _tabsJson = const [];
  int _currentTabIndex = 0;
  SideBySideMode? _sideBySideMode;

  @override
  List<OpenedTab> loadTabs() =>
      _tabsJson.map((tab) => TextBookTab.fromJson(tab)).toList();

  @override
  int loadCurrentTabIndex() => _currentTabIndex;

  @override
  SideBySideMode? loadSideBySideMode() => _sideBySideMode;

  @override
  void saveTabs(
    List<OpenedTab> tabs,
    int currentTabIndex, [
    SideBySideMode? sideBySideMode,
  ]) {
    _tabsJson = tabs
        .map<Map<String, dynamic>>((tab) => tab.toJson())
        .toList(growable: false);
    _currentTabIndex = currentTabIndex;
    _sideBySideMode = sideBySideMode;
  }
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
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> removeAll() async {
    _values.clear();
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String? value) async {
    _values[key] = value;
  }
}
