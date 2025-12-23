import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:otzaria/data/data_providers/library_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/migration/core/models/category.dart' as db_models;
import 'package:otzaria/migration/core/models/book.dart' as db_models;
import 'package:otzaria/migration/core/models/toc_entry.dart' as db_models;
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:otzaria/utils/toc_parser.dart';

/// Library provider that loads books from the SQLite database.
class DatabaseLibraryProvider implements LibraryProvider {
  final SqliteDataProvider _sqliteProvider = SqliteDataProvider.instance;
  final Set<String> _cachedTitles = {}; // Only DB books
  final Set<String> _fileOnlyTitles = {}; // Books only in file system
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
    // Return only books that are actually in the database, not file-only books
    return await getDatabaseOnlyBookTitles();
  }

  /// Gets book titles that are ONLY in the database (not including file-only books)
  Future<Set<String>> getDatabaseOnlyBookTitles() async {
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
    _fileOnlyTitles.clear();
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

    // CRITICAL: Clear cache before rebuilding to ensure fresh data
    _cachedTitles.clear();
    _fileOnlyTitles.clear();
    _titlesCached = false;

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

    // Mark titles as cached
    _titlesCached = true;

    debugPrint(
        '💾 Database catalog built with $totalCategories categories and ${allDbBooks.length} books from DB');

    // NOTE: Library is now built ONLY from the database.
    // Files that are not in the DB will not appear in the library browser.
    // This is intentional - all book/file information should be in the DB.

    return library;
  }

  /// Gets or creates a category in the database for the given path.
  /// Returns the category ID.
  Future<int> _getOrCreateCategoryInDb(List<String> categoryPath) async {
    final repository = _sqliteProvider.repository;
    if (repository == null) {
      return 1; // Default category ID
    }

    if (categoryPath.isEmpty) {
      // Return default category
      final defaultCategory =
          await repository.getCategoryByTitle('ללא קטגוריה');
      if (defaultCategory != null) {
        return defaultCategory.id;
      }
      // Create default category if it doesn't exist
      return await repository.insertCategory(
        db_models.Category(
          id: 0,
          title: 'ללא קטגוריה',
          parentId: null,
          level: 0,
        ),
      );
    }

    int? parentId;
    int categoryId = 1;
    int level = 0;

    for (final part in categoryPath) {
      // Try to find existing category
      final existingCategory =
          await repository.getCategoryByTitleAndParent(part, parentId);

      if (existingCategory != null) {
        categoryId = existingCategory.id;
        parentId = existingCategory.id;
        level = existingCategory.level + 1;
      } else {
        // Create new category
        categoryId = await repository.insertCategory(
          db_models.Category(
            id: 0,
            title: part,
            parentId: parentId,
            level: level,
          ),
        );
        parentId = categoryId;
        level++;
      }
    }

    return categoryId;
  }

  /// Parses TOC entries for an external text book.
  /// Returns a list of TocEntry objects ready for insertion.
  Future<List<db_models.TocEntry>?> _parseTocForExternalBook(
    File file,
    int bookId,
  ) async {
    try {
      final content = await file.readAsString();

      // Parse TOC using the existing TocParser
      final tocEntries =
          await Isolate.run(() => TocParser.parseEntriesFromContent(content));

      if (tocEntries.isEmpty) {
        return null;
      }

      // Convert to DB TocEntry format
      final dbEntries = <db_models.TocEntry>[];
      _convertTocEntriesToDb(tocEntries, dbEntries, bookId, null);

      return dbEntries;
    } catch (e) {
      debugPrint('⚠️ Failed to parse TOC for external book: $e');
      return null;
    }
  }

  /// Recursively converts TocEntry objects to DB format.
  void _convertTocEntriesToDb(
    List<TocEntry> entries,
    List<db_models.TocEntry> dbEntries,
    int bookId,
    int? parentId,
  ) {
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLastChild = i == entries.length - 1;
      final hasChildren = entry.children.isNotEmpty;

      final dbEntry = db_models.TocEntry(
        id: 0,
        bookId: bookId,
        parentId: parentId,
        text: entry.text,
        level: entry.level,
        lineId: entry.index, // Using index as lineId for external books
        isLastChild: isLastChild,
        hasChildren: hasChildren,
      );

      dbEntries.add(dbEntry);

      // Process children recursively
      // Note: We can't set the actual parentId here since we don't have the inserted ID yet
      // The repository will handle this during insertion
      if (hasChildren) {
        _convertTocEntriesToDb(entry.children, dbEntries, bookId, null);
      }
    }
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

  /// Scans a custom folder and adds all books as external books to the database.
  /// This is called when a new custom folder is added.
  ///
  /// [folderPath] - The full path to the folder to scan
  /// [folderName] - The display name of the folder
  /// [repository] - The repository to use for database operations
  Future<void> scanAndAddExternalBooksFromFolder(
    String folderPath,
    String folderName,
    dynamic repository,
  ) async {
    debugPrint('📁 Scanning custom folder for external books: $folderPath');

    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      debugPrint('⚠️ Folder does not exist: $folderPath');
      return;
    }

    // Load metadata (empty map if not available)
    final metadata = <String, Map<String, dynamic>>{};

    // Scan the folder recursively
    await _scanFolderForExternalBooks(
      dir,
      repository,
      metadata,
      ['ספרים אישיים', folderName],
    );

    debugPrint('📁 Finished scanning custom folder: $folderPath');
  }

  /// Recursively scans a folder and adds external books to the database.
  Future<void> _scanFolderForExternalBooks(
    Directory dir,
    dynamic repository,
    Map<String, Map<String, dynamic>> metadata,
    List<String> categoryPath,
  ) async {
    await for (FileSystemEntity entity in dir.list()) {
      try {
        await entity.stat();

        if (entity is Directory) {
          final subDirName = entity.path.split(Platform.pathSeparator).last;
          final newPath = [...categoryPath, subDirName];
          await _scanFolderForExternalBooks(
            entity,
            repository,
            metadata,
            newPath,
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

          await _addSingleExternalBookToDb(
            entity,
            repository,
            metadata,
            categoryPath,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Skipping inaccessible entity: ${entity.path}');
        continue;
      }
    }
  }

  /// Adds a single external book to the database.
  Future<void> _addSingleExternalBookToDb(
    File file,
    dynamic repository,
    Map<String, Map<String, dynamic>> metadata,
    List<String> categoryPath,
  ) async {
    final path = file.path.toLowerCase();
    final title = getTitleFromPath(file.path);
    final fileStat = await file.stat();
    final fileSize = fileStat.size;
    final lastModified = fileStat.modified.millisecondsSinceEpoch;

    // Determine file type
    String fileType;
    if (path.endsWith('.pdf')) {
      fileType = 'pdf';
    } else if (path.endsWith('.txt')) {
      fileType = 'txt';
    } else if (path.endsWith('.docx')) {
      fileType = 'docx';
    } else {
      return;
    }

    // Check if the book already exists in DB (by file path)
    final existingBook = await repository.getExternalBookByFilePath(file.path);
    if (existingBook != null) {
      // Book exists - check if we need to update metadata
      if (existingBook.fileSize != fileSize ||
          existingBook.lastModified != lastModified) {
        await repository.updateExternalBookMetadata(
          existingBook.id,
          fileSize,
          lastModified,
        );
        debugPrint('📁 Updated external book metadata: $title');
      }
      return;
    }

    // Book doesn't exist - add it to DB
    try {
      // Get or create category in DB
      final categoryId = await _getOrCreateCategoryInDb(categoryPath);

      // Parse TOC for text files
      List<db_models.TocEntry>? tocEntries;
      if (fileType == 'txt') {
        tocEntries = await _parseTocForExternalBook(file, categoryId);
      }

      // Insert the external book
      await repository.insertExternalBook(
        categoryId: categoryId,
        title: title,
        filePath: file.path,
        fileType: fileType,
        fileSize: fileSize,
        lastModified: lastModified,
        heShortDesc: metadata[title]?['heShortDesc'],
        orderIndex: (metadata[title]?['order'] ?? 999).toDouble(),
        tocEntries: tocEntries,
      );

      debugPrint('📁 Inserted external book to DB: $title (type: $fileType)');
    } catch (e) {
      debugPrint('⚠️ Failed to insert external book to DB: $title - $e');
    }
  }
}
