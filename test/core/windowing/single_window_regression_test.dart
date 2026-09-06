import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/repository/bookmark_repository.dart';
import 'package:otzaria/core/windowing/shared_hive_store.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/core/windowing/window_role.dart';
import 'package:otzaria/history/history_repository.dart';
import 'package:otzaria/models/books.dart';

/// ⚠️ קידומת ייחודית לסוויטה — [ui.IsolateNameServer] גלובלי לתהליך.
const String _namespace = 'otzaria.test.singlewindow';

/// **הבדיקה שמגנה על 99% מהמשתמשים.**
///
/// כל שכבת המצב המשותף נוספה עבור ריבוי חלונות, אבל היא יושבת על מסלול
/// הכתיבה של **כל** משתמש — כולל מי שלעולם לא יפתח חלון שני. שתי דרישות:
///
/// 1. **אפס המתנה.** אין קריאת בקשה-תשובה על האפיק, כלומר אין מסלול שבו
///    שמירת סימנייה ממתינה ל-timeout.
/// 2. **אפס שינוי התנהגות.** הוספה, הסרה ומחיקה עובדות בדיוק כמו קודם,
///    מול Hive אמיתי.
///
/// ⚠️ **המצב המדויק חשוב כאן.** גרסה ראשונה של הבדיקה תפסה את כל המשבצות
/// כדי "להאזין לתעבורה" — ובכך גרמה לחלון לחשוב שיש שכנים, וקיבלה שש
/// הודעות שידור. בחלון יחיד אמיתי המשבצות **ריקות**, ולכן `broadcast`
/// אינו מוצא למי לשלוח. שתי התצורות נבדקות בנפרד: `[יחיד]` בלי משבצות
/// תפוסות, ו-`[עם שכן]` שמאמת שהתעבורה היחידה היא שידור ולא בקשה חוסמת.
void main() {
  Bookmark bookmark(String title, {int index = 0}) => Bookmark(
    ref: title,
    book: TextBook(title: title),
    index: index,
  );

  setUp(() async {
    WindowBus.namespace = _namespace;
    WindowRole.isSecondary = false;
    SharedHiveStore.instance.resetForTest();
    Hive.init('${Directory.systemTemp.path}/otzaria_single_window_test');
    await Hive.openBox<dynamic>('history');
    await Hive.openBox<dynamic>('bookmarks');
    await Hive.openBox<dynamic>('workspaces');
    WindowBus.instance.register(asOwner: true);
  });

  tearDown(() async {
    WindowBus.instance.unregister();
    for (var i = 1; i <= WindowBus.slotCount; i++) {
      ui.IsolateNameServer.removePortNameMapping('$_namespace.$i');
    }
    ui.IsolateNameServer.removePortNameMapping('$_namespace.owner');
    WindowBus.namespace = 'otzaria.window';
    await Hive.deleteFromDisk();
  });

  test('[יחיד] היסטוריה: הוספה, קריאה והסרה, בלי אף הודעת אפיק', () async {
    final repo = HistoryRepository();
    final started = DateTime.now();

    await repo.mutateHistory((current) => [bookmark('בראשית'), ...current]);
    await repo.mutateHistory((current) => [bookmark('שמות'), ...current]);

    expect((await repo.loadHistory()).map((b) => b.book.title), [
      'שמות',
      'בראשית',
    ]);

    await repo.mutateHistory(
      (current) => current.where((b) => b.book.title != 'שמות').toList(),
    );
    expect((await repo.loadHistory()).map((b) => b.book.title), ['בראשית']);

    // ⚠️ המספר הוא הראיה שלא הומתן לשום timeout. ה-timeout לבקשת בעלים
    // הוא 8 שניות, ושל `peers` 800ms — אף אחד מהם אינו על המסלול הזה.
    final elapsed = DateTime.now().difference(started);
    expect(elapsed.inMilliseconds, lessThan(500));
  });

  test('[יחיד] סימניות: הוספה ומחיקה נשמרות ל-Hive האמיתי', () async {
    final repo = BookmarkRepository();

    await repo.mutateBookmarks((current) => [...current, bookmark('ויקרא')]);
    await repo.mutateBookmarks(
      (current) => [...current, bookmark('במדבר', index: 4)],
    );

    // נקרא מה-box עצמו, כלומר מה שבאמת נכתב.
    final stored =
        Hive.box<dynamic>('bookmarks').get('key-bookmarks') as List<dynamic>;
    expect(stored, hasLength(2));

    await repo.clearBookmarks();
    expect(await repo.loadBookmarks(), isEmpty);
  });

  test('[יחיד] קריאה היא תמיד מוסמכת', () async {
    // ⚠️ בחלון יחיד אין "לא הצלחנו לשאול" — הוא **הוא** הבעלים. אם הדגל
    // יהיה false כאן, `mutate` יזרוק ושמירת סימנייה תיכשל לכל משתמש.
    final snapshot = await SharedHiveStore.instance.read('history', 'history');
    expect(snapshot.authoritative, isTrue);
  });

  test('[עם שכן] הבעלים משדר, ואינו שולח בקשה חוסמת לאף אחד', () async {
    final listener = _BusEavesdropper()..register();
    addTearDown(listener.dispose);

    await HistoryRepository().mutateHistory(
      (current) => [bookmark('דברים'), ...current],
    );
    // השידור הוא fire-and-forget, ולכן נמתין שיגיע — זו כל הנקודה בכך
    // שהוא אינו מעכב את הכתיבה.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // ⚠️ זו ההבחנה. `sharedHiveRead`/`sharedHiveWrite` הן בקשות
    // **בקשה-תשובה** עם timeout — הן מסלול חלון משני, ואסור שיופיעו אצל
    // הבעלים. שידור "השתנה" הוא fire-and-forget ואינו מעכב כלום.
    expect(listener.blockingRequests, 0);
    expect(listener.changeNotices, greaterThan(0));
  });

  test('רשומה פגומה מדולגת בתצוגה ואינה נמחקת בכתיבה', () async {
    // ⚠️ מחיקת נתונים בגלל באג פענוח היא בדיוק מה שאסור. הרשומה אינה
    // מוצגת, אבל היא נשארת על הדיסק לניסיון הבא או לתיקון.
    await Hive.box<dynamic>('history').put('history', [
      {'this': 'is not a bookmark'},
      bookmark('דברים').toJson(),
    ]);
    final repo = HistoryRepository();

    expect((await repo.loadHistory()).map((b) => b.book.title), ['דברים']);

    await repo.mutateHistory((current) => [bookmark('יהושע'), ...current]);

    final stored = Hive.box<dynamic>('history').get('history') as List<dynamic>;
    expect(stored, hasLength(3));
    expect(
      stored.any((e) => e is Map && e['this'] == 'is not a bookmark'),
      isTrue,
    );
  });

  test('כשל כתיבה מתפשט ואינו נבלע', () async {
    // ⚠️ שלוש שכבות תלויות בכשל הזה: ההודעה למשתמש, הניסיון החוזר
    // ב-PreCloseRegistry, ודיווח ל-Sentry. `tabs` אינו נפתח ב-setUp
    // בכוונה, ולכן `Hive.box` עליו זורק.
    await expectLater(
      SharedHiveStore.instance.write('tabs', 'key-tabs', const []),
      throwsA(anything),
    );
  });
}

