import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../core/models/book.dart';
import '../core/models/category.dart';
import '../core/models/line.dart';
import '../core/models/link.dart';
import '../core/models/toc_entry.dart';
import '../dao/repository/seforim_repository.dart';
import '../../settings/custom_folders/custom_folder.dart';
import '../../settings/settings_repository.dart';

/// Result of a file sync operation
class FileSyncResult {
  final int addedBooks;
  final int updatedBooks;
  final int addedCategories;
  final int addedLinks;
  final int deletedFiles;
  final int skippedFiles;
  final List<String> errors;
  final Duration duration;

  const FileSyncResult({
    this.addedBooks = 0,
    this.updatedBooks = 0,
    this.addedCategories = 0,
    this.addedLinks = 0,
    this.deletedFiles = 0,
    this.skippedFiles = 0,
    this.errors = const [],
    this.duration = Duration.zero,
  });

  @override
  String toString() {
    return 'FileSyncResult(added: $addedBooks, updated: $updatedBooks, '
        'categories: $addedCategories, links: $addedLinks, deleted: $deletedFiles, '
        'skipped: $skippedFiles, errors: ${errors.length}, '
        'duration: ${duration.inSeconds}s)';
  }
}

/// Service for syncing files from אוצריא and links folders to the database.
///
/// This service scans for new TXT files in the library path and adds them
/// to the database automatically. It runs in the background after app startup.
class FileSyncService {
  static final _log = Logger('FileSyncService');
  static FileSyncService? _instance;

  final SeforimRepository _repository;
  bool _isSyncing = false;

  /// Progress callback for UI updates
  void Function(double progress, String message)? onProgress;

  /// Counter for IDs
  int _nextBookId = 0;
  int _nextLineId = 0;
  int _nextTocEntryId = 0;
  int _nextCategoryId = 0;

  /// Cache for book titles to IDs (for link processing)
  final Map<String, int> _bookTitleToId = {};

  /// Cache for book line indices to IDs
  final Map<int, List<int>> _bookLineIndexToId = {};

  FileSyncService._(this._repository);

  /// Get singleton instance
  static Future<FileSyncService?> getInstance(
      SeforimRepository? repository) async {
    if (repository == null) return null;
    _instance ??= FileSyncService._(repository);
    return _instance;
  }

  /// Check if sync is currently running
  bool get isSyncing => _isSyncing;

  /// Get the repository for external access
  SeforimRepository get repository => _repository;

  /// Delete a book from the database by its file path
  /// This is used when a file is removed from GitHub sync
  Future<bool> deleteBookByFilePath(String filePath) async {
    try {
      // Extract the book title from the file path
      final title = path.basenameWithoutExtension(filePath);
      _log.info('Attempting to delete book from DB: $title');

      // Find the book by title
      final existingBook = await _repository.checkBookExists(title);
      if (existingBook == null) {
        _log.info('Book not found in DB, nothing to delete: $title');
        return false;
      }

      // Delete the book completely (including lines, TOC, links, etc.)
      await _repository.deleteBookCompletely(existingBook.id);
      _log.info(
          'Successfully deleted book from DB: $title (id: ${existingBook.id})');
      return true;
    } catch (e, stackTrace) {
      _log.warning('Error deleting book from DB: $filePath', e, stackTrace);
      return false;
    }
  }

  /// Restore files from DB for a custom folder
  /// This exports books from the "ספרים אישיים" category back to files
  /// and then deletes them from the database.
  ///
  /// [folder] - The custom folder to restore
  /// [onProgress] - Progress callback for UI updates
  ///
  /// Returns the number of books restored
  Future<RestoreFolderResult> restoreFolderFromDatabase(
    CustomFolder folder, {
    void Function(double progress, String message)? onProgress,
  }) async {
    _log.info('Restoring folder from DB: ${folder.name}');
    int restoredBooks = 0;
    int restoredCategories = 0;
    final errors = <String>[];

    try {
      // Find the "ספרים אישיים" root category
      final rootCategories = await _repository.getRootCategories();
      Category? personalCategory;
      for (final cat in rootCategories) {
        if (cat.title == 'ספרים אישיים') {
          personalCategory = cat;
          break;
        }
      }

      if (personalCategory == null) {
        _log.info('No "ספרים אישיים" category found in DB');
        return RestoreFolderResult(
          restoredBooks: 0,
          restoredCategories: 0,
          errors: ['לא נמצאה קטגוריית "ספרים אישיים" במסד הנתונים'],
        );
      }

      // Find the folder's category under "ספרים אישיים"
      final folderCategories =
          await _repository.getCategoryChildren(personalCategory.id);
      Category? folderCategory;
      for (final cat in folderCategories) {
        if (cat.title == folder.name) {
          folderCategory = cat;
          break;
        }
      }

      if (folderCategory == null) {
        _log.info('Folder category not found in DB: ${folder.name}');
        return RestoreFolderResult(
          restoredBooks: 0,
          restoredCategories: 0,
          errors: ['התיקייה "${folder.name}" לא נמצאה במסד הנתונים'],
        );
      }

      onProgress?.call(0.1, 'מייצא ספרים מהמסד...');

      // Recursively restore all books and subcategories
      final result = await _restoreCategoryRecursive(
        folderCategory,
        folder.path,
        onProgress,
        0.1,
        0.8,
      );
      restoredBooks = result.books;
      restoredCategories = result.categories;
      errors.addAll(result.errors);

      onProgress?.call(0.9, 'מוחק נתונים מהמסד...');

      // Delete the folder category and all its contents from DB
      await _deleteCategoryRecursive(folderCategory.id);

      // Clean up empty parent categories up to "ספרים אישיים"
      await _cleanupEmptyParentCategories(personalCategory.id);

      onProgress?.call(1.0, 'השחזור הושלם');
      _log.info(
          'Restored $restoredBooks books and $restoredCategories categories from DB');
    } catch (e, stackTrace) {
      _log.severe('Error restoring folder from DB', e, stackTrace);
      errors.add('שגיאה בשחזור: $e');
    }

    return RestoreFolderResult(
      restoredBooks: restoredBooks,
      restoredCategories: restoredCategories,
      errors: errors,
    );
  }

