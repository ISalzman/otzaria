import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/library_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/migration/core/models/category.dart' as db_models;
import 'package:otzaria/migration/core/models/book.dart' as db_models;
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:otzaria/settings/custom_folders/custom_folder.dart';
import 'package:otzaria/settings/settings_repository.dart';

/// Library provider that loads books from the SQLite database.
class DatabaseLibraryProvider implements LibraryProvider {
  final SqliteDataProvider _sqliteProvider = SqliteDataProvider.instance;
  final Set<String> _cachedTitles = {};
  bool _titlesCached = false;

  /// Singleton instance
  static DatabaseLibraryProvider? _instance;

  DatabaseLibraryProvider._();

  static DatabaseLibraryProvider get instance {
    _instance ??= DatabaseLibraryProvider._();
    return _instance!;
  }

  @override
  String get providerId => 'database';

  @override
  String get displayName => 'מסד נתונים';

  @override
  String get sourceIndicator => 'DB';

  @override
  int get priority => 1; // Higher priority than file system

  @override
  bool get isInitialized => _sqliteProvider.isInitialized;

  @override
  Future<void> initialize() async {
    await _sqliteProvider.initialize();
    debugPrint('💾 DatabaseLibraryProvider initialized');
  }

  @override
  Future<Map<String, List<Book>>> loadBooks(
      Map<String, Map<String, dynamic>> metadata) async {
    final Map<String, List<Book>> booksByCategory = {};

    if (!_sqliteProvider.isInitialized || _sqliteProvider.repository == null) {
      debugPrint('💾 Database not initialized, returning empty');
      return booksByCategory;
    }

    try {
      final dbBooks = await _sqliteProvider.repository!.getAllBooks();
      debugPrint('💾 Database found ${dbBooks.length} books');

      // Cache titles for quick lookup
      _cachedTitles.clear();

      for (final dbBook in dbBooks) {
        _cachedTitles.add(dbBook.title);

        final categoryName =
            dbBook.topics.isNotEmpty ? dbBook.topics.first.name : 'ללא קטגוריה';

        final book = TextBook(
          title: dbBook.title,
          author: dbBook.authors.isNotEmpty ? dbBook.authors.first.name : null,
          heShortDesc: dbBook.heShortDesc,
          pubDate:
              dbBook.pubDates.isNotEmpty ? dbBook.pubDates.first.date : null,
          pubPlace:
              dbBook.pubPlaces.isNotEmpty ? dbBook.pubPlaces.first.name : null,
          order: dbBook.order.toInt(),
          topics: dbBook.topics.map((t) => t.name).join(', '),
        );

        booksByCategory.putIfAbsent(categoryName, () => []);
        booksByCategory[categoryName]!.add(book);
      }

      _titlesCached = true;
      debugPrint(
          '💾 Database loaded ${dbBooks.length} books into ${booksByCategory.length} categories');
    } catch (e) {
      debugPrint('⚠️ Error loading books from database: $e');
    }

    return booksByCategory;
  }

  @override
  Future<bool> hasBook(String title) async {
    // Use cached titles if available
    if (_titlesCached) {
      // Check both regular title (TextBook) and PDF key
      return _cachedTitles.contains(title) ||
          _cachedTitles.contains('${title}_PDF');
    }
    return await _sqliteProvider.isBookInDatabase(title);
  }

  @override
  Future<String?> getBookText(String title) async {
    return await _sqliteProvider.getBookTextFromDb(title);
  }

  @override
  Future<List<TocEntry>?> getBookToc(String title) async {
    return await _sqliteProvider.getBookTocFromDb(title);
  }

  @override
  Future<Set<String>> getAvailableBookTitles() async {
    if (_titlesCached) {
      return Set.from(_cachedTitles);
    }

    if (!_sqliteProvider.isInitialized || _sqliteProvider.repository == null) {
      return {};
    }

    try {
      final dbBooks = await _sqliteProvider.repository!.getAllBooks();
      _cachedTitles.clear();
      for (final book in dbBooks) {
        _cachedTitles.add(book.title);
      }
      _titlesCached = true;
      return Set.from(_cachedTitles);
    } catch (e) {
      debugPrint('⚠️ Error getting book titles from database: $e');
      return {};
    }
  }

