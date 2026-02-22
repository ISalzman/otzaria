import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:otzaria/utils/ref_helper.dart';

class IndexingRepository {
  final TantivyDataProvider _tantivyDataProvider;

  IndexingRepository(this._tantivyDataProvider);

  static final RegExp _pdfInvisibleChars = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069]'
    r'|\uFEFF',
  );

  static final RegExp _pdfLettersAndDigits =
      RegExp(r'[\u05D0-\u05EAa-zA-Z0-9]');
  static final RegExp _pdfNonLettersNonSpace =
      RegExp(r'[^\s\u05D0-\u05EAa-zA-Z0-9]');

  static String _normalizePdfTextForIndexing(String input) {
    var text = stripHtmlIfNeeded(input);
    text = text.replaceAll(_pdfInvisibleChars, '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = removeVolwels(text);
    return text;
  }

  static bool _isProbablyGarbagePdfText(String normalizedText) {
    final compact = normalizedText.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return true;

    final letters = _pdfLettersAndDigits.allMatches(compact).length;
    if (letters == 0) return true;

    final nonLetters = _pdfNonLettersNonSpace.allMatches(compact).length;
    final ratioLetters = letters / compact.length;

    // Heuristic: dot/bullet/garbage glyph-mapped text tends to be mostly
    // punctuation/symbols with very few letters.
    if (compact.length >= 50 && ratioLetters < 0.10) return true;
    if (compact.length >= 20 && ratioLetters < 0.20 && nonLetters > letters) {
      return true;
    }

    return false;
  }

  /// Indexes all books in the provided library.
  ///
  /// [library] The library containing books to index
  /// [onProgress] Callback function to report progress
  Future<void> indexAllBooks(
    Library library,
    void Function(int processed, int total) onProgress,
  ) async {
    _tantivyDataProvider.isIndexing.value = true;
    final allBooks = library.getAllBooks();

    // Filter out books with externalLibraryId (external library books should not be indexed)
    final booksToIndex =
        allBooks.where((book) => book.externalLibraryId == null).toList();

    final totalBooks = booksToIndex.length;
    int processedBooks = 0;
    int actuallyIndexed = 0;
    int skipped = 0;
    int errors = 0;

    debugPrint('📚 התחלת אינדוקס: $totalBooks ספרים');
    debugPrint(
        '📊 ספרים שכבר מאונדקסים: ${_tantivyDataProvider.booksDone.length}');

    for (Book book in booksToIndex) {
      // Check if indexing was cancelled
      if (!_tantivyDataProvider.isIndexing.value) {
        debugPrint('⚠️ אינדוקס בוטל על ידי המשתמש');
        return;
      }

      try {
        // Check if this book has already been indexed
        if (book is TextBook) {
          if (!_tantivyDataProvider.booksDone
              .contains("${book.title}textBook")) {
            if (_tantivyDataProvider.booksDone.contains(
                sha1.convert(utf8.encode((await book.text))).toString())) {
              debugPrint('⏭️ דילוג על ספר קיים (hash): ${book.title}');
              _tantivyDataProvider.booksDone.add("${book.title}textBook");
              skipped++;
            } else {
              debugPrint('📖 מאנדקס ספר טקסט: ${book.title}');
              await _indexTextBook(book);
              _tantivyDataProvider.booksDone.add("${book.title}textBook");
              actuallyIndexed++;
            }
          } else {
            debugPrint('⏭️ דילוג על ספר טקסט שכבר מאונדקס: ${book.title}');
            skipped++;
          }
        } else if (book is PdfBook) {
          if (!_tantivyDataProvider.booksDone
              .contains("${book.title}pdfBook")) {
            // Try to get file hash for deduplication
            String? fileHash;
            try {
              // Try to load from database first
              final pdfBytes =
                  await SqliteDataProvider.instance.getPdfBytesFromDb(book);
              if (pdfBytes != null && pdfBytes.isNotEmpty) {
                fileHash = sha1.convert(pdfBytes).toString();
              } else {
                // Fallback to file if exists
                final file = File(book.path);
                if (await file.exists()) {
                  fileHash = sha1.convert(await file.readAsBytes()).toString();
                }
              }
            } catch (e) {
              debugPrint('⚠️ לא ניתן לחשב hash עבור ${book.title}: $e');
            }

            if (fileHash != null &&
                _tantivyDataProvider.booksDone.contains(fileHash)) {
              debugPrint('⏭️ דילוג על PDF קיים (hash): ${book.title}');
              _tantivyDataProvider.booksDone.add("${book.title}pdfBook");
              skipped++;
            } else {
              debugPrint('📄 מאנדקס PDF: ${book.title}');
              await _indexPdfBook(book);
              _tantivyDataProvider.booksDone.add("${book.title}pdfBook");
              actuallyIndexed++;
            }
          } else {
            debugPrint('⏭️ דילוג על PDF שכבר מאונדקס: ${book.title}');
            skipped++;
          }
        } else if (book is ExternalLibraryBook) {
          if (!_tantivyDataProvider.booksDone
              .contains("${book.title}externalBook")) {
            final idHash = sha1.convert(utf8.encode(book.link)).toString();
            if (_tantivyDataProvider.booksDone.contains(idHash)) {
              debugPrint('⏭️ דילוג על ספר חיצוני קיים (hash): ${book.title}');
              _tantivyDataProvider.booksDone.add("${book.title}externalBook");
              skipped++;
            } else {
              debugPrint('🔗 מאנדקס ספר חיצוני: ${book.title}');
              await _indexExternalLibraryBook(book);
              _tantivyDataProvider.booksDone.add("${book.title}externalBook");
              actuallyIndexed++;
            }
          } else {
            debugPrint('⏭️ דילוג על ספר חיצוני שכבר מאונדקס: ${book.title}');
            skipped++;
          }
        }
        processedBooks++;

        // Commit every 25 books to save progress (optimized for 8GB RAM)
        if (processedBooks % 25 == 0) {
          debugPrint('💾 שומר אינדקס (commit)...');
          final index = await _tantivyDataProvider.engine;
          await index.commit();
          saveIndexedBooks();
        }

        // Report progress every 50 books
        if (processedBooks % 50 == 0) {
          debugPrint(
              '📈 התקדמות: $processedBooks/$totalBooks (מאונדקסים: $actuallyIndexed, דולגו: $skipped, שגיאות: $errors)');
        }

        // Report progress
        onProgress(processedBooks, totalBooks);
      } catch (e) {
        // Use async error handling to prevent event loop blocking
        await Future.microtask(() {
          debugPrint('❌ שגיאה באינדוקס של ${book.title}: $e');
        });
        errors++;
        processedBooks++;
        // Still report progress even after error
        onProgress(processedBooks, totalBooks);
        // Yield control back to event loop after error
        await Future.delayed(Duration.zero);
      }

      await Future.delayed(Duration.zero);
    }

    debugPrint('✅ אינדוקס הושלם!');
    debugPrint('   📊 סה"כ: $totalBooks ספרים');
    debugPrint('   ✅ מאונדקסים: $actuallyIndexed');
    debugPrint('   ⏭️ דולגו: $skipped');
    debugPrint('   ❌ שגיאות: $errors');

    // Final commit to ensure everything is saved
    debugPrint('💾 שומר אינדקס סופי (final commit)...');
    final index = await _tantivyDataProvider.engine;
    await index.commit();
    saveIndexedBooks();
    debugPrint('✅ אינדקס נשמר בהצלחה!');

    // Reset indexing flag after completion
    _tantivyDataProvider.isIndexing.value = false;
  }

  /// Indexes a text-based book by processing its content and adding it to the search index.
  Future<void> _indexTextBook(TextBook book) async {
    final index = await _tantivyDataProvider.engine;

    try {
      // Try to get text directly from DB if we have categoryId
      String? text;
      if (book.categoryId != null) {
        debugPrint(
            '   🔍 מנסה לקרוא מ-DB: ${book.title} (categoryId: ${book.categoryId})');
        text = await SqliteDataProvider.instance.getBookTextFromDb(
          book.title,
          book.categoryId,
          book.fileType ?? 'txt',
        );
      }

      // Fallback to regular method
      if (text == null || text.isEmpty) {
        debugPrint('   🔍 מנסה לקרוא דרך LibraryProvider: ${book.title}');
        final bookText = await book.text;
        text = bookText;
      }

      if (text.isEmpty) {
        debugPrint(
            '⚠️ ספר ריק: ${book.title} (categoryId: ${book.categoryId}) - מדלג');
        return;
      }

      final title = book.title;
      final topics = "/${book.topics.replaceAll(', ', '/')}";

      final texts = text.split('\n');

      if (texts.length <= 1) {
        debugPrint(
            '⚠️ ספר עם שורה אחת בלבד: ${book.title} (${texts.length} שורות) - מדלג');
        return;
      }

      List<String> reference = [];

      debugPrint('   📝 מאנדקס ${texts.length} שורות מ-$title');

      // Index each line separately
      for (int i = 0; i < texts.length; i++) {
        if (!_tantivyDataProvider.isIndexing.value) {
          return;
        }

        // Yield control periodically to prevent blocking
        if (i % 100 == 0) {
          await Future.delayed(Duration.zero);
        }

        String line = texts[i];
        // get the reference from the headers
        if (line.startsWith('<h')) {
          if (reference.isNotEmpty &&
              reference.any((element) =>
                  element.substring(0, 4) == line.substring(0, 4))) {
            reference.removeRange(
                reference.indexWhere((element) =>
                    element.substring(0, 4) == line.substring(0, 4)),
                reference.length);
          }
          reference.add(line);

          // Index the header also into the main search index so in-book search
          // can find headings that are displayed and highlighted.
          var headerLine = stripHtmlIfNeeded(line);
          headerLine = removeVolwels(headerLine);
          index.addDocument(
              id: BigInt.from(DateTime.now().microsecondsSinceEpoch),
              title: title,
              reference: stripHtmlIfNeeded(reference.join(', ')),
              topics: '$topics/$title',
              text: headerLine,
              segment: BigInt.from(i),
              isPdf: false,
              filePath: '');
        } else {
          line = stripHtmlIfNeeded(line);
          line = removeVolwels(line);

          // Add to search index
          index.addDocument(
              id: BigInt.from(DateTime.now().microsecondsSinceEpoch),
              title: title,
              reference: stripHtmlIfNeeded(reference.join(', ')),
              topics: '$topics/$title',
              text: line,
              segment: BigInt.from(i),
              isPdf: false,
              filePath: '');
        }
      }

      // Don't commit after every book - too slow!
      // We'll commit periodically in indexAllBooks instead
      debugPrint('   ✅ סיים אינדוקס של $title (${texts.length} שורות)');
    } catch (e) {
      debugPrint('❌ שגיאה באינדוקס של ${book.title}: $e');
      rethrow;
    }
  }

  /// Indexes an external library book (e.g., Otzar) by indexing its metadata
  /// so the book becomes discoverable in searches.
  Future<void> _indexExternalLibraryBook(ExternalLibraryBook book) async {
    final index = await _tantivyDataProvider.engine;

    final title = book.title;
    final topics = "/${book.topics.replaceAll(', ', '/')}";

    // Combine available metadata into a single text blob for indexing
    final parts = <String>[];
    parts.add(title);
    if (book.author != null) parts.add(book.author!);
    if (book.heShortDesc != null) parts.add(book.heShortDesc!);
    if (book.heDesc != null) parts.add(book.heDesc!);
    if (book.link.isNotEmpty) parts.add(book.link);
    if (book.topics.isNotEmpty) parts.add(book.topics);

    var combined = parts.where((p) => p.isNotEmpty).join(' — ');
    combined = stripHtmlIfNeeded(combined);
    combined = removeVolwels(combined);

    index.addDocument(
      id: BigInt.from(DateTime.now().microsecondsSinceEpoch),
      title: title,
      reference: '',
      topics: '$topics/$title',
      text: combined,
      segment: BigInt.from(0),
      isPdf: false,
      filePath: book.link,
    );

    // Don't commit after every book - too slow!
    debugPrint('   ✅ סיים אינדוקס של ספר חיצוני: $title');
  }

  /// Indexes a PDF book by extracting and processing text from each page.
  Future<void> _indexPdfBook(PdfBook book) async {
    final index = await _tantivyDataProvider.engine;

    debugPrint('📚 PDF indexing started: "${book.title}" (${book.path})');

    // Try to load PDF from database first, then fall back to file
    PdfDocument? document;
    try {
      final pdfBytes =
          await SqliteDataProvider.instance.getPdfBytesFromDb(book);
      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        debugPrint('📚 Loading PDF from database for: ${book.title}');
        // Add timeout for PDF opening (30 seconds)
        document = await PdfDocument.openData(pdfBytes)
            .timeout(Duration(seconds: 30), onTimeout: () {
          debugPrint('⏱️ טיימאאוט בפתיחת PDF מ-DB: ${book.title}');
          throw TimeoutException('PDF open timeout');
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load PDF from database: $e');
    }

    // Fallback to file if database load failed
    if (document == null) {
      final file = File(book.path);
      if (await file.exists()) {
        debugPrint('📚 Loading PDF from file: ${book.path}');
        try {
          // Add timeout for PDF opening from file (30 seconds)
          document = await PdfDocument.openFile(book.path)
              .timeout(Duration(seconds: 30), onTimeout: () {
            debugPrint('⏱️ טיימאאוט בפתיחת PDF מקובץ: ${book.title}');
            throw TimeoutException('PDF open timeout');
          });
        } catch (e) {
          debugPrint('❌ שגיאה בפתיחת PDF: ${book.path} - $e');
          return;
        }
      } else {
        debugPrint('❌ PDF not found in database or file system: ${book.path}');
        return;
      }
    }

    final pages = document.pages;
    final outline = await document.loadOutline();
    final title = book.title;
    final topics = "/${book.topics.replaceAll(', ', '/')}";

    debugPrint('📚 PDF מכיל ${pages.length} עמודים, ${outline.length} סימניות');

    // Process each page
    var addedAnyInBook = false;
    for (int i = 0; i < pages.length; i++) {
      if (!_tantivyDataProvider.isIndexing.value) {
        return;
      }

      // Report progress every 10 pages
      if (i % 10 == 0 && i > 0) {
        debugPrint('   📄 מעבד עמוד $i/${pages.length} של $title');
      }

      try {
        // Add timeout for page text loading (10 seconds per page)
        final pageText = await pages[i].loadText().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏱️ טיימאאוט בעמוד ${i + 1} של $title');
            return null;
          },
        );

        if (pageText == null) {
          // Skip this page if timeout occurred
          continue;
        }

        final rawLines = pageText.fullText.split('\n');

        final bookmark = await refFromPageNumber(i + 1, outline, title);
        final ref = bookmark.isNotEmpty
            ? '$title, $bookmark, עמוד ${i + 1}'
            : '$title, עמוד ${i + 1}';

        var addedAny = false;
        for (int j = 0; j < rawLines.length; j++) {
          if (!_tantivyDataProvider.isIndexing.value) {
            return;
          }

          // Yield control periodically to prevent blocking
          if (j % 50 == 0) {
            await Future.delayed(Duration.zero);
          }

          final normalized = _normalizePdfTextForIndexing(rawLines[j]);
          if (_isProbablyGarbagePdfText(normalized)) {
            continue;
          }

          index.addDocument(
            id: BigInt.from(DateTime.now().microsecondsSinceEpoch),
            title: title,
            reference: ref,
            topics: '$topics/$title',
            text: normalized,
            segment: BigInt.from(i),
            isPdf: true,
            filePath: book.path,
          );
          addedAny = true;
          addedAnyInBook = true;
        }

        if (!addedAny && kDebugMode) {
          debugPrint(
            '⚠️ עמוד ${i + 1}: דולג (אין טקסט שמיש)',
          );
        }
      } catch (e) {
        debugPrint('❌ שגיאה בעמוד ${i + 1} של $title: $e');
        // Continue to next page
      }
    }

    // Fallback: some PDFs have no usable text layer, but ship alongside a
    // plain-text OCR dump. If the PDF extraction produced nothing usable,
    // try indexing a sidecar .txt so the book is still searchable.
    if (!addedAnyInBook) {
      final candidates = <String>{
        '${book.path}.txt',
        p.setExtension(book.path, '.txt'),
      };

      File? sidecar;
      for (final candidate in candidates) {
        final f = File(candidate);
        if (await f.exists()) {
          sidecar = f;
          break;
        }
      }

      if (sidecar != null) {
        final ocrText = await sidecar.readAsString();
        final pagesText =
            ocrText.contains('\f') ? ocrText.split('\f') : <String>[ocrText];

        for (int pageIndex = 0; pageIndex < pagesText.length; pageIndex++) {
          if (!_tantivyDataProvider.isIndexing.value) {
            return;
          }

          final bookmark =
              await refFromPageNumber(pageIndex + 1, outline, title);
          final ref = bookmark.isNotEmpty
              ? '$title, $bookmark, עמוד ${pageIndex + 1}'
              : '$title, עמוד ${pageIndex + 1}';

          final lines = pagesText[pageIndex].split('\n');
          for (int j = 0; j < lines.length; j++) {
            if (!_tantivyDataProvider.isIndexing.value) {
              return;
            }
            if (j % 50 == 0) {
              await Future.delayed(Duration.zero);
            }

            final normalized = _normalizePdfTextForIndexing(lines[j]);
            if (_isProbablyGarbagePdfText(normalized)) {
              continue;
            }

            index.addDocument(
              id: BigInt.from(DateTime.now().microsecondsSinceEpoch),
              title: title,
              reference: ref,
              topics: '$topics/$title',
              text: normalized,
              segment: BigInt.from(pageIndex),
              isPdf: true,
              filePath: book.path,
            );
            addedAnyInBook = true;
          }
        }

        if (kDebugMode) {
          debugPrint(
            'ℹ️ Indexed PDF from sidecar text: ${sidecar.path} (pdf: ${book.path})',
          );
        }
      }
    }

    // Don't commit after every book - too slow!
    debugPrint('   ✅ סיים אינדוקס PDF: ${book.title}');
  }

  /// Cancels the ongoing indexing process.
  void cancelIndexing() {
    _tantivyDataProvider.isIndexing.value = false;
  }

  /// Persists the list of indexed books to disk.
  void saveIndexedBooks() {
    _tantivyDataProvider.saveBooksDoneToDisk();
  }

  /// Clears the index and resets the list of indexed books.
  Future<void> clearIndex() async {
    _tantivyDataProvider.clear();
  }

  /// Gets the list of books that have already been indexed.
  List<String> getIndexedBooks() {
    return List<String>.from(_tantivyDataProvider.booksDone);
  }

  /// Checks if indexing is currently in progress.
  bool isIndexing() {
    return _tantivyDataProvider.isIndexing.value;
  }
}
