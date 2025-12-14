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
    final db = await _repository.database.database;

    // Get max book ID
    final bookResult = await db.rawQuery('SELECT MAX(id) as maxId FROM book');
    _nextBookId = ((bookResult.first['maxId'] as int?) ?? 0) + 1;

    // Get max line ID
    final lineResult = await db.rawQuery('SELECT MAX(id) as maxId FROM line');
    _nextLineId = ((lineResult.first['maxId'] as int?) ?? 0) + 1;

    // Get max TOC entry ID
    final tocResult =
        await db.rawQuery('SELECT MAX(id) as maxId FROM tocEntry');
    _nextTocEntryId = ((tocResult.first['maxId'] as int?) ?? 0) + 1;

    // Get max category ID
    final catResult =
        await db.rawQuery('SELECT MAX(id) as maxId FROM category');
    _nextCategoryId = ((catResult.first['maxId'] as int?) ?? 0) + 1;

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
    final books = await _repository.getAllBooks();
    for (final book in books) {
      _bookTitleToId[book.title] = book.id;
    }
    _log.info('Loaded ${_bookTitleToId.length} books to cache');
  }

  /// Load lines cache for a specific book
  Future<void> _loadBookLinesCache(int bookId) async {
    if (_bookLineIndexToId.containsKey(bookId)) return;

    final book = await _repository.getBook(bookId);
    final totalLines = book?.totalLines ?? 0;
    final arr = List<int>.filled(totalLines, 0);

    if (totalLines > 0) {
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

          // Insert in batches of 1000
          if (linksToInsert.length >= 1000) {
            await _repository.insertLinksBatch(linksToInsert);
            linksToInsert.clear();
          }
        } catch (e) {
          skipped++;
        }
      }

      // Insert remaining links
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

        // Skip notes files
        if (title.startsWith('הערות על ')) {
          continue;
        }

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
        // Create new category
        final newCategoryId = _nextCategoryId++;
        final category = Category(
          id: newCategoryId,
          parentId: currentParentId,
          title: categoryName,
          level: level,
        );

        await _repository.insertCategory(category);
        currentParentId = newCategoryId;
        categoriesCreated++;

        _log.info('Created new category: $categoryName (id: $newCategoryId)');
      }
    }

    return _CategoryResult(
      categoryId: currentParentId!,
      categoriesCreated: categoriesCreated,
    );
  }

  /// Find a category by name and parent ID
  Future<Category?> _findCategory(String name, int? parentId) async {
    final db = await _repository.database.database;

    final result = await db.rawQuery(
      parentId == null
          ? 'SELECT * FROM category WHERE title = ? AND parentId IS NULL'
          : 'SELECT * FROM category WHERE title = ? AND parentId = ?',
      parentId == null ? [name] : [name, parentId],
    );

    if (result.isEmpty) return null;

    return Category(
      id: result.first['id'] as int,
      parentId: result.first['parentId'] as int?,
      title: result.first['title'] as String,
      level: result.first['level'] as int,
    );
  }

  /// Find a book in a specific category
  Future<Book?> _findBookInCategory(String title, int categoryId) async {
    final db = await _repository.database.database;

    final result = await db.rawQuery(
      'SELECT * FROM book WHERE title = ? AND categoryId = ?',
      [title, categoryId],
    );

    if (result.isEmpty) return null;

    return Book(
      id: result.first['id'] as int,
      categoryId: result.first['categoryId'] as int,
      sourceId: result.first['sourceId'] as int,
      title: result.first['title'] as String,
      heShortDesc: result.first['heShortDesc'] as String?,
      order: (result.first['orderIndex'] as num?)?.toDouble() ?? 999.0,
      totalLines: result.first['totalLines'] as int? ?? 0,
      isBaseBook: (result.first['isBaseBook'] as int?) == 1,
    );
  }

  /// Update content of an existing book
  Future<void> _updateBookContent(int bookId, String filePath) async {
    _log.info('Updating book content for ID: $bookId');

    final db = await _repository.database.database;

    // Delete existing lines and TOC entries
    await db.rawDelete('DELETE FROM line WHERE bookId = ?', [bookId]);
    await db.rawDelete('DELETE FROM tocEntry WHERE bookId = ?', [bookId]);

    // Read and process new content
    final file = File(filePath);
    final content = await file.readAsString(encoding: utf8);
    final lines = content.split('\n');

    // Process lines and TOC entries
    await _processBookLines(bookId, lines);

    // Update total lines
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

    // Get or create default source
    final sourceId = await _getOrCreateDefaultSource();

    // Create book
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

    await _repository.insertBook(book);

    // Process lines and TOC entries
    await _processBookLines(bookId, lines);

    // Update total lines
    await _repository.updateBookTotalLines(bookId, lines.length);

    _log.info(
        'Added new book: $title (id: $bookId) with ${lines.length} lines');
  }

  /// Get or create a default source for user-added books
  Future<int> _getOrCreateDefaultSource() async {
    final db = await _repository.database.database;

    const sourceName = 'user_added';

    // Check if source exists
    final result = await db.rawQuery(
      'SELECT id FROM source WHERE name = ?',
      [sourceName],
    );

    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }

    // Create new source
    await db.rawInsert(
      'INSERT INTO source (name) VALUES (?)',
      [sourceName],
    );

    final newResult = await db.rawQuery(
      'SELECT id FROM source WHERE name = ?',
      [sourceName],
    );

    return newResult.first['id'] as int;
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

      // Flush batches
      if (linesBatch.length >= batchSize) {
        await _repository.insertLinesBatch(linesBatch);
        linesBatch.clear();
      }
      if (tocEntriesBatch.length >= batchSize) {
        await _repository.insertTocEntriesBatch(tocEntriesBatch);
        tocEntriesBatch.clear();
      }
    }

    // Flush remaining
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
