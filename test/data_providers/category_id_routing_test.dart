import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/book_locator.dart';
import 'package:otzaria/data/data_providers/book_composite_key.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/data/data_providers/file_system_library_provider.dart';
import 'package:otzaria/data/data_providers/library_provider.dart';
import 'package:otzaria/data/data_providers/library_provider_manager.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';

class _FakeProvider implements LibraryProvider {
  final String _providerId;
  final String _displayName;
  final String _sourceIndicator;
  final Set<BookCompositeKey> _availableKeys;
  final Map<BookCompositeKey, List<Link>> _linksByBook;

  _FakeProvider({
    required String providerId,
    required String displayName,
    required String sourceIndicator,
    Set<BookCompositeKey>? availableKeys,
    Map<BookCompositeKey, List<Link>>? linksByBook,
  })  : _providerId = providerId,
        _displayName = displayName,
        _sourceIndicator = sourceIndicator,
        _availableKeys = availableKeys ?? {},
        _linksByBook = linksByBook ?? {};

  @override
  String get providerId => _providerId;

  @override
  String get displayName => _displayName;

  @override
  String get sourceIndicator => _sourceIndicator;

  @override
  int get priority => 1;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, List<Book>>> loadBooks(
      Map<String, Map<String, dynamic>> metadata) async {
    return {};
  }

  @override
  Future<bool> hasBook(String title, int categoryId, String fileType) async {
    final key = BookCompositeKey.create(
      title: title,
      categoryId: categoryId,
      fileType: fileType,
    );
    return _availableKeys.contains(key);
  }

  @override
  Future<String?> getBookText(
      String title, int categoryId, String fileType) async {
    return null;
  }

  @override
  Future<List<TocEntry>?> getBookToc(
      String title, int categoryId, String fileType) async {
    return null;
  }

  @override
  Future<Set<String>> getAvailableBookTitles() async {
    return _availableKeys.map((key) => key.toStorageKey()).toSet();
  }

  @override
  Future<Library> buildLibraryCatalog(
    Map<String, Map<String, dynamic>> metadata,
    String rootPath,
  ) async {
    return Library(categories: []);
  }

  @override
  Future<List<Link>> getAllLinksForBook(
      String title, int categoryId, String fileType) async {
    final key = BookCompositeKey.create(
      title: title,
      categoryId: categoryId,
      fileType: fileType,
    );
    return _linksByBook[key] ?? const [];
  }

  @override
  Future<String> getLinkContent(Link link) async {
    return '';
  }
}