  /// Recursively restore a category and its contents to files
  Future<_RestoreResult> _restoreCategoryRecursive(
    Category category,
    String targetPath,
    void Function(double progress, String message)? onProgress,
    double progressStart,
    double progressEnd,
  ) async {
    int books = 0;
    int categories = 0;
    final errors = <String>[];

    // Ensure the target directory exists
    final targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
      categories++;
    }

    // Get books in this category
    final categoryBooks = await _repository.getBooksByCategory(category.id);

    // Restore each book
    for (int i = 0; i < categoryBooks.length; i++) {
      final book = categoryBooks[i];
      try {
        await _restoreBookToFile(book, targetPath);
        books++;

        final progress = progressStart +
            (progressEnd - progressStart) * (i / categoryBooks.length) * 0.5;
        onProgress?.call(progress, 'משחזר: ${book.title}');
      } catch (e) {
        _log.warning('Error restoring book ${book.title}: $e');
        errors.add('שגיאה בשחזור "${book.title}": $e');
      }
    }

    // Get and restore subcategories
    final subCategories = await _repository.getCategoryChildren(category.id);
    for (int i = 0; i < subCategories.length; i++) {
      final subCat = subCategories[i];
      final subPath = path.join(targetPath, subCat.title);

      final subResult = await _restoreCategoryRecursive(
        subCat,
        subPath,
        onProgress,
        progressStart + (progressEnd - progressStart) * 0.5,
        progressEnd,
      );

      books += subResult.books;
      categories += subResult.categories + 1;
      errors.addAll(subResult.errors);
    }

