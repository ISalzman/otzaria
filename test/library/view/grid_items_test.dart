import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/library/view/grid_items.dart';
import 'package:otzaria/models/books.dart';

class _FakeFileSystemData extends FileSystemData {
  _FakeFileSystemData(this.source);

  final String source;

  @override
  Future<String> getBookDataSource(
    String title, {
    int? categoryId,
    String? fileType = 'txt',
  }) async {
    return source;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileSystemData originalFileSystemData;

  setUpAll(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
    originalFileSystemData = FileSystemData.instance;
  });

  setUp(() {
    FileSystemData.instance = _FakeFileSystemData('ק');
  });

  tearDown(() {
    FileSystemData.instance = originalFileSystemData;
  });

  Widget buildTestWidget({
    required Book book,
    bool showTopics = false,
    double width = 260,
  }) {
    return MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: width,
            child: BookGridItem(
              book: book,
              showTopics: showTopics,
              onBookClickCallback: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('מציג tooltip כשהכותרת נחתכת עם ellipsis בתוך המילה האחרונה',
      (tester) async {
    final book = PdfBook(
      title: 'ספר עם שם ארוך מאודמאודשנחתךבאמצעהמילה',
      path: r'C:\library\folder\book.pdf',
      categoryPath: 'קטגוריה/פנימית/ארוכה',
    );

    await tester.pumpWidget(buildTestWidget(book: book, width: 180));
    await tester.pumpAndSettle();

    expect(find.byType(Tooltip), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.preferBelow, isFalse);
    expect(tooltip.verticalOffset, 18);
  });

  testWidgets('מציג tooltip כשהנתיב או הנושאים נחתכים גם אם הכותרת קצרה',
      (tester) async {
    const topics = 'נתיב ארוך מאוד מאוד שנחתך בתצוגת הספריה ומחייב tooltip';
    final book = PdfBook(
      title: 'א',
      path: r'C:\library\folder\book.pdf',
      topics: topics,
      categoryPath: 'קטגוריה ראשית, קטגוריה משנית, נתיב מלא ארוך',
    );

    await tester.pumpWidget(
      buildTestWidget(book: book, showTopics: true, width: 220),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(topics), findsOneWidget);
    expect(find.byTooltip('א'), findsNothing);
  });

  testWidgets('מציג פעולת מחיקה עבור ספר שמקורו ב-DB', (tester) async {
    FileSystemData.instance = _FakeFileSystemData('DB');

    final book =
        TextBook(title: 'ספר DB לבדיקה', categoryId: 42, isUserBook: true);

    await tester.pumpWidget(buildTestWidget(book: book));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(FluentIcons.more_vertical_24_regular),
      findsOneWidget,
    );
  });

  testWidgets('לא מציג פעולת מחיקה עבור ספר שמקורו בקבצים', (tester) async {
    FileSystemData.instance = _FakeFileSystemData('ק');

    final book = TextBook(title: 'ספר קבצים לבדיקה', categoryId: 7);

    await tester.pumpWidget(buildTestWidget(book: book));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(FluentIcons.more_vertical_24_regular),
      findsNothing,
    );
  });

  testWidgets('מציג את אייקון הקובץ ותפריט האפשרויות בטור אנכי',
      (tester) async {
    FileSystemData.instance = _FakeFileSystemData('DB');

    final book =
        TextBook(title: 'ספר לבדיקה', categoryId: 11, isUserBook: true);

    await tester.pumpWidget(buildTestWidget(book: book));
    await tester.pumpAndSettle();

    final fileIconCenter = tester.getCenter(
      find.byIcon(FluentIcons.document_text_24_regular),
    );
    final menuIconCenter = tester.getCenter(
      find.byIcon(FluentIcons.more_vertical_24_regular),
    );

    expect((fileIconCenter.dx - menuIconCenter.dx).abs(), lessThan(2));
    expect(menuIconCenter.dy, greaterThan(fileIconCenter.dy));
  });

  testWidgets('מציג אייקון תיקייה בקו regular ולא filled', (tester) async {
    final category = Category(
      title: 'קטגוריה',
      description: '',
      shortDescription: '',
      order: 0,
      subCategories: [],
      books: [],
      parent: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 260,
              child: CategoryGridItem(
                category: category,
                onCategoryClickCallback: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.folder_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.folder_24_filled), findsNothing);
  });
}
