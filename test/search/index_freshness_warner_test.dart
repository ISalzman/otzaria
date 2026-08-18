import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/utils/index_freshness_warner.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';

/// האזהרה הלא-חוסמת על דריפט תוכן (issue #828): התוצאה נפתחת תמיד,
/// והאזהרה מוצגת פעם אחת לספר רק על אי-התאמה ודאית.
void main() {
  final warner = IndexFreshnessWarner.instance;

  setUp(warner.resetForTesting);
  tearDown(warner.resetForTesting);

  test('ספר עם דריפט מזהיר פעם אחת בלבד', () async {
    final book = TextBook(id: 1, title: 'ספר');
    var verifierCalls = 0;
    final notifications = <String>[];
    warner.debugVerifier = (_) async {
      verifierCalls++;
      return false;
    };
    warner.debugNotifier = notifications.add;

    await warner.warnIfContentDrifted(book);
    await warner.warnIfContentDrifted(book);

    expect(verifierCalls, 1);
    expect(notifications, [LibraryMessages.searchResultContentDrifted]);
  });

  test('ספר טרי אינו מזהיר', () async {
    final notifications = <String>[];
    warner.debugVerifier = (_) async => true;
    warner.debugNotifier = notifications.add;

    await warner.warnIfContentDrifted(TextBook(id: 2, title: 'טרי'));

    expect(notifications, isEmpty);
  });

  test('כשל אימות אינו מזהיר ואינו נצרב — ניסיון חוזר בפתיחה הבאה', () async {
    final book = TextBook(id: 3, title: 'כושל');
    var verifierCalls = 0;
    final notifications = <String>[];
    warner.debugVerifier = (_) async {
      verifierCalls++;
      if (verifierCalls == 1) throw StateError('engine down');
      return false;
    };
    warner.debugNotifier = notifications.add;

    await warner.warnIfContentDrifted(book);
    expect(notifications, isEmpty);

    await warner.warnIfContentDrifted(book);
    expect(verifierCalls, 2);
    expect(notifications, [LibraryMessages.searchResultContentDrifted]);
  });

  test('ספרים שונים נבדקים בנפרד', () async {
    final checkedKeys = <String>[];
    warner.debugVerifier = (book) async {
      checkedKeys.add(IndexingRepository.buildIndexedBookFilePath(book));
      return true;
    };

    await warner.warnIfContentDrifted(TextBook(id: 4, title: 'א'));
    await warner.warnIfContentDrifted(TextBook(id: 5, title: 'ב'));

    expect(checkedKeys, hasLength(2));
    expect(checkedKeys.toSet(), hasLength(2));
  });

  test('אין חתימת טקסט באינדקס = לא ניתן לאימות = אין אזהרה', () async {
    // המסלול המוקדם ב-textBookContentMatchesIndex — לפני כל קריאת FFI,
    // ולכן הספק המזויף לעולם אינו נוגע.
    final repository = IndexingRepository(_FakeTantivyDataProvider());
    final fresh = await repository.textBookContentMatchesIndex(
      TextBook(id: 6, title: 'בלי חתימה'),
      const {},
    );
    expect(fresh, isTrue);
  });
}

class _FakeTantivyDataProvider implements TantivyDataProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