  /// Clears the cached titles (call when database changes)
  void clearCache() {
    _cachedTitles.clear();
    _titlesCached = false;
    debugPrint('💾 Database cache cleared');
  }

  /// Gets database statistics
  Future<Map<String, int>> getStats() async {
    return await _sqliteProvider.getDatabaseStats();
  }

  /// Gets the underlying SQLite provider for advanced operations
  SqliteDataProvider get sqliteProvider => _sqliteProvider;

  @override
  Future<Library> buildLibraryCatalog(
    Map<String, Map<String, dynamic>> metadata,
    String rootPath,
  ) async {
    if (!_sqliteProvider.isInitialized || _sqliteProvider.repository == null) {
      debugPrint('💾 Database not initialized, returning empty library');
      return Library(categories: []);
    }

    debugPrint('💾 Building library catalog from database...');

    final repository = _sqliteProvider.repository!;

    // OPTIMIZATION 1: Load all books with relations in a single optimized query
    final allDbBooks =
        await repository.database.bookDao.getAllBooksWithRelations();
    final booksByCategory = <int, List<db_models.Book>>{};

    for (final bookData in allDbBooks) {
      final book = db_models.Book.fromJson(bookData);
      booksByCategory.putIfAbsent(book.categoryId, () => []);
      booksByCategory[book.categoryId]!.add(book);
    }

    debugPrint('💾 Loaded ${allDbBooks.length} books');

    // OPTIMIZATION 2: Load all categories at once and build a parent-child map
    final allCategories =
        await repository.database.categoryDao.getAllCategories();

    final categoriesByParent = <int?, List<db_models.Category>>{};
    for (final cat in allCategories) {
      categoriesByParent.putIfAbsent(cat.parentId, () => []);
      categoriesByParent[cat.parentId]!.add(cat);
    }

    debugPrint('💾 Loaded ${allCategories.length} categories');

    // Build catalog tree starting from root categories (parentId = null)
    final rootCategories = categoriesByParent[null] ?? [];
    final Library library = Library(categories: []);

    int totalCategories = 0;
    for (final rootCategory in rootCategories) {
      final catalogCategory = _buildCatalogCategoryRecursiveOptimized(
        rootCategory,
        booksByCategory,
        categoriesByParent,
        library,
        metadata,
      );
      library.subCategories.add(catalogCategory);
      totalCategories += _countCategories(catalogCategory);
    }

    // Sort all categories and books
    _sortLibraryRecursive(library);

    debugPrint(
        '💾 Database catalog built with $totalCategories categories and ${allDbBooks.length} books from DB');

    // CRITICAL: Merge files from file system that are NOT in the database (e.g., PDFs)
    final filesAdded = await _mergeFileSystemBooks(library, rootPath, metadata);

    // Sort again after merging
    _sortLibraryRecursive(library);

    debugPrint(
        '💾 Final catalog: $totalCategories categories, ${allDbBooks.length} DB books + $filesAdded file system books');
    return library;
  }

  /// Merges books from the file system that are not in the database.
  /// This includes PDF files and any other files not imported to DB.
  /// Returns the number of books added.
  Future<int> _mergeFileSystemBooks(
    Library library,
    String rootPath,
    Map<String, Map<String, dynamic>> metadata,
  ) async {
    int booksAdded = 0;

    final otzariaDir = Directory(rootPath);
    if (!otzariaDir.existsSync()) {
      debugPrint('📁 Otzaria directory does not exist: $rootPath');
      return 0;
    }

    debugPrint('📁 Scanning file system for non-DB books in: $rootPath');

    // Build a map of category paths to Category objects for quick lookup
    // The path format is: "תלמוד בבלי/סדר זרעים" (without the root "אוצריא")
    final categoryPathMap = <String, Category>{};
    _buildCategoryPathMap(library, categoryPathMap);

    debugPrint('📁 Category path map has ${categoryPathMap.length} entries');

    // Scan file system and add non-DB books
    // Start scanning from the root directory (אוצריא), with empty path
    await _scanAndMergeDirectory(
      otzariaDir,
      library,
      categoryPathMap,
      metadata,
      [], // Start with empty path - will be built as we go deeper
      (count) => booksAdded += count,
    );

    // Also scan custom folders that are NOT marked for DB sync
    final customFoldersAdded = await _mergeCustomFolders(
      library,
      categoryPathMap,
      metadata,
    );
    booksAdded += customFoldersAdded;

    _titlesCached = true;
    debugPrint(
        '📁 Added $booksAdded books from file system (including $customFoldersAdded from custom folders)');
    return booksAdded;
  }