void main() {
  final manager = LibraryProviderManager.instance;

  tearDown(() {
    manager.resetForTesting();
    DatabaseLibraryProvider.instance.clearCache();
    FileSystemLibraryProvider.instance.resetForTesting();
  });

  test('provider mapping by categoryId מזהה ספר DB ללא categoryPath', () async {
    final dbKey = BookCompositeKey.create(
        title: 'ספר בדיקה', categoryId: 12, fileType: 'txt');
    final dbProvider = _FakeProvider(
      providerId: 'database',
      displayName: 'DB',
      sourceIndicator: 'DB',
      availableKeys: {dbKey},
    );
    final fileProvider = _FakeProvider(
      providerId: 'file_system',
      displayName: 'Files',
      sourceIndicator: 'ק',
    );

    manager.seedMappingsForTesting(
      mapping: {dbKey: dbProvider},
      providers: [dbProvider, fileProvider],
    );

    final source = await manager.getBookDataSource(
      'ספר בדיקה',
      categoryId: 12,
      fileType: 'txt',
    );

    expect(source, 'DB');
  });

  test('getBookDataSource מחזיר DB לספר DB ו-ק לספר קבצים', () async {
    final dbKey = BookCompositeKey.create(
        title: 'ספר DB', categoryId: 1, fileType: 'txt');
    final fileKey = BookCompositeKey.create(
        title: 'ספר קבצים', categoryId: 2, fileType: 'txt');

    final dbProvider = _FakeProvider(
      providerId: 'database',
      displayName: 'DB',
      sourceIndicator: 'DB',
      availableKeys: {dbKey},
    );
    final fileProvider = _FakeProvider(
      providerId: 'file_system',
      displayName: 'Files',
      sourceIndicator: 'ק',
      availableKeys: {fileKey},
    );

    manager.seedMappingsForTesting(
      mapping: {
        dbKey: dbProvider,
        fileKey: fileProvider,
      },
      providers: [dbProvider, fileProvider],
    );

    final dbSource = await manager.getBookDataSource(
      'ספר DB',
      categoryId: 1,
      fileType: 'txt',
    );
    final fileSource = await manager.getBookDataSource(
      'ספר קבצים',
      categoryId: 2,
      fileType: 'txt',
    );

    expect(dbSource, 'DB');
    expect(fileSource, 'ק');
  });

  test('findCategoryPathForBook מחזיר נתיב קטגוריה מלא ולא מזהה מספרי',
      () async {
    final dbProvider = DatabaseLibraryProvider.instance;
    final key = BookCompositeKey.create(
        title: 'בראשית', categoryId: 101, fileType: 'txt');
    dbProvider.seedCacheForTesting(
      keys: [key],
      categoryIdToPath: {101: 'תנך, תורה'},
    );

    final categoryPath = await dbProvider.findCategoryPathForBook(
      'בראשית',
      categoryId: 101,
      fileType: 'txt',
    );

    expect(categoryPath, 'תנך, תורה');
    expect(categoryPath, isNot('101'));
  });

  test('isTanachPath מזהה נתיבי DB ונתיבי קבצים ישנים', () {
    expect(FileSystemData.isTanachPathForTesting('תנ"ך/תורה/בראשית'), isTrue);
    expect(
      FileSystemData.isTanachPathForTesting(
        r'C:\library\אוצריא\תנך\נביאים\ישעיהו.txt',
      ),
      isTrue,
    );
    expect(FileSystemData.isTanachPathForTesting('תנך, כתובים'), isTrue);
    expect(FileSystemData.isTanachPathForTesting('הלכה/רמב"ם'), isFalse);
    expect(
      FileSystemData.isTanachPathForTesting('error: book path not found'),
      isFalse,
    );
  });

  test('titleToPath עבור ספרי DB מחזיר נתיב קטגוריה תקין', () async {
    final fsKey = BookCompositeKey.create(
      title: 'ספר קבצים',
      categoryId: 11,
      fileType: 'txt',
    ).toStorageKey();
    final dbKey = BookCompositeKey.create(
      title: 'ספר DB',
      categoryId: 12,
      fileType: 'txt',
    ).toStorageKey();

    final titleToPath = await FileSystemData.buildTitleToPathMap(
      fileSystemKeyToPath: {
        fsKey: r'C:\tmp\book.txt',
      },
      databaseKeys: [dbKey],
      resolveDatabaseCategoryPath: (_) async => 'תנך, תורה',
    );

    expect(titleToPath['ספר DB'], 'תנך, תורה');
    expect(titleToPath['ספר קבצים'], r'C:\tmp\book.txt');
  });

  test('BookLocator מאתר ספר קובץ לפי קטגוריה עם key חדש', () async {
    final tempDir = await Directory.systemTemp.createTemp('otzaria_locator_');
    final testFile = File(
      '${tempDir.path}${Platform.pathSeparator}ספר איתור.txt',
    );
    await testFile.writeAsString('שורה 1\nשורה 2');

    final categoryPath = 'הלכה';
    final categoryId = categoryPath.hashCode;
    final storageKey = BookCompositeKey.create(
      title: 'ספר איתור',
      categoryId: categoryId,
      fileType: 'txt',
    ).toStorageKey();

    FileSystemLibraryProvider.instance.seedKeyToPathForTesting(
      keyToPath: {storageKey: testFile.path},
      categoryIdToPath: {categoryId: categoryPath},
      libraryPath: tempDir.path,
    );

    final library = Library(categories: []);
    final category = Category(
      title: categoryPath,
      description: '',
      shortDescription: '',
      order: 0,
      subCategories: [],
      books: [],
      parent: library,
    );

    final location = await BookLocator.locateBook(
      'ספר איתור',
      category: category,
    );

    expect(location, isNotNull);
    expect(location!.source, BookSource.fileSystem);
    expect(location.filePath, testFile.path);

    await tempDir.delete(recursive: true);
  });

  test('TextBook.links טוען קישורים עבור ספר DB לפי categoryId', () async {
    final link = Link(
      heRef: 'קישור בדיקה',
      index1: 1,
      path2: 'מפרש בדיקה',
      index2: 2,
      connectionType: 'reference',
    );
    final key = BookCompositeKey.create(
        title: 'ספר מקשר', categoryId: 7, fileType: 'txt');

    final dbProvider = _FakeProvider(
      providerId: 'database',
      displayName: 'DB',
      sourceIndicator: 'DB',
      availableKeys: {key},
      linksByBook: {
        key: [link],
      },
    );

    manager.seedMappingsForTesting(
      mapping: {key: dbProvider},
      providers: [dbProvider],
    );

    final book = TextBook(
      title: 'ספר מקשר',
      categoryId: 7,
      fileType: 'txt',
    );

    final links = await book.links;
    expect(links.length, 1);
    expect(links.first.path2, 'מפרש בדיקה');
  });
}
