import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/declarative/services/declarative_library_book_access.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';

void main() {
  test('זהות חיצונית קנונית אינה חושפת קישור או נתיב', () async {
    final external = ExternalLibraryBook(
      title: 'ספר חיצוני',
      id: 10,
      link: 'https://example.invalid/secret',
      externalLibraryId: 'hb:10',
    );
    final access = _access(library: [], hebrewBooks: [external]);

    final identity = await access.resolveUnique({
      'external': {'provider': 'hebrewbooks', 'id': 10},
    });

    expect(identity, {
      'id': 10,
      'type': 'external',
      'bookId': 'ספר חיצוני',
      'source': 'external',
      'external': {'provider': 'hebrewbooks', 'id': 10},
    });
    expect(identity, isNot(contains('link')));
    expect(identity, isNot(contains('filePath')));
  });

  test('טוען מהקטלוג החיצוני רק לפי הספק והמזהה המבוקשים', () async {
    final loads = <(String, Set<Object>)>[];
    final external = ExternalLibraryBook(
      title: 'ספר חיצוני',
      id: 10,
      link: '',
      externalLibraryId: 'hb:10',
    );
    final access = _access(
      library: [],
      hebrewBooks: [external],
      externalLoads: loads,
    );

    await access.resolveUnique({
      'external': {'provider': 'hebrewbooks', 'id': 10},
    });

    expect(loads, hasLength(1));
    expect(loads.single.$1, 'hebrewbooks');
    expect(loads.single.$2, {10});
  });

  test('פותר כמה זהויות באצווה וטוען כל מקור פעם אחת', () async {
    var libraryLoads = 0;
    final externalLoads = <(String, Set<Object>)>[];
    final access = DeclarativeLibraryBookAccess(
      () async {
        libraryLoads++;
        return [TextBook(id: 1, title: 'א'), TextBook(id: 2, title: 'ב')];
      },
      (provider, ids) async {
        externalLoads.add((provider, ids));
        return [
          ExternalLibraryBook(
            id: 10,
            title: 'חיצוני א',
            link: '',
            externalLibraryId: 'hb:10',
          ),
          ExternalLibraryBook(
            id: 11,
            title: 'חיצוני ב',
            link: '',
            externalLibraryId: 'hb:11',
          ),
        ];
      },
      (_, _, _) {},
    );

    final resolved = await access.resolveUniqueBatch([
      {'id': 1},
      {'bookId': 'ב'},
      {
        'external': {'provider': 'hebrewbooks', 'id': 10},
      },
      {
        'external': {'provider': 'hebrewbooks', 'id': 11},
      },
    ]);

    expect(resolved, hasLength(4));
    expect(resolved.map((identity) => identity?['id']), [1, 2, 10, 11]);
    expect(libraryLoads, 1);
    expect(externalLoads, hasLength(1));
    expect(externalLoads.single.$1, 'hebrewbooks');
    expect(externalLoads.single.$2, {10, 11});
  });

  test('זהות עמומה אינה נפתרת ואינה פותחת ספר', () async {
    final opened = <Book>[];
    final access = _access(
      library: [
        TextBook(id: 1, title: 'כותרת'),
        TextBook(id: 2, title: 'כותרת'),
      ],
      opened: opened,
    );

    expect(await access.resolveUnique({'bookId': 'כותרת'}), isNull);
    expect(
      await access.openUnique(
        {'bookId': 'כותרת'},
        index: 0,
        searchQuery: '',
      ),
      isFalse,
    );
    expect(opened, isEmpty);
  });

  test('נתיב או URL בשדות הזהות נדחים', () async {
    final access = _access(library: [TextBook(id: 1, title: 'ספר')]);

    expect(
      await access.resolveUnique({'id': 1, 'filePath': '/private/book.txt'}),
      isNull,
    );
    expect(
      await access.resolveUnique({'id': 1, 'url': 'https://example.com'}),
      isNull,
    );
  });

  test('id לא חוקי אינו מושמט לטובת התאמה לפי כותרת', () async {
    final access = _access(library: [TextBook(id: 1, title: 'ספר')]);

    expect(
      await access.resolveUnique({'id': 'invalid', 'bookId': 'ספר'}),
      isNull,
    );
  });

  test('ספר יחיד נפתח עם המיקום המבוקש', () async {
    final opened = <Book>[];
    final positions = <(int, String)>[];
    final book = TextBook(id: 7, title: 'ספר');
    final access = _access(
      library: [book],
      opened: opened,
      positions: positions,
    );

    final result = await access.openUnique(
      {'id': 7, 'type': 'text'},
      index: 12,
      searchQuery: 'חיפוש',
    );

    expect(result, isTrue);
    expect(opened, [book]);
    expect(positions, [(12, 'חיפוש')]);
  });

  test('PluginBookIdentity מפענח ספק חיצוני מוכר בלבד', () {
    final hb = ExternalLibraryBook(
      title: 'HB',
      id: 8,
      link: '',
      externalLibraryId: 'hb:8',
    );
    final unknown = ExternalLibraryBook(
      title: 'Unknown',
      id: 9,
      link: '',
      externalLibraryId: 'custom:9',
    );

    expect(
      PluginBookIdentity.externalOf(hb),
      (provider: 'hebrewbooks', id: 8),
    );
    expect(PluginBookIdentity.externalOf(unknown), isNull);
  });
}

DeclarativeLibraryBookAccess _access({
  required List<Book> library,
  List<Book> hebrewBooks = const [],
  List<Book>? opened,
  List<(int, String)>? positions,
  List<(String, Set<Object>)>? externalLoads,
}) {
  return DeclarativeLibraryBookAccess(
    () async => library,
    (provider, externalIds) async {
      externalLoads?.add((provider, externalIds));
      return provider == 'hebrewbooks' ? hebrewBooks : const [];
    },
    (book, index, searchQuery) {
      opened?.add(book);
      positions?.add((index, searchQuery));
    },
  );
}