  /// Merges books from custom folders that are NOT marked for DB sync.
  /// These folders are displayed under "ספרים אישיים" category.
  Future<int> _mergeCustomFolders(
    Library library,
    Map<String, Category> categoryPathMap,
    Map<String, Map<String, dynamic>> metadata,
  ) async {
    int booksAdded = 0;

    final customFoldersJson =
        Settings.getValue<String>(SettingsRepository.keyCustomFolders);
    final customFolders = CustomFoldersManager.loadFolders(customFoldersJson);

    // Only load folders NOT marked for DB sync
    final foldersToLoad = customFolders.where((f) => !f.addToDatabase).toList();

    if (foldersToLoad.isEmpty) return 0;

    debugPrint('📁 Merging ${foldersToLoad.length} custom folders');

    for (final folder in foldersToLoad) {
      final folderDir = Directory(folder.path);
      if (!await folderDir.exists()) {
        debugPrint('⚠️ Custom folder does not exist: ${folder.path}');
        continue;
      }

      // Scan with category path: ספרים אישיים -> folder name
      await _scanAndMergeDirectory(
        folderDir,
        library,
        categoryPathMap,
        metadata,
        ['ספרים אישיים', folder.name],
        (count) => booksAdded += count,
      );
    }

    return booksAdded;
  }

  /// Builds a map from category path to Category object.
  /// Path format: "תלמוד בבלי/סדר זרעים" (category hierarchy without root)
  void _buildCategoryPathMap(
    Library library,
    Map<String, Category> pathMap,
  ) {
    // Start from the library's subcategories (top-level categories)
    for (final topCategory in library.subCategories) {
      _buildCategoryPathMapRecursive(topCategory, '', pathMap);
    }
  }

  void _buildCategoryPathMapRecursive(
    Category category,
    String parentPath,
    Map<String, Category> pathMap,
  ) {
    // Build the path for this category
    final path =
        parentPath.isEmpty ? category.title : '$parentPath/${category.title}';
    pathMap[path] = category;

    for (final subCat in category.subCategories) {
      _buildCategoryPathMapRecursive(subCat, path, pathMap);
    }
  }

