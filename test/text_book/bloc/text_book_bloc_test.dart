import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextBookBloc', () {
    setUp(() async {
      await Settings.init(cacheProvider: _MemoryCacheProvider());
    });

    test('בתצוגה רגילה טוען את כל הקישורים ולא חלון חלקי', () async {
      final repository = _FakeTextBookRepository();
      final bloc =
          _createBloc(repository: repository, showPageShapeView: false);

      bloc.add(
        const LoadContent(
          fontSize: 20,
          showSplitView: false,
          removeNikud: false,
          loadCommentators: false,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.getBookLinksCalls, 1);
      expect(repository.getBookLinksInRangeCalls, 0);

      await bloc.close();
    });

    test('בצורת הדף טוען רק חלון קישורים נראה', () async {
      final repository = _FakeTextBookRepository();
      final bloc = _createBloc(repository: repository, showPageShapeView: true);

      bloc.add(
        const LoadContent(
          fontSize: 20,
          showSplitView: false,
          removeNikud: false,
          loadCommentators: false,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.getBookLinksCalls, 0);
      expect(repository.getBookLinksInRangeCalls, 1);

      await bloc.close();
    });
  });
}

TextBookBloc _createBloc({
  required _FakeTextBookRepository repository,
  required bool showPageShapeView,
}) {
  return TextBookBloc(
    repository: repository,
    initialState: TextBookInitial.named(
      TextBook(title: 'בראשית'),
      10,
      false,
      const [],
      searchMode: SearchMode.exact,
      showPageShapeView: showPageShapeView,
    ),
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}

class _FakeTextBookRepository extends TextBookRepository {
  _FakeTextBookRepository() : super(fileSystem: FileSystemData.instance);

  int getBookLinksCalls = 0;
  int getBookLinksInRangeCalls = 0;

  @override
  Future<String> getBookContent(TextBook book) async {
    return List.generate(40, (index) => 'שורה $index').join('\n');
  }

  @override
  Future<List<TocEntry>> getTableOfContents(TextBook book) async {
    return const [];
  }

  @override
  Future<List<Link>> getBookLinks(TextBook book) async {
    getBookLinksCalls++;
    return const [];
  }

  @override
  Future<List<Link>> getBookLinksInRange(
    TextBook book, {
    required int startIndex,
    required int endIndex,
  }) async {
    getBookLinksInRangeCalls++;
    return const [];
  }

  @override
  Future<List<String>> getAvailableCommentators(TextBook book) async {
    return const [];
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