    return _RestoreResult(books: books, categories: categories, errors: errors);
  }

  /// Restore a single book to a file
  Future<void> _restoreBookToFile(Book book, String targetPath) async {
    // Get all lines for the book
    final lines = await _repository.getLines(book.id, 0, book.totalLines - 1);

    // Sort lines by index
    lines.sort((a, b) => a.lineIndex.compareTo(b.lineIndex));

    // Build the file content
    final content = lines.map((line) => line.content).join('\n');

    // Write to file
    final filePath = path.join(targetPath, '${book.title}.txt');
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);

    _log.info('Restored book to file: $filePath');
  }

  /// Recursively delete a category and all its contents from DB
  Future<void> _deleteCategoryRecursive(int categoryId) async {
    // First, delete all books in this category
    final books = await _repository.getBooksByCategory(categoryId);
    for (final book in books) {
      await _repository.deleteBookCompletely(book.id);
    }

    // Then, recursively delete subcategories
    final subCategories = await _repository.getCategoryChildren(categoryId);
    for (final subCat in subCategories) {
      await _deleteCategoryRecursive(subCat.id);
    }

    // Finally, delete this category
    await _repository.deleteCategory(categoryId);
  }

  /// Clean up empty parent categories recursively
  /// Starts from a category and checks if it's empty, if so deletes it
  /// and continues up the hierarchy
  Future<void> _cleanupEmptyParentCategories(int categoryId) async {
    // Get the category to check its parent
    final category = await _repository.getCategory(categoryId);
    if (category == null) return;

    // Check if this category has any children (books or subcategories)
    final books = await _repository.getBooksByCategory(categoryId);
    final subCategories = await _repository.getCategoryChildren(categoryId);

    // If category is empty, delete it and check parent
    if (books.isEmpty && subCategories.isEmpty) {
      final parentId = category.parentId;
      await _repository.deleteCategory(categoryId);
      _log.info('Deleted empty category: ${category.title}');

      // If there's a parent, check if it's now empty too
      if (parentId != null) {
        await _cleanupEmptyParentCategories(parentId);
      }
    }
  }

  /// Delete a folder from the database (without restoring files)
  /// Used when removing a folder from the app completely
  Future<void> deleteFolderFromDatabase(
      int folderCategoryId, int personalCategoryId) async {
    _log.info('Deleting folder category from DB: $folderCategoryId');

    // Delete the folder category and all its contents
    await _deleteCategoryRecursive(folderCategoryId);

    // Clean up empty parent categories
    await _cleanupEmptyParentCategories(personalCategoryId);

    _log.info('Folder deleted from DB');
  }

  /// Main sync function - scans אוצריא and links folders for new files
  Future<FileSyncResult> syncFiles({
    void Function(double progress, String message)? onProgress,
  }) async {
    if (_isSyncing) {
      _log.warning('Sync already in progress, skipping');
      return const FileSyncResult(errors: ['Sync already in progress']);
    }

    _isSyncing = true;
    this.onProgress = onProgress;
    final stopwatch = Stopwatch()..start();

    int addedBooks = 0;
    int updatedBooks = 0;
    int addedCategories = 0;
    int addedLinks = 0;
    int deletedFiles = 0;
    int skippedFiles = 0;
    final errors = <String>[];

    try {
      final libraryPath = Settings.getValue<String>('key-library-path');
      if (libraryPath == null || libraryPath.isEmpty) {
        _log.warning('Library path not set, skipping sync');
        return const FileSyncResult(errors: ['Library path not set']);
      }

      // Initialize ID counters from database
      await _initializeIdCounters();

      // Scan אוצריא folder for TXT files only
      final otzariaPath = path.join(libraryPath, 'אוצריא');
      final otzariaDir = Directory(otzariaPath);

      if (await otzariaDir.exists()) {
        _log.info('Scanning אוצריא folder: $otzariaPath');
        _reportProgress(0.1, 'סורק תיקיית אוצריא...');

        final otzariaResult = await _scanAndSyncTxtFiles(otzariaPath);
        addedBooks += otzariaResult.addedBooks;
        updatedBooks += otzariaResult.updatedBooks;
        addedCategories += otzariaResult.addedCategories;
        deletedFiles += otzariaResult.deletedFiles;
        skippedFiles += otzariaResult.skippedFiles;
        errors.addAll(otzariaResult.errors);
      }

      // Scan custom folders that are marked for DB sync
      _reportProgress(0.4, 'סורק תיקיות מותאמות אישית...');
      final customFoldersResult = await _scanAndSyncCustomFolders();
      addedBooks += customFoldersResult.addedBooks;
      updatedBooks += customFoldersResult.updatedBooks;
      addedCategories += customFoldersResult.addedCategories;
      deletedFiles += customFoldersResult.deletedFiles;
      skippedFiles += customFoldersResult.skippedFiles;
      errors.addAll(customFoldersResult.errors);

      // Scan links folder for JSON files only
      final linksPath = path.join(libraryPath, 'links');
      final linksDir = Directory(linksPath);

      if (await linksDir.exists()) {
        _log.info('Scanning links folder: $linksPath');
        _reportProgress(0.6, 'סורק תיקיית קישורים...');

        final linksResult = await _scanAndSyncLinkFiles(linksPath);
        addedLinks += linksResult.addedLinks;
        deletedFiles += linksResult.deletedFiles;
        skippedFiles += linksResult.skippedFiles;
        errors.addAll(linksResult.errors);
      }

      // Check for acronym.json file and update book_acronym table if found
      _reportProgress(0.85, 'בודק קובץ acronym.json...');
      final acronymResult = await _checkAndProcessAcronymFile(libraryPath);
      if (acronymResult.processed) {
        _log.info(
            'Processed acronym.json: ${acronymResult.updatedBooks} books updated, ${acronymResult.newTerms} new terms');
      }
      errors.addAll(acronymResult.errors);

      // Rebuild category closure if categories were added
      if (addedCategories > 0) {
        _reportProgress(0.95, 'מעדכן היררכיית קטגוריות...');
        await _repository.rebuildCategoryClosure();
      }

      _reportProgress(1.0, 'הסנכרון הושלם');
    } catch (e, stackTrace) {
      _log.severe('Error during sync', e, stackTrace);
      errors.add('Sync error: $e');
    } finally {
      _isSyncing = false;
      stopwatch.stop();
    }

    final result = FileSyncResult(
      addedBooks: addedBooks,
      updatedBooks: updatedBooks,
      addedCategories: addedCategories,
      addedLinks: addedLinks,
      deletedFiles: deletedFiles,
      skippedFiles: skippedFiles,
      errors: errors,
      duration: stopwatch.elapsed,
    );

    _log.info('Sync completed: $result');
    return result;
  }

  /// Initialize ID counters from database
  Future<void> _initializeIdCounters() async {
    // Use repository extension method to get max IDs
    final maxIds = await _repository.getMaxIds();

    _nextBookId = maxIds.maxBookId + 1;
    _nextLineId = maxIds.maxLineId + 1;
    _nextTocEntryId = maxIds.maxTocId + 1;
    _nextCategoryId = maxIds.maxCategoryId + 1;

    _log.info('Initialized ID counters: book=$_nextBookId, line=$_nextLineId, '
        'toc=$_nextTocEntryId, category=$_nextCategoryId');
  }

  /// Scan a folder and sync new TXT files to database (for אוצריא folder)
  Future<FileSyncResult> _scanAndSyncTxtFiles(String folderPath) async {
    int addedBooks = 0;
    int updatedBooks = 0;
    int addedCategories = 0;
    int deletedFiles = 0;
    int skippedFiles = 0;
    final errors = <String>[];

    // Find new TXT files only
    final newFiles = await _findNewTxtFiles(folderPath);

    if (newFiles.isEmpty) {
      _log.info('No new TXT files found in $folderPath');
      return const FileSyncResult();
    }

    _log.info('Found ${newFiles.length} new TXT files to process');

    int processed = 0;
    for (final filePath in newFiles) {
      try {
        final result = await _processNewFile(filePath, folderPath);
        if (result.wasAdded) {
          addedBooks++;
          addedCategories += result.categoriesCreated;
        } else if (result.wasUpdated) {
          updatedBooks++;
        } else {
          skippedFiles++;
        }

        // Delete the TXT file after successful processing
        if (result.wasAdded || result.wasUpdated) {
          try {
            await File(filePath).delete();
            deletedFiles++;
            _log.info('Deleted processed file: ${path.basename(filePath)}');
          } catch (e) {
            _log.warning('Failed to delete file $filePath: $e');
          }
        }

        processed++;
        _reportProgress(
          0.1 + (0.7 * processed / newFiles.length),
          'מעבד ${path.basename(filePath)}...',
        );
      } catch (e, stackTrace) {
        _log.warning('Error processing file $filePath', e, stackTrace);
        errors.add('Error processing ${path.basename(filePath)}: $e');
      }
    }

    // Clean up empty directories after processing
    await _removeEmptyDirectories(folderPath);

    return FileSyncResult(
      addedBooks: addedBooks,
      updatedBooks: updatedBooks,
      addedCategories: addedCategories,
      deletedFiles: deletedFiles,
      skippedFiles: skippedFiles,
      errors: errors,
    );
  }

  /// Scan custom folders that are marked for DB sync
  /// Custom folders are stored under the "ספרים אישיים" category
  Future<FileSyncResult> _scanAndSyncCustomFolders() async {
    int addedBooks = 0;
    int updatedBooks = 0;
    int addedCategories = 0;
    int deletedFiles = 0;
    int skippedFiles = 0;
    final errors = <String>[];

    // Load custom folders from settings
    final customFoldersJson =
        Settings.getValue<String>(SettingsRepository.keyCustomFolders);
    final customFolders = CustomFoldersManager.loadFolders(customFoldersJson);

    // Filter only folders marked for DB sync
    final foldersToSync = customFolders.where((f) => f.addToDatabase).toList();

    if (foldersToSync.isEmpty) {
      _log.info('No custom folders marked for DB sync');
      return const FileSyncResult();
    }

    _log.info('Found ${foldersToSync.length} custom folders to sync');

    for (final folder in foldersToSync) {
      final folderDir = Directory(folder.path);
      if (!await folderDir.exists()) {
        _log.warning('Custom folder does not exist: ${folder.path}');
        errors.add('תיקייה לא קיימת: ${folder.name}');
        continue;
      }

      _log.info('Scanning custom folder: ${folder.path}');

      // Scan for TXT files in this custom folder
      final result = await _scanAndSyncCustomFolder(folder);
      addedBooks += result.addedBooks;
      updatedBooks += result.updatedBooks;
      addedCategories += result.addedCategories;
      deletedFiles += result.deletedFiles;
      skippedFiles += result.skippedFiles;
      errors.addAll(result.errors);
    }

    return FileSyncResult(
      addedBooks: addedBooks,
      updatedBooks: updatedBooks,
      addedCategories: addedCategories,
      deletedFiles: deletedFiles,
      skippedFiles: skippedFiles,
      errors: errors,
    );
  }

  /// Scan a single custom folder and sync its files to DB
  /// Files are placed under "ספרים אישיים" -> folder name -> subfolders
  Future<FileSyncResult> _scanAndSyncCustomFolder(CustomFolder folder) async {
    int addedBooks = 0;
    int updatedBooks = 0;
    int addedCategories = 0;
    int deletedFiles = 0;
    int skippedFiles = 0;
    final errors = <String>[];

    // Find all TXT files in the custom folder
    final newFiles = await _findNewTxtFiles(folder.path);

    if (newFiles.isEmpty) {
      _log.info('No TXT files found in custom folder: ${folder.name}');
      return const FileSyncResult();
    }

    _log.info(
        'Found ${newFiles.length} TXT files in custom folder: ${folder.name}');

    for (final filePath in newFiles) {
      try {
        // Process file with custom category path prefix
        final result = await _processCustomFolderFile(filePath, folder);
        if (result.wasAdded) {
          addedBooks++;
          addedCategories += result.categoriesCreated;
        } else if (result.wasUpdated) {
          updatedBooks++;
        } else {
          skippedFiles++;
        }

        // Delete the TXT file after successful processing
        if (result.wasAdded || result.wasUpdated) {
          try {
            await File(filePath).delete();
            deletedFiles++;
            _log.info('Deleted processed file: ${path.basename(filePath)}');
          } catch (e) {
            _log.warning('Failed to delete file $filePath: $e');
          }
        }
      } catch (e, stackTrace) {
        _log.warning(
            'Error processing custom folder file $filePath', e, stackTrace);
        errors.add('Error processing ${path.basename(filePath)}: $e');
      }
    }

    // Clean up empty directories after processing
    await _removeEmptyDirectories(folder.path);

    return FileSyncResult(
      addedBooks: addedBooks,
      updatedBooks: updatedBooks,
      addedCategories: addedCategories,
      deletedFiles: deletedFiles,
      skippedFiles: skippedFiles,
      errors: errors,
    );
  }

  /// Process a file from a custom folder
  /// Creates category hierarchy: ספרים אישיים -> folder name -> subfolders
  Future<_FileProcessResult> _processCustomFolderFile(
    String filePath,
    CustomFolder folder,
  ) async {
    final title = path.basenameWithoutExtension(filePath);
    _log.info('Processing custom folder file: $title');

    // Build category path: ספרים אישיים -> folder name -> relative path
    final categoryPath = _buildCustomFolderCategoryPath(filePath, folder);

    if (categoryPath.isEmpty) {
      _log.warning('Could not build category path for: $filePath');
      return const _FileProcessResult(wasAdded: false, wasUpdated: false);
    }

    // Find or create category chain
    int categoriesCreated = 0;
    final categoryResult = await _findOrCreateCategoryChain(categoryPath);
    final categoryId = categoryResult.categoryId;
    categoriesCreated = categoryResult.categoriesCreated;

    // Check if book already exists in this category
    final existingBook = await _findBookInCategory(title, categoryId);

    if (existingBook != null) {
      // Update existing book
      await _updateBookContent(existingBook.id, filePath);
      _log.info('Updated existing book in custom folder: $title');
      return _FileProcessResult(
        wasAdded: false,
        wasUpdated: true,
        categoriesCreated: categoriesCreated,
      );
    }

    // Add new book
    await _addNewBook(filePath, categoryId, title);
    return _FileProcessResult(
      wasAdded: true,
      wasUpdated: false,
      categoriesCreated: categoriesCreated,
    );
  }

  /// Build category path for a custom folder file
  /// Returns: ["ספרים אישיים", folder.name, ...subfolders]
  List<String> _buildCustomFolderCategoryPath(
    String filePath,
    CustomFolder folder,
  ) {
    final result = <String>['ספרים אישיים', folder.name];

    // Get relative path within the custom folder
    final normalizedFile = path.normalize(filePath);
    final normalizedBase = path.normalize(folder.path);

    if (normalizedFile.startsWith(normalizedBase)) {
      String relativePath = normalizedFile.substring(normalizedBase.length);
      if (relativePath.startsWith(path.separator)) {
        relativePath = relativePath.substring(1);
      }

      // Split into parts and remove the filename
      final parts = path.split(relativePath);
      if (parts.length > 1) {
        // Add subdirectories (excluding the filename)
        result.addAll(parts.sublist(0, parts.length - 1));
      }
    }

    return result;
  }

  /// Scan links folder and sync JSON files to database
  Future<FileSyncResult> _scanAndSyncLinkFiles(String folderPath) async {
    int addedLinks = 0;
    int deletedFiles = 0;
    int skippedFiles = 0;
    final errors = <String>[];

    // Load books cache for link processing
    await _loadBooksCache();

    // Find JSON files in links folder
    final linksDir = Directory(folderPath);
    final jsonFiles = <String>[];

    await for (final entity in linksDir.list()) {
      if (entity is File && path.extension(entity.path) == '.json') {
        jsonFiles.add(entity.path);
      }
    }

    if (jsonFiles.isEmpty) {
      _log.info('No JSON files found in links folder');
      return const FileSyncResult();
    }

    _log.info('Found ${jsonFiles.length} JSON link files to process');

    int processed = 0;
    for (final filePath in jsonFiles) {
      try {
        final linksProcessed = await _processLinkFile(filePath);
        if (linksProcessed > 0) {
          addedLinks += linksProcessed;

          // Delete the JSON file after successful processing
          try {
            await File(filePath).delete();
            deletedFiles++;
            _log.info(
                'Deleted processed link file: ${path.basename(filePath)}');
          } catch (e) {
            _log.warning('Failed to delete link file $filePath: $e');
          }
        } else {
          skippedFiles++;
        }

        processed++;
        _reportProgress(
          0.6 + (0.3 * processed / jsonFiles.length),
          'מעבד קישורים ${path.basename(filePath)}...',
        );
      } catch (e, stackTrace) {
        _log.warning('Error processing link file $filePath', e, stackTrace);
        errors.add('Error processing ${path.basename(filePath)}: $e');
      }
    }

    return FileSyncResult(
      addedLinks: addedLinks,
      deletedFiles: deletedFiles,
      skippedFiles: skippedFiles,
      errors: errors,
    );
  }

  /// Load all books into cache for link processing
  Future<void> _loadBooksCache() async {
    if (_bookTitleToId.isNotEmpty) return; // Already loaded

    _log.info('Loading books cache for link processing...');
    // Use repository's getAllBooks method
    final books = await _repository.getAllBooks();
    for (final book in books) {
      _bookTitleToId[book.title] = book.id;
    }
    _log.info('Loaded ${_bookTitleToId.length} books to cache');
  }

  /// Load lines cache for a specific book
  Future<void> _loadBookLinesCache(int bookId) async {
    if (_bookLineIndexToId.containsKey(bookId)) return;

    // Use repository methods to get book and lines
    final book = await _repository.getBook(bookId);
    final totalLines = book?.totalLines ?? 0;
    final arr = List<int>.filled(totalLines, 0);

    if (totalLines > 0) {
      // Use repository's getLines method
      final lines = await _repository.getLines(bookId, 0, totalLines - 1);
      for (final ln in lines) {
        final idx = ln.lineIndex;
        if (idx >= 0 && idx < arr.length) {
          arr[idx] = ln.id;
        }
      }
    }

    _bookLineIndexToId[bookId] = arr;
  }

  /// Process a single link JSON file
  Future<int> _processLinkFile(String linkFile) async {
    final bookTitle = path
        .basenameWithoutExtension(path.basename(linkFile))
        .replaceAll('_links', '');
    _log.fine('Processing link file for book: $bookTitle');

    // Find source book
    final sourceBookId = _bookTitleToId[bookTitle];
    if (sourceBookId == null) {
      _log.warning('Source book not found for links: $bookTitle');
      return 0;
    }

    // Load lines cache for source book
    await _loadBookLinesCache(sourceBookId);

    try {
      final file = File(linkFile);
      final content = await file.readAsString();
      final linksData = (jsonDecode(content) as List<dynamic>)
          .map((item) => _LinkData.fromJson(item as Map<String, dynamic>))
          .toList();

      // Prepare batch of links
      final linksToInsert = <Link>[];
      var skipped = 0;

      for (final linkData in linksData) {
        try {
          // Handle paths with backslashes
          final pathStr = linkData.path2;
          final targetTitle = pathStr.contains('\\')
              ? pathStr.split('\\').last.replaceAll(RegExp(r'\.[^.]*$'), '')
              : path.basenameWithoutExtension(pathStr);

          // Find target book
          final targetBookId = _bookTitleToId[targetTitle];
          if (targetBookId == null) {
            skipped++;
            continue;
          }

          // Load lines cache for target book
          await _loadBookLinesCache(targetBookId);

          // Adjust indices from 1-based to 0-based
          final sourceLineIndex = (linkData.lineIndex1.toInt() - 1)
              .clamp(0, double.infinity)
              .toInt();
          final targetLineIndex = (linkData.lineIndex2.toInt() - 1)
              .clamp(0, double.infinity)
              .toInt();

          // Get line IDs from cache
          final sourceLineArr = _bookLineIndexToId[sourceBookId];
          final targetLineArr = _bookLineIndexToId[targetBookId];

          final sourceLineId = (sourceLineArr != null &&
                  sourceLineIndex >= 0 &&
                  sourceLineIndex < sourceLineArr.length)
              ? (sourceLineArr[sourceLineIndex] != 0
                  ? sourceLineArr[sourceLineIndex]
                  : null)
              : null;
          final targetLineId = (targetLineArr != null &&
                  targetLineIndex >= 0 &&
                  targetLineIndex < targetLineArr.length)
              ? (targetLineArr[targetLineIndex] != 0
                  ? targetLineArr[targetLineIndex]
                  : null)
              : null;

          if (sourceLineId == null || targetLineId == null) {
            skipped++;
            continue;
          }

          linksToInsert.add(Link(
            sourceBookId: sourceBookId,
            targetBookId: targetBookId,
            sourceLineId: sourceLineId,
            targetLineId: targetLineId,
            connectionType: ConnectionType.fromString(linkData.connectionType),
          ));

          // Insert in batches of 1000 using repository batch method
          if (linksToInsert.length >= 1000) {
            await _repository.insertLinksBatch(linksToInsert);
            linksToInsert.clear();
          }
        } catch (e) {
          skipped++;
        }
      }

      // Insert remaining links using repository batch method
      if (linksToInsert.isNotEmpty) {
        await _repository.insertLinksBatch(linksToInsert);
      }

      final processed = linksData.length - skipped;
      _log.info('Processed $processed links from ${path.basename(linkFile)}');
      return processed;
    } catch (e, stackTrace) {
      _log.warning('Error processing link file: ${path.basename(linkFile)}', e,
          stackTrace);
      return 0;
    }
  }

  /// Find new or updated TXT files to sync to the database
  /// Returns all TXT files - the processing logic will determine if they should be added or updated
  Future<List<String>> _findNewTxtFiles(String basePath) async {
    final newFiles = <String>[];
    final dir = Directory(basePath);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && path.extension(entity.path) == '.txt') {
        final title = path.basenameWithoutExtension(entity.path);

        // Add all TXT files - _processNewFile will handle add vs update logic
        // based on the full category path, not just the title
        newFiles.add(entity.path);
        _log.fine('Found TXT file to process: $title');
      }
    }

    return newFiles;
  }

  /// Process a new file and add it to the database
  Future<_FileProcessResult> _processNewFile(
    String filePath,
    String basePath,
  ) async {
    final title = path.basenameWithoutExtension(filePath);
    _log.info('Processing file: $title');

    // Parse path to get category hierarchy
    final categoryPath = _parsePathToCategories(filePath, basePath);

    if (categoryPath.isEmpty) {
      _log.warning('Could not parse category path for: $filePath');
      return const _FileProcessResult(wasAdded: false, wasUpdated: false);
    }

    // Find or create category chain
    int categoriesCreated = 0;
    final categoryResult = await _findOrCreateCategoryChain(categoryPath);
    final categoryId = categoryResult.categoryId;
    categoriesCreated = categoryResult.categoriesCreated;

    // Check if book already exists in this category
    final existingBook = await _findBookInCategory(title, categoryId);

    if (existingBook != null) {
      // Update existing book in the same category
      await _updateBookContent(existingBook.id, filePath);
      _log.info('Updated existing book in same category: $title');
      return _FileProcessResult(
        wasAdded: false,
        wasUpdated: true,
        categoriesCreated: categoriesCreated,
      );
    }

    // Book doesn't exist in this category - add as new book
    // Note: Books with the same name can exist in different categories
    await _addNewBook(filePath, categoryId, title);
    return _FileProcessResult(
      wasAdded: true,
      wasUpdated: false,
      categoriesCreated: categoriesCreated,
    );
  }

  /// Parse file path to extract category hierarchy
  List<String> _parsePathToCategories(String filePath, String basePath) {
    // Normalize paths
    final normalizedFile = path.normalize(filePath);
    final normalizedBase = path.normalize(basePath);

    // Get relative path
    String relativePath;
    if (normalizedFile.startsWith(normalizedBase)) {
      relativePath = normalizedFile.substring(normalizedBase.length);
      if (relativePath.startsWith(path.separator)) {
        relativePath = relativePath.substring(1);
      }
    } else {
      return [];
    }

    // Split into parts and remove the filename
    final parts = path.split(relativePath);
    if (parts.isEmpty) return [];

    // Remove the filename (last part)
    return parts.sublist(0, parts.length - 1);
  }

  /// Find or create a category chain and return the leaf category ID
  Future<_CategoryResult> _findOrCreateCategoryChain(
    List<String> categoryPath,
  ) async {
    int? currentParentId;
    int categoriesCreated = 0;

    for (int i = 0; i < categoryPath.length; i++) {
      final categoryName = categoryPath[i];
      final level = i;

      // Try to find existing category
      final existingCategory =
          await _findCategory(categoryName, currentParentId);

      if (existingCategory != null) {
        currentParentId = existingCategory.id;
      } else {
        // Create new category using repository method
        // Repository's insertCategory handles duplicates and returns existing ID if found
        final category = Category(
          id: _nextCategoryId++,
          parentId: currentParentId,
          title: categoryName,
          level: level,
        );

        final insertedId = await _repository.insertCategory(category);
        currentParentId = insertedId;
        categoriesCreated++;

        _log.info('Created new category: $categoryName (id: $insertedId)');
      }
    }

    return _CategoryResult(
      categoryId: currentParentId!,
      categoriesCreated: categoriesCreated,
    );
  }

  /// Find a category by name and parent ID
  Future<Category?> _findCategory(String name, int? parentId) async {
    // Use repository methods to get categories by parent
    final categories = parentId == null
        ? await _repository.getRootCategories()
        : await _repository.getCategoryChildren(parentId);

    // Find category with matching name
    for (final cat in categories) {
      if (cat.title == name) {
        return cat;
      }
    }
    return null;
  }

  /// Find a book in a specific category
  Future<Book?> _findBookInCategory(String title, int categoryId) async {
    // Use repository method to get books by category
    final books = await _repository.getBooksByCategory(categoryId);

    // Find book with matching title
    for (final book in books) {
      if (book.title == title) {
        return book;
      }
    }
    return null;
  }

  /// Update content of an existing book
  Future<void> _updateBookContent(int bookId, String filePath) async {
    _log.info('Updating book content for ID: $bookId');

    // Clear existing book content using repository extension method
    // This preserves the book metadata but replaces content
    await _repository.clearBookContent(bookId);

    // Read and process new content
    final file = File(filePath);
    final content = await file.readAsString(encoding: utf8);
    final lines = content.split('\n');

    // Process lines and TOC entries
    await _processBookLines(bookId, lines);

    // Update total lines using repository method
    await _repository.updateBookTotalLines(bookId, lines.length);

    _log.info('Updated book $bookId with ${lines.length} lines');
  }

  /// Add a new book to the database
  Future<void> _addNewBook(
    String filePath,
    int categoryId,
    String title,
  ) async {
    _log.info('Adding new book: $title to category $categoryId');

    // Read file content
    final file = File(filePath);
    final content = await file.readAsString(encoding: utf8);
    final lines = content.split('\n');

    // Get or create default source using repository method
    final sourceId = await _getOrCreateDefaultSource();

    // Create book using repository method
    final bookId = _nextBookId++;
    final book = Book(
      id: bookId,
      categoryId: categoryId,
      sourceId: sourceId,
      title: title,
      order: 999.0,
      totalLines: lines.length,
      isBaseBook: false,
    );

    // Repository's insertBook handles the insertion
    await _repository.insertBook(book);

    // Process lines and TOC entries
    await _processBookLines(bookId, lines);

    // Update total lines using repository method
    await _repository.updateBookTotalLines(bookId, lines.length);

    _log.info(
        'Added new book: $title (id: $bookId) with ${lines.length} lines');
  }

  /// Get or create a default source for user-added books
  Future<int> _getOrCreateDefaultSource() async {
    const sourceName = 'user_added';
    // Use repository method to insert source (handles existing check internally)
    return await _repository.insertSource(sourceName);
  }

  /// Process book lines and create TOC entries
  Future<void> _processBookLines(int bookId, List<String> lines) async {
    final linesBatch = <Line>[];
    final tocEntriesBatch = <TocEntry>[];
    final parentStack = <int, int>{};

    const batchSize = 1000;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final plainText = _cleanHtml(line);
      final level = _detectHeaderLevel(line);

      if (level > 0 && plainText.trim().isNotEmpty) {
        // This is a TOC entry
        int? parentId;
        for (int l = level - 1; l >= 1; l--) {
          if (parentStack.containsKey(l)) {
            parentId = parentStack[l];
            break;
          }
        }

        final currentTocEntryId = _nextTocEntryId++;
        final currentLineId = _nextLineId++;

        // Add TOC entry
        tocEntriesBatch.add(TocEntry(
          id: currentTocEntryId,
          bookId: bookId,
          parentId: parentId,
          text: plainText,
          level: level,
          lineId: currentLineId,
          isLastChild: false,
          hasChildren: false,
        ));

        parentStack[level] = currentTocEntryId;

        // Add line
        linesBatch.add(Line(
          id: currentLineId,
          bookId: bookId,
          lineIndex: lineIndex,
          content: line,
        ));
      } else {
        // Regular line
        final currentLineId = _nextLineId++;

        linesBatch.add(Line(
          id: currentLineId,
          bookId: bookId,
          lineIndex: lineIndex,
          content: line,
        ));
      }

      // Flush batches using repository batch methods
      if (linesBatch.length >= batchSize) {
        await _repository.insertLinesBatch(linesBatch);
        linesBatch.clear();
      }
      if (tocEntriesBatch.length >= batchSize) {
        await _repository.insertTocEntriesBatch(tocEntriesBatch);
        tocEntriesBatch.clear();
      }
    }

    // Flush remaining using repository batch methods
    if (tocEntriesBatch.isNotEmpty) {
      await _repository.insertTocEntriesBatch(tocEntriesBatch);
    }
    if (linesBatch.isNotEmpty) {
      await _repository.insertLinesBatch(linesBatch);
    }
  }

  /// Clean HTML tags from text
  String _cleanHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Detect header level from HTML tags
  int _detectHeaderLevel(String line) {
    final match = RegExp(r'<h(\d)>').firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  /// Remove empty directories recursively
  Future<void> _removeEmptyDirectories(String basePath) async {
    final dir = Directory(basePath);
    final entities = await dir.list(recursive: true).toList();

    // Sort from deepest to shallowest
    entities.sort((a, b) => b.path.length.compareTo(a.path.length));

    for (final entity in entities) {
      if (entity is Directory) {
        try {
          final contents = await entity.list().toList();
          if (contents.isEmpty) {
            await entity.delete();
            _log.fine('Deleted empty directory: ${entity.path}');
          }
        } catch (e) {
          // Ignore errors when deleting directories
        }
      }
    }
  }

  /// Report progress to callback
  void _reportProgress(double progress, String message) {
    onProgress?.call(progress, message);
    _log.fine('Progress: ${(progress * 100).toStringAsFixed(1)}% - $message');
  }

  /// Check for acronym.json file in "אודות התוכנה" folder and update book_acronym table
  /// Updates existing books by matching book_title to book.title in the database
  /// After processing, deletes the acronym.json file
  Future<_AcronymProcessResult> _checkAndProcessAcronymFile(
      String libraryPath) async {
    final errors = <String>[];
    int updatedBooks = 0;
    int newTerms = 0;

    try {
      final acronymPath =
          path.join(libraryPath, 'אוצריא', 'אודות התוכנה', 'acronym.json');
      final acronymFile = File(acronymPath);

      if (!await acronymFile.exists()) {
        _log.fine('No acronym.json file found at $acronymPath');
        return const _AcronymProcessResult(processed: false);
      }

      _log.info('Found acronym.json file, processing...');

      // Read and parse the file
      final content = await acronymFile.readAsString();
      final decoded = jsonDecode(content);

      // Convert to list format (handle both Map and List)
      List<Map<String, dynamic>> acronymEntries = [];
      if (decoded is List) {
        acronymEntries = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        // Convert map to list format
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            acronymEntries.add(value);
          }
        });
      }

      _log.info('Loaded ${acronymEntries.length} acronym entries from file');

      // Process each entry - match by book_title to find the book in DB
      for (final entry in acronymEntries) {
        final bookTitle = entry['book_title'] as String?;
        final termsRaw = entry['terms'] as String?;

        if (bookTitle == null || bookTitle.isEmpty) {
          continue;
        }

        // Find the book by title in the database
        final existingBook = await _repository.checkBookExists(bookTitle);
        if (existingBook == null) {
          _log.fine('Book not found in DB for acronym update: $bookTitle');
          continue;
        }

        final bookId = existingBook.id;

        // Parse terms (comma-separated)
        final terms = (termsRaw == null || termsRaw.isEmpty)
            ? <String>[]
            : termsRaw
                .split(',')
                .map((t) => _sanitizeAcronymTerm(t))
                .where((t) => t.isNotEmpty)
                .toList();

        // Full replacement: delete all existing terms and insert new ones
        // This handles additions, removals, and updates
        await _repository.deleteBookAcronyms(bookId);

        if (terms.isNotEmpty) {
          await _repository.bulkInsertBookAcronyms(bookId, terms);
          newTerms += terms.length;
        }

        updatedBooks++;
        _log.fine(
            'Replaced acronym terms for book: $bookTitle (id: $bookId) with ${terms.length} terms');
      }

      // Delete the acronym.json file after successful processing
      try {
        await acronymFile.delete();
        _log.info('Deleted acronym.json file after processing');
      } catch (e) {
        _log.warning('Failed to delete acronym.json file: $e');
        errors.add('Failed to delete acronym.json: $e');
      }

      _log.info(
          'Acronym processing complete: $updatedBooks books updated, $newTerms new terms added');

      return _AcronymProcessResult(
        processed: true,
        updatedBooks: updatedBooks,
        newTerms: newTerms,
        errors: errors,
      );
    } catch (e, stackTrace) {
      _log.warning('Error processing acronym.json', e, stackTrace);
      errors.add('Error processing acronym.json: $e');
      return _AcronymProcessResult(
        processed: false,
        errors: errors,
      );
    }
  }

  /// Sanitizes an acronym term by removing diacritics, maqaf, gershayim and geresh
  String _sanitizeAcronymTerm(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    // Remove Hebrew diacritics (nikud) - Unicode range 0x0591-0x05C7
    s = s.replaceAll(RegExp(r'[\u0591-\u05C7]'), '');

    // Replace maqaf (Hebrew hyphen) with space
    s = s.replaceAll('\u05BE', ' ');

    // Remove Hebrew gershayim (״) and geresh (׳)
    s = s.replaceAll('\u05F4', ''); // gershayim
    s = s.replaceAll('\u05F3', ''); // geresh

    // Clean up multiple spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }
}