  /// Recursively scans a directory and merges non-DB books into the library.
  Future<void> _scanAndMergeDirectory(
    Directory dir,
    Library library,
    Map<String, Category> categoryPathMap,
    Map<String, Map<String, dynamic>> metadata,
    List<String> currentPath,
    void Function(int) onBooksAdded,
  ) async {
    final dirName = dir.path.split(Platform.pathSeparator).last;

    // Skip special directories
    if (dirName == 'אודות התוכנה' || dirName == 'links') return;

    await for (FileSystemEntity entity in dir.list()) {
      try {
        await entity.stat();

        if (entity is Directory) {
          final subDirName = entity.path.split(Platform.pathSeparator).last;
          final newPath = [...currentPath, subDirName];
          await _scanAndMergeDirectory(
            entity,
            library,
            categoryPathMap,
            metadata,
            newPath,
            onBooksAdded,
          );
        } else if (entity is File) {
          final fileName =
              entity.path.split(Platform.pathSeparator).last.toLowerCase();
          // Only process supported file types
          if (!fileName.endsWith('.pdf') &&
              !fileName.endsWith('.txt') &&
              !fileName.endsWith('.docx')) {
            continue;
          }

          final book =
              _createBookFromFileIfNotInDb(entity, metadata, currentPath);
          if (book != null) {
            debugPrint(
                '📁 Found non-DB book: ${book.title} at path: ${currentPath.join("/")}');

            // Find or create the category for this book
            final category = _findOrCreateCategory(
              currentPath,
              library,
              categoryPathMap,
              metadata,
            );

            // Set the category on the book
            final bookWithCategory =
                _createBookWithCategoryRef(book, category, metadata);
            category.books.add(bookWithCategory);
            onBooksAdded(1);

            debugPrint(
                '📁 Added book "${book.title}" to category "${category.title}"');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Skipping inaccessible entity: ${entity.path}');
        continue;
      }
    }
  }

  /// Creates a book from a file only if it's not already loaded.
  /// PDF files are always added (even if a TextBook with same name exists in DB).
  /// TXT/DOCX files are only added if not already in DB.
  /// Returns null if the book should be skipped or file type is not supported.
  Book? _createBookFromFileIfNotInDb(
    File file,
    Map<String, Map<String, dynamic>> metadata,
    List<String> categoryPath,
  ) {
    final path = file.path.toLowerCase();
    final title = getTitleFromPath(file.path);

    final topics = categoryPath.join(', ');
    String finalTopics = topics;
    if (title.contains(' על ')) {
      finalTopics = '$topics, ${title.split(' על ')[1]}';
    }

    if (path.endsWith('.pdf')) {
      // PDF files are ALWAYS from file system, never in DB
      // Use a unique key for PDF to allow same title as TextBook
      final pdfKey = '${title}_PDF';
      if (_cachedTitles.contains(pdfKey)) {
        return null; // Already added this PDF
      }
      _cachedTitles.add(pdfKey);

      return PdfBook(
        title: title,
        path: file.path,
        author: metadata[title]?['author'],
        heShortDesc: metadata[title]?['heShortDesc'],
        pubDate: metadata[title]?['pubDate'],
        pubPlace: metadata[title]?['pubPlace'],
        order: metadata[title]?['order'] ?? 999,
        topics: finalTopics,
      );
    }

    // For TXT/DOCX files - only add if not already in DB
    if (path.endsWith('.txt') || path.endsWith('.docx')) {
      // Check if TextBook with this title already exists in DB
      if (_cachedTitles.contains(title)) {
        return null;
      }
      _cachedTitles.add(title);

      return TextBook(
        title: title,
        author: metadata[title]?['author'],
        heShortDesc: metadata[title]?['heShortDesc'],
        pubDate: metadata[title]?['pubDate'],
        pubPlace: metadata[title]?['pubPlace'],
        order: metadata[title]?['order'] ?? 999,
        topics: finalTopics,
        extraTitles: metadata[title]?['extraTitles'],
      );
    }

    return null;
  }

  /// Finds an existing category or creates a new one in the hierarchy.
  Category _findOrCreateCategory(
    List<String> categoryPath,
    Library library,
    Map<String, Category> categoryPathMap,
    Map<String, Map<String, dynamic>> metadata,
  ) {
    if (categoryPath.isEmpty) {
      // Return or create a default category
      const defaultName = 'ללא קטגוריה';
      if (categoryPathMap.containsKey(defaultName)) {
        return categoryPathMap[defaultName]!;
      }
      final defaultCategory = Category(
        title: defaultName,
        description: '',
        shortDescription: '',
        order: 999,
        subCategories: [],
        books: [],
        parent: library,
      );
      library.subCategories.add(defaultCategory);
      categoryPathMap[defaultName] = defaultCategory;
      return defaultCategory;
    }

    // Build the full path string
    final fullPath = categoryPath.join('/');

    // Check if category already exists
    if (categoryPathMap.containsKey(fullPath)) {
      return categoryPathMap[fullPath]!;
    }

    // Need to create the category hierarchy
    Category currentParent = library;
    String currentPath = '';

    for (int i = 0; i < categoryPath.length; i++) {
      final part = categoryPath[i];
      currentPath = currentPath.isEmpty ? part : '$currentPath/$part';

      if (categoryPathMap.containsKey(currentPath)) {
        currentParent = categoryPathMap[currentPath]!;
        continue;
      }

      // Check if exists in parent's subcategories
      Category? existingCategory;
      for (final subCat in currentParent.subCategories) {
        if (subCat.title == part) {
          existingCategory = subCat;
          break;
        }
      }

      if (existingCategory != null) {
        categoryPathMap[currentPath] = existingCategory;
        currentParent = existingCategory;
      } else {
        // Create new category
        final newCategory = Category(
          title: part,
          description: metadata[part]?['heDesc'] ?? '',
          shortDescription: metadata[part]?['heShortDesc'] ?? '',
          order: metadata[part]?['order'] ?? 999,
          subCategories: [],
          books: [],
          parent: currentParent,
        );

        currentParent.subCategories.add(newCategory);
        categoryPathMap[currentPath] = newCategory;
        currentParent = newCategory;
      }
    }

    return currentParent;
  }

  /// Creates a book with proper category reference.
  Book _createBookWithCategoryRef(
    Book book,
    Category category,
    Map<String, Map<String, dynamic>> metadata,
  ) {
    final bookMeta = metadata[book.title];

    if (book is TextBook) {
      return TextBook(
        title: book.title,
        category: category,
        author: book.author ?? bookMeta?['author'],
        heShortDesc: book.heShortDesc ?? bookMeta?['heShortDesc'],
        pubDate: book.pubDate ?? bookMeta?['pubDate'],
        pubPlace: book.pubPlace ?? bookMeta?['pubPlace'],
        order: book.order,
        topics: book.topics,
        extraTitles: book.extraTitles ?? bookMeta?['extraTitles'],
      );
    } else if (book is PdfBook) {
      return PdfBook(
        title: book.title,
        category: category,
        path: book.path,
        author: book.author ?? bookMeta?['author'],
        heShortDesc: book.heShortDesc ?? bookMeta?['heShortDesc'],
        pubDate: book.pubDate ?? bookMeta?['pubDate'],
        pubPlace: book.pubPlace ?? bookMeta?['pubPlace'],
        order: book.order,
        topics: book.topics,
      );
    }
    return book;
  }

  /// Recursively builds a catalog category with its subcategories and books (OPTIMIZED - no async).
  Category _buildCatalogCategoryRecursiveOptimized(
    db_models.Category dbCategory,
    Map<int, List<db_models.Book>> booksByCategory,
    Map<int?, List<db_models.Category>> categoriesByParent,
    Category parent,
    Map<String, Map<String, dynamic>> metadata,
  ) {
    // Create the category
    final category = Category(
      title: dbCategory.title,
      description: metadata[dbCategory.title]?['heDesc'] ?? '',
      shortDescription: metadata[dbCategory.title]?['heShortDesc'] ?? '',
      order: metadata[dbCategory.title]?['order'] ?? 999,
      subCategories: [],
      books: [],
      parent: parent,
    );

    // Add books in this category
    final dbBooks = booksByCategory[dbCategory.id] ?? [];
    for (final dbBook in dbBooks) {
      final book = _convertDbBookToBook(dbBook, category, metadata);
      category.books.add(book);
      _cachedTitles.add(dbBook.title);
    }

    // Get subcategories and build them recursively
    final children = categoriesByParent[dbCategory.id] ?? [];
    for (final child in children) {
      final subCategory = _buildCatalogCategoryRecursiveOptimized(
        child,
        booksByCategory,
        categoriesByParent,
        category,
        metadata,
      );
      category.subCategories.add(subCategory);
    }

    return category;
  }

  /// Converts a database book model to the app's Book model.
  Book _convertDbBookToBook(
    db_models.Book dbBook,
    Category category,
    Map<String, Map<String, dynamic>> metadata,
  ) {
    final bookMeta = metadata[dbBook.title];

    return TextBook(
      title: dbBook.title,
      category: category,
      author: dbBook.authors.isNotEmpty
          ? dbBook.authors.first.name
          : bookMeta?['author'],
      heShortDesc: dbBook.heShortDesc ?? bookMeta?['heShortDesc'],
      pubDate: dbBook.pubDates.isNotEmpty
          ? dbBook.pubDates.first.date
          : bookMeta?['pubDate'],
      pubPlace: dbBook.pubPlaces.isNotEmpty
          ? dbBook.pubPlaces.first.name
          : bookMeta?['pubPlace'],
      order: dbBook.order.toInt(),
      topics: dbBook.topics.map((t) => t.name).join(', '),
    );
  }

  /// Counts the total number of categories in the tree.
  int _countCategories(Category category) {
    return 1 +
        category.subCategories
            .fold(0, (sum, sub) => sum + _countCategories(sub));
  }

  /// Recursively sorts all categories and books in the library.
  void _sortLibraryRecursive(Category category) {
    category.subCategories.sort((a, b) => a.order.compareTo(b.order));
    category.books.sort((a, b) => a.order.compareTo(b.order));

    for (final subCat in category.subCategories) {
      _sortLibraryRecursive(subCat);
    }
  }

  @override
  Future<List<Link>> getAllLinksForBook(String title) async {
    if (!_sqliteProvider.isInitialized || _sqliteProvider.repository == null) {
      debugPrint('💾 Database not initialized, returning empty links');
      return [];
    }

    try {
      final book = await _sqliteProvider.repository!.getBookByTitle(title);
      if (book == null) {
        debugPrint('💾 Book "$title" not found in database');
        return [];
      }

      final db = await _sqliteProvider.repository!.database.database;

      // Get all links where this book is the source
      final result = await db.rawQuery('''
        SELECT 
          l.sourceLineId,
          l.targetLineId,
          sl.lineIndex as sourceLineIndex,
          tl.lineIndex as targetLineIndex,
          tb.title as targetBookTitle,
          ct.name as connectionTypeName
        FROM link l
        JOIN line sl ON l.sourceLineId = sl.id
        JOIN line tl ON l.targetLineId = tl.id
        JOIN book tb ON l.targetBookId = tb.id
        LEFT JOIN connection_type ct ON l.connectionTypeId = ct.id
        WHERE l.sourceBookId = ?
        ORDER BY sl.lineIndex
      ''', [book.id]);

      final links = result.map((row) {
        final targetTitle = row['targetBookTitle'] as String;
        final connectionType =
            row['connectionTypeName'] as String? ?? 'reference';

        return Link(
          heRef: targetTitle,
          index1: (row['sourceLineIndex'] as int) + 1,
          path2: targetTitle,
          index2: (row['targetLineIndex'] as int) + 1,
          connectionType: connectionType,
        );
      }).toList();

      debugPrint('💾 Found ${links.length} links for book "$title"');
      return links;
    } catch (e) {
      debugPrint('⚠️ Error getting links for book "$title": $e');
      return [];
    }
  }

  @override
  Future<String> getLinkContent(Link link) async {
    if (!_sqliteProvider.isInitialized || _sqliteProvider.repository == null) {
      return 'שגיאה: מסד הנתונים לא מאותחל';
    }

    try {
      if (link.path2.isEmpty) {
        return 'שגיאה: נתיב ריק';
      }

      if (link.index2 <= 0) {
        return 'שגיאה: אינדקס לא תקין';
      }

      // Get the target book text and extract the specific line
      final targetTitle = link.path2.contains('/')
          ? link.path2.split('/').last.replaceAll('.txt', '')
          : link.path2;

      final bookText = await _sqliteProvider.getBookTextFromDb(targetTitle);
      if (bookText == null) {
        return 'שגיאה: הספר לא נמצא במסד הנתונים';
      }

      final lines = bookText.split('\n');
      if (link.index2 < 1 || link.index2 > lines.length) {
        return 'שגיאה: אינדקס מחוץ לטווח';
      }

      return lines[link.index2 - 1];
    } catch (e) {
      debugPrint('⚠️ Error loading link content from database: $e');
      return 'שגיאה בטעינת תוכן המפרש: $e';
    }
  }
}
