import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';

void main() {
  group('IndexingRepository.shouldSkipManualReindexCheck', () {
    test('מחזיר true עבור ספרייה ריקה - מונע דיאלוג איפוס בלי ספרים', () {
      expect(
        IndexingRepository.shouldSkipManualReindexCheck(
          Library(categories: []),
        ),
        isTrue,
      );
    });

    test('מחזיר true עבור ספרייה עם קטגוריות ריקות', () {
      final library = Library(categories: []);
      library.subCategories.add(
        Category(
          title: 'תנ"ך',
          description: '',
          shortDescription: '',
          order: 1,
          subCategories: [],
          books: [],
          parent: library,
        ),
      );
      expect(
        IndexingRepository.shouldSkipManualReindexCheck(library),
        isTrue,
      );
    });

    test('מחזיר false עבור ספרייה עם ספר אחד', () {
      final library = _buildLibrary(bavliBooks: const [('שבת', 1)]);
      expect(
        IndexingRepository.shouldSkipManualReindexCheck(library),
        isFalse,
      );
    });
  });

  group('IndexingRepository.shouldResetBeforeFullReindex', () {
    test('מחזיר true כשמתחילים בנייה מחדש מעל אינדקס קיים', () {
      final shouldReset = IndexingRepository.shouldResetBeforeFullReindex(
        indexExistedBeforeInit: true,
        booksDone: const [],
      );

      expect(shouldReset, isTrue);
    });

    test('מחזיר false ביצירה ראשונית של אינדקס חדש', () {
      final shouldReset = IndexingRepository.shouldResetBeforeFullReindex(
        indexExistedBeforeInit: false,
        booksDone: const [],
      );

      expect(shouldReset, isFalse);
    });

    test('מחזיר false כשמדובר בעדכון אינקרמנטלי', () {
      final shouldReset = IndexingRepository.shouldResetBeforeFullReindex(
        indexExistedBeforeInit: true,
        booksDone: const ['ספר אחד'],
      );

      expect(shouldReset, isFalse);
    });
  });

  group('IndexingRepository.buildCatalogueDocumentId', () {
    test('נותן עדיפות לסדר הספר לפני הסדר הפנימי בתוך הספר', () {
      final earlierBookLateSegment =
          IndexingRepository.buildCatalogueDocumentId(
        catalogueOrder: 0,
        ordinal: 500,
      );
      final laterBookFirstSegment = IndexingRepository.buildCatalogueDocumentId(
        catalogueOrder: 1,
        ordinal: 0,
      );

      expect(earlierBookLateSegment, lessThan(laterBookFirstSegment));
    });
  });

  group('IndexingRepository.catalogueOrderKey', () {
    test('מבדיל בין קבצי PDF עם אותו שם לפי הנתיב בפועל', () {
      final first = PdfBook(
        title: 'שבת',
        path: r'C:\books\a.pdf',
        categoryPath: 'תלמוד בבלי, סדר מועד',
      );
      final second = PdfBook(
        title: 'שבת',
        path: r'C:\books\b.pdf',
        categoryPath: 'תלמוד בבלי, סדר מועד',
      );

      expect(
        IndexingRepository.catalogueOrderKey(first),
        isNot(IndexingRepository.catalogueOrderKey(second)),
      );
    });
  });

  group('IndexingRepository.buildCatalogueOrderSignature', () {
    test('משתנה כשסדר הקטלוג משתנה', () {
      final firstLibrary = _buildLibrary(
        bavliBooks: const [
          ('שבת', 1),
          ('חגיגה', 2),
        ],
      );
      final secondLibrary = _buildLibrary(
        bavliBooks: const [
          ('שבת', 2),
          ('חגיגה', 1),
        ],
      );

      expect(
        IndexingRepository.buildCatalogueOrderSignature(firstLibrary),
        isNot(
          IndexingRepository.buildCatalogueOrderSignature(secondLibrary),
        ),
      );
    });
  });

  group('IndexingRepository.isIndexableBook', () {
    test('DocxBook נכלל באינדוקס דרך מיפוי ל-TextBook', () {
      // רגרסיה: לפני התיקון `isIndexableBook` החזיר false ל-DocxBook,
      // אז `IndexingBloc` סינן אותו לפני indexAllBooks וקבצי DOCX לא נכנסו
      // לאינדקס הטנטיווי. עכשיו הוא ממופה ל-TextBook באמצעות `toTextBook()`
      // ו-`book.text` מחלץ את התוכן דרך docxToText ב-DatabaseLibraryProvider.
      final docx = DocxBook(
        id: 1,
        title: 'בדיקה',
        path: r'C:\library\בדיקה.docx',
        categoryId: 10,
      );
      expect(IndexingRepository.isIndexableBook(docx), isTrue);
    });

    test('TextBook ו-PdfBook נשארים אינדוקסיביליים', () {
      expect(
        IndexingRepository.isIndexableBook(TextBook(title: 'א')),
        isTrue,
      );
      expect(
        IndexingRepository.isIndexableBook(
          PdfBook(title: 'א', path: r'C:\a.pdf'),
        ),
        isTrue,
      );
    });

    test('ExternalLibraryBook לא אינדוקסיבילי', () {
      final external = ExternalLibraryBook(
        title: 'אוצר',
        id: 999,
        link: 'https://example.com',
      );
      expect(IndexingRepository.isIndexableBook(external), isFalse);
    });
  });

  group('DocxBook ↔ TextBook(wrap) — עקביות מפתח קטלוג', () {
    test('catalogueOrderKey זהה ל-DocxBook ול-TextBook העטוף עם id', () {
      // קריטי: שני המפתחות חייבים להיות זהים כדי שהבדיקה
      // `booksDone.contains(indexedBookKey)` תזהה אותו ספר בלי לכפול
      // את האינדוקס בהפעלות חוזרות.
      final docx = DocxBook(
        id: 42,
        title: 'בדיקה',
        path: r'C:\library\בדיקה.docx',
        categoryId: 7,
      );
      expect(
        IndexingRepository.catalogueOrderKey(docx),
        IndexingRepository.catalogueOrderKey(docx.toTextBook()),
      );
    });

    test('catalogueOrderKey זהה גם ללא id (נופל ל-title|category|docx|path)',
        () {
      // FileBook משתמש ב-`book.path` ב-pathKey, ו-TextBook (לא FileBook)
      // משתמש ב-`book.filePath`. `toTextBook()` מעביר `filePath ?? path`,
      // כך שהמפתח נשאר עקבי גם בלי id.
      final docx = DocxBook(
        title: 'בדיקה ללא id',
        path: r'C:\library\בדיקה.docx',
        categoryPath: 'ספרים אישיים',
      );
      expect(
        IndexingRepository.catalogueOrderKey(docx),
        IndexingRepository.catalogueOrderKey(docx.toTextBook()),
      );
    });
  });

  group('IndexingRepository.optimizeIndexBestEffort', () {
    test('מחזיר true כש-optimize מצליח', () async {
      var called = false;

      final completed =
          await IndexingRepository.optimizeIndexBestEffort(() async {
        called = true;
      });

      expect(called, isTrue);
      expect(completed, isTrue);
    });

    test('מחזיר false ולא זורק כש-optimize נכשל אחרי commit', () async {
      Object? reportedError;

      final completed =
          await IndexingRepository.optimizeIndexBestEffort(() async {
        throw StateError('maintenance failed');
      }, onFailure: (error, _) {
        reportedError = error;
      });

      expect(completed, isFalse);
      expect(reportedError, isA<StateError>());
    });
  });
}

Library _buildLibrary({
  required List<(String, int)> bavliBooks,
}) {
  final library = Library(categories: []);
  final tanakh = Category(
    title: 'תנ"ך',
    description: '',
    shortDescription: '',
    order: 1,
    subCategories: [],
    books: [],
    parent: library,
  );
  final bavli = Category(
    title: 'תלמוד בבלי',
    description: '',
    shortDescription: '',
    order: 2,
    subCategories: [],
    books: [],
    parent: library,
  );
  library.subCategories.addAll([tanakh, bavli]);

  tanakh.books.add(
    TextBook(title: 'בראשית', order: 1, category: tanakh),
  );

  bavli.books.addAll(
    bavliBooks
        .map(
          (entry) => TextBook(
            title: entry.$1,
            order: entry.$2,
            category: bavli,
          ),
        )
        .toList(),
  );

  return library;
}