/// Result of processing a single file
class _FileProcessResult {
  final bool wasAdded;
  final bool wasUpdated;
  final int categoriesCreated;

  const _FileProcessResult({
    required this.wasAdded,
    required this.wasUpdated,
    this.categoriesCreated = 0,
  });
}

/// Result of finding/creating category chain
class _CategoryResult {
  final int categoryId;
  final int categoriesCreated;

  const _CategoryResult({
    required this.categoryId,
    required this.categoriesCreated,
  });
}

/// Result of restoring a folder from DB
class RestoreFolderResult {
  final int restoredBooks;
  final int restoredCategories;
  final List<String> errors;

  const RestoreFolderResult({
    this.restoredBooks = 0,
    this.restoredCategories = 0,
    this.errors = const [],
  });
}

/// Internal result for recursive restore
class _RestoreResult {
  final int books;
  final int categories;
  final List<String> errors;

  const _RestoreResult({
    this.books = 0,
    this.categories = 0,
    this.errors = const [],
  });
}

/// Data class for deserializing link data from JSON files
class _LinkData {
  final String heRef2;
  final double lineIndex1;
  final String path2;
  final double lineIndex2;
  final String connectionType;

  const _LinkData({
    required this.heRef2,
    required this.lineIndex1,
    required this.path2,
    required this.lineIndex2,
    this.connectionType = '',
  });

  factory _LinkData.fromJson(Map<String, dynamic> json) {
    return _LinkData(
      heRef2: json['heRef_2'] as String? ?? '',
      lineIndex1: (json['line_index_1'] as num?)?.toDouble() ?? 0,
      path2: json['path_2'] as String? ?? '',
      lineIndex2: (json['line_index_2'] as num?)?.toDouble() ?? 0,
      connectionType: json['Conection Type'] as String? ?? '',
    );
  }
}

/// Result of processing acronym.json file
class _AcronymProcessResult {
  final bool processed;
  final int updatedBooks;
  final int newTerms;
  final List<String> errors;

  const _AcronymProcessResult({
    this.processed = false,
    this.updatedBooks = 0,
    this.newTerms = 0,
    this.errors = const [],
  });
}
