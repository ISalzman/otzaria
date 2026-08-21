import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/utils/index_freshness_warner.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

import '../support/search_engine_test_init.dart';

/// האזהרה הלא-חוסמת על דריפט תוכן (issue #828): התוצאה נפתחת תמיד,
/// האזהרה מוצגת רק על אי-התאמה ודאית, מפת החתימות נטענת פעם אחת לדור
/// אינדקס, וכל המטמונים מתאפסים כשהאינדקס נבנה או נפתח מחדש.
Future<void> main() async {
  final engineReady = await tryInitSearchEngine();

  final warner = IndexFreshnessWarner.instance;
  late _FakeTantivyDataProvider provider;

  setUp(() {
    warner.resetForTesting();
    provider = _FakeTantivyDataProvider(_FakeSearchEngine());
    warner.providerResolver = () => provider;
  });
  tearDown(warner.resetForTesting);

  test('מפת החתימות נטענת מהמנוע פעם אחת עבור כמה ספרים', () async {
    // getBookTextFingerprints סורק את כל האינדקס — קריאה פר-ספר היא
    // נסיגת ביצועים (ביקורת P1 על ה-PR).
    for (var id = 1; id <= 3; id++) {
      await warner.warnIfContentDrifted(TextBook(id: id, title: 'ספר $id'));
    }

    expect(provider.fakeEngine.fingerprintFetches, 1);
  });

  test('ספר עם דריפט מזהיר פעם אחת בלבד', () async {
    final book = TextBook(id: 1, title: 'ספר');
    var verifierCalls = 0;
    final notifications = <String>[];
    warner.debugBookVerifier = (_, _) async {
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
    warner.debugBookVerifier = (_, _) async => true;
    warner.debugNotifier = notifications.add;

    await warner.warnIfContentDrifted(TextBook(id: 2, title: 'טרי'));

    expect(notifications, isEmpty);
  });

  test('ספר שאינו באינדקס — לא ניתן לאימות, אין אזהרה (מסלול אמיתי)', () async {
    final notifications = <String>[];
    warner.debugNotifier = notifications.add;

    // בלי debugBookVerifier: textBookContentMatchesIndex האמיתי רץ, ומחזיר
    // true מוקדם כי המפה מהמנוע המזויף ריקה.
    await warner.warnIfContentDrifted(TextBook(id: 3, title: 'לא באינדקס'));

    expect(notifications, isEmpty);
  });

  test('סוף ריצת אינדוקס מאפס את המטמונים — הספר נבדק מחדש', () async {
    // ביקורת P1: מטמון לכל חיי התהליך מחמיץ דריפט אחרי בנייה מחדש, וגם
    // ספר שלא היה ניתן לאימות חייב להיבדק שוב אחרי בנייה.
    final book = TextBook(id: 1, title: 'ספר');
    var verifierCalls = 0;
    warner.debugBookVerifier = (_, _) async {
      verifierCalls++;
      return true;
    };

    await warner.warnIfContentDrifted(book);
    provider.isIndexing.value = true;
    provider.isIndexing.value = false;
    await warner.warnIfContentDrifted(book);

    expect(verifierCalls, 2);
    expect(provider.fakeEngine.fingerprintFetches, 2);
  });

  test('reopen (החלפת ה-Future של המנוע) מאפס את המטמונים', () async {
    final book = TextBook(id: 1, title: 'ספר');
    var verifierCalls = 0;
    warner.debugBookVerifier = (_, _) async {
      verifierCalls++;
      return true;
    };

    await warner.warnIfContentDrifted(book);
    provider.replaceEngine(_FakeSearchEngine());
    await warner.warnIfContentDrifted(book);

    expect(verifierCalls, 2);
    expect(provider.fakeEngine.fingerprintFetches, 1);
  });

  test('כשל בטעינת המפה אינו נצרב — לא לספר ולא למפה', () async {
    final book = TextBook(id: 1, title: 'ספר');
    provider.fakeEngine.failuresBeforeSuccess = 1;
    final notifications = <String>[];
    warner.debugBookVerifier = (_, _) async => false;
    warner.debugNotifier = notifications.add;

    await warner.warnIfContentDrifted(book);
    expect(notifications, isEmpty);

    await warner.warnIfContentDrifted(book);
    expect(provider.fakeEngine.fingerprintFetches, 2);
    expect(notifications, [LibraryMessages.searchResultContentDrifted]);
  });

  group('אינטגרציה מול המנוע האמיתי', () {
    late Directory indexDir;
    late SearchEngine engine;
    const bookText = '<h1>ספר</h1>\nשורה ראשונה של תוכן\nשורה שנייה';

    setUp(() {
      if (!engineReady) return;
      indexDir = Directory.systemTemp.createTempSync('freshness_warner');
      engine = SearchEngine(path: indexDir.path);
    });

    tearDown(() {
      if (!engineReady) return;
      try {
        indexDir.deleteSync(recursive: true);
      } on FileSystemException {
        // ב-Windows המנוע עדיין מחזיק קבצים פתוחים; אין להפיל את הריצה.
      }
    });

    Future<void> indexBook(String text) async {
      await engine.addTextBook(
        title: 'ספר',
        topics: '/root/ספר',
        filePath: 'id:1',
        catalogueOrder: 5,
        generationOrder: 5,
        text: text,
      );
      await engine.commit();
    }

    test('אינדוקס → getBookTextFingerprints → שינוי תוכן מזוהה', () async {
      await indexBook(bookText);

      final fingerprints = await engine.getBookTextFingerprints();
      expect(
        fingerprints['id:1'],
        computeContentFingerprint(text: bookText),
        reason: 'החתימה באינדקס זהה לחישוב על תוכן הספר',
      );

      const editedText = '$bookText\nשורה שנוספה בעריכה';
      expect(
        fingerprints['id:1'],
        isNot(computeContentFingerprint(text: editedText)),
        reason: 'תוכן שהשתנה אינו תואם את החתימה הישנה',
      );

      // אינדוקס מחדש של התוכן הערוך — החתימה החדשה תואמת אותו.
      await engine.deleteDocumentsByFilePath(filePath: 'id:1');
      await indexBook(editedText);
      final refreshed = await engine.getBookTextFingerprints();
      expect(refreshed['id:1'], computeContentFingerprint(text: editedText));
    }, skip: !engineReady);

    test('textBookContentMatchesIndex מכריע מול חתימות אמיתיות', () async {
      await indexBook(bookText);
      final fingerprints = await engine.getBookTextFingerprints();
      final repository = IndexingRepository(
        _FakeTantivyDataProvider(
          _FakeSearchEngine(),
        ),
      );

      // הספר אינו נטען מ-DB בבדיקה — ההשוואה מוזנת ישירות במפה: ספר שאין
      // לו חתימה מוכרע "לא ניתן לאימות" (true), בלי לגעת במנוע.
      final unverifiable = await repository.textBookContentMatchesIndex(
        TextBook(id: 999, title: 'ספר אחר'),
        fingerprints,
      );
      expect(unverifiable, isTrue);
    }, skip: !engineReady);
  });
}

class _FakeSearchEngine implements SearchEngine {
  final Map<String, BigInt> textFingerprints = {};
  int fingerprintFetches = 0;
  int failuresBeforeSuccess = 0;

  @override
  Future<Map<String, BigInt>> getBookTextFingerprints() async {
    fingerprintFetches++;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('engine down');
    }
    return Map.of(textFingerprints);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTantivyDataProvider implements TantivyDataProvider {
  _FakeTantivyDataProvider(this.fakeEngine) {
    engine = Future.value(fakeEngine);
  }

  _FakeSearchEngine fakeEngine;

  @override
  late Future<SearchEngine> engine;

  @override
  ValueNotifier<bool> isIndexing = ValueNotifier(false);

  /// מדמה reopen: המנוע (וזהות ה-Future) מוחלפים, כמו ב-_doReopen האמיתי.
  void replaceEngine(_FakeSearchEngine next) {
    fakeEngine = next;
    engine = Future.value(next);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