/// חלון שכן מדומה, שמפריד בין בקשה חוסמת לשידור.
///
/// ⚠️ עצם קיומו משנה את מה שנמדד: כל עוד משבצת תפוסה, `broadcast` מוצא
/// למי לשלוח. לכן הוא נרשם רק בבדיקה שבודקת **סוג** תעבורה, ולא באלה
/// שבודקות שאין תעבורה בכלל.
class _BusEavesdropper {
  final List<ReceivePort> _ports = [];

  /// `sharedHiveRead` / `sharedHiveWrite` — מסלול חלון משני, עם timeout.
  int blockingRequests = 0;

  /// `sharedHiveChanged` — fire-and-forget, אינו מעכב כלום.
  int changeNotices = 0;

  void register() {
    // משבצת 1 שייכת לחלון הנבדק; 2..N נתפסות כאן.
    for (var slot = 2; slot <= WindowBus.slotCount; slot++) {
      final port = ReceivePort();
      ui.IsolateNameServer.registerPortWithName(
        port.sendPort,
        '$_namespace.$slot',
      );
      port.listen((message) {
        if (message is! Map) return;
        final body = message['body'];
        if (body is Map) {
          switch (body['type']) {
            case SharedHiveStore.requestRead:
            case SharedHiveStore.requestWrite:
              blockingRequests++;
            case SharedHiveStore.requestChanged:
              changeNotices++;
          }
        }
        if (message['reply'] is SendPort) {
          (message['reply'] as SendPort).send({'ok': true, 'result': null});
        }
      });
      _ports.add(port);
    }
  }

  void dispose() {
    for (final port in _ports) {
      port.close();
    }
    _ports.clear();
  }
}
