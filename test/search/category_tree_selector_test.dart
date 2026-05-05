import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/search/search_scope_preferences.dart';
import 'package:otzaria/search/view/category_tree_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CategoryTreeSelector', () {
    setUp(() async {
      await Settings.init(cacheProvider: _MemoryCacheProvider());
    });

    testWidgets('לחיצה על איפוס קוראת ל-callback הייעודי', (tester) async {
      Set<String>? lastSelection;
      var resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => LibraryBloc(),
              child: CategoryTreeSelector(
                selectedFacets: const {'/תנ״ך'},
                onSelectionChanged: (selection) {
                  lastSelection = selection;
                },
                onResetSelection: () {
                  resetCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('איפוס בחירה'), findsOneWidget);

      await tester.tap(find.byTooltip('איפוס בחירה'));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      expect(lastSelection, isNull);
    });

    testWidgets('כיבוי חיפוש בכל הקטגוריות מפיץ scope ידני ריק', (tester) async {
      final emittedSelections = <Set<String>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => LibraryBloc(),
              child: SearchScopeSelector(
                selectedFacets: const {'/'},
                onSelectionChanged: (selection) {
                  emittedSelections.add(selection);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(emittedSelections, isNotEmpty);
      expect(emittedSelections.last, isEmpty);
    });

    testWidgets('האתחול לא מפעיל setState בזמן build אצל הווידג׳ט ההורה',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => LibraryBloc(),
              child: const _SearchScopeHost(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('איפוס בחירה ידנית משאיר את הסוויץ׳ כבוי ושומר מצב ידני ריק',
        (tester) async {
      final emittedSelections = <Set<String>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => LibraryBloc(),
              child: SearchScopeSelector(
                selectedFacets: const {'/תנ״ך'},
                onSelectionChanged: (selection) {
                  emittedSelections.add(selection);
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('איפוס בחירה'));
      await tester.pumpAndSettle();

      expect(emittedSelections, isNotEmpty);
      expect(emittedSelections.last, isEmpty);

      final loaded = SearchScopePreferences.load();
      expect(loaded.searchAllCategories, isFalse);
      expect(loaded.manualFacets, isEmpty);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('מצב ידני ריק נשמר גם אחרי rebuild של ההורה', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => LibraryBloc(),
              child: const _SearchScopeHost(initialSelection: {'/תנ״ך'}),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('איפוס בחירה'));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });
  });
}

class _SearchScopeHost extends StatefulWidget {
  final Set<String> initialSelection;

  const _SearchScopeHost({this.initialSelection = const {'/'}});

  @override
  State<_SearchScopeHost> createState() => _SearchScopeHostState();
}

class _SearchScopeHostState extends State<_SearchScopeHost> {
  late Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set<String>.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return SearchScopeSelector(
      selectedFacets: _selection,
      onSelectionChanged: (selection) {
        setState(() {
          _selection = selection;
        });
      },
    );
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
