import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/repository/db_commentator_entry.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/services/commentary_service.dart';

// המבחנים בודקים את ההתנהגות האמיתית של
// [FindRefRepository.getCommentatorsForResult] — לא שכפול מקומי.
// אנחנו מזרקים את ה-DB callbacks דרך ה-constructor (selectCommentatorsBySourceLine /
// selectCommentatorsByBook / getBookEra) ובודקים שהקוד האמיתי בוחר את ה-callback
// הנכון, ממיין לפי דורות, מוסיף ל-cache, מכבד את התנאים של PDF / bookId<=0 /
// isUserBook, ובונה את ה-`targetSegment` מ-`targetLineIndex` או ב-fallback.
//
// במבחנים ללא [getBookEra] אנו מסתמכים על fallback ל-CommentaryService.getBookEra:
// בסביבת טסט SqliteDataProvider אינו מאותחל ולכן הוא מחזיר CommentaryEra.other
// לכל המפרשים — מה שגורר מיון אלפביתי על פי `String.compareTo`.

DbReferenceResult _ref({
  int bookId = 10,
  int sourceLineId = 0,
  int segment = 1,
  bool isPdf = false,
  bool isUserBook = false,
}) =>
    DbReferenceResult(
      title: 'בראשית',
      reference: 'בראשית פרק א',
      segment: segment,
      bookId: bookId,
      sourceLineId: sourceLineId,
      isPdf: isPdf,
      isUserBook: isUserBook,
    );

FindRefRepository _repoWith({
  Future<List<Map<String, dynamic>>> Function(int)? bySourceLine,
  Future<List<Map<String, dynamic>>> Function(int)? byBook,
  Future<CommentaryEra> Function(String)? era,
}) =>
    FindRefRepository(
      selectCommentatorsBySourceLine: bySourceLine,
      selectCommentatorsByBook: byBook,
      getBookEra: era,
    );

List<String> _titles(List<DbCommentatorEntry> entries) =>
    [for (final e in entries) e.title];

void main() {
  group('FindRefRepository.getCommentatorsForResult — קוד היצור', () {
    test('PDF — מחזיר רשימה ריקה בלי שאילתה', () async {
      var calls = 0;
      final repo = _repoWith(byBook: (id) async {
        calls++;
        return const [];
      });

      final result = await repo.getCommentatorsForResult(
        _ref(isPdf: true, bookId: -1),
      );

      expect(result, isEmpty);
      expect(calls, 0);
    });

    test('bookId ≤ 0 — מחזיר רשימה ריקה בלי שאילתה', () async {
      var calls = 0;
      final repo = _repoWith(byBook: (id) async {
        calls++;
        return const [];
      });

      final result = await repo.getCommentatorsForResult(_ref(bookId: -1));

      expect(result, isEmpty);
      expect(calls, 0);
    });

    test('isUserBook — לא מבצע שאילתה (namespace collision)', () async {
      var calls = 0;
      final repo = _repoWith(byBook: (id) async {
        calls++;
        return [
          {'targetBookTitle': 'מפרש מספר אחר'},
        ];
      });

      final result = await repo.getCommentatorsForResult(
        _ref(isUserBook: true, bookId: 5, sourceLineId: 42),
      );

      expect(result, isEmpty);
      expect(calls, 0);
    });

    test('sourceLineId > 0 — מעדיף שאילתת segment ולא נופל ל-book', () async {
      var lineCalls = 0;
      var bookCalls = 0;
      final repo = _repoWith(
        bySourceLine: (lineId) async {
          lineCalls++;
          return [
            {'targetBookTitle': 'רש"י', 'targetLineIndex': 100},
            {'targetBookTitle': 'אבן עזרא', 'targetLineIndex': 200},
          ];
        },
        byBook: (bookId) async {
          bookCalls++;
          return const [];
        },
      );

      final result = await repo.getCommentatorsForResult(
        _ref(sourceLineId: 42),
      );

      // ללא injection של era — fallback מחזיר 'other' לשניהם → מיון אלפביתי.
      // 'אבן עזרא' (א) < 'רש"י' (ר).
      expect(_titles(result), ['אבן עזרא', 'רש"י']);
      expect(lineCalls, 1);
      expect(bookCalls, 0);
    });

    test('segment-level — `targetSegment` נלקח מ-`targetLineIndex`', () async {
      final repo = _repoWith(
        bySourceLine: (lineId) async => [
          {'targetBookTitle': 'רש"י', 'targetLineIndex': 100},
          {'targetBookTitle': 'אבן עזרא', 'targetLineIndex': 250},
        ],
      );

      final result = await repo.getCommentatorsForResult(
        _ref(sourceLineId: 42, segment: 7),
      );

      final segmentByTitle = {for (final e in result) e.title: e.targetSegment};
      expect(segmentByTitle['רש"י'], 100);
      expect(segmentByTitle['אבן עזרא'], 250);
    });

    test('segment-level בלי `targetLineIndex` — targetSegment=null', () async {
      // אם השאילתה אינה מחזירה targetLineIndex (למשל בעקבות שדרוג נתונים
      // ישנים), `targetSegment` יישאר null. על הצרכן ליפול ל-ref.segment
      // בזמן הקליק; ה-repository לא נוגע ב-ref.segment כדי לא להזליג ל-cache.
      final repo = _repoWith(
        bySourceLine: (lineId) async => [
          {'targetBookTitle': 'רש"י'}, // אין targetLineIndex
        ],
      );

      final result = await repo.getCommentatorsForResult(
        _ref(sourceLineId: 42, segment: 17),
      );

      expect(result.single.title, 'רש"י');
      expect(result.single.targetSegment, isNull);
    });

    test('segment חוזר ריק → fallback ל-book-level, targetSegment=null',
        () async {
      var lineCalls = 0;
      var bookCalls = 0;
      final repo = _repoWith(
        bySourceLine: (lineId) async {
          lineCalls++;
          return const [];
        },
        byBook: (bookId) async {
          bookCalls++;
          return [
            {'targetBookTitle': 'רש"י'},
            {'targetBookTitle': 'רמב"ן'},
          ];
        },
      );

      final result = await repo.getCommentatorsForResult(
        _ref(sourceLineId: 42, segment: 7),
      );

      // fallback אלפביתי: 'רמב"ן' (מ U+05DE) < 'רש"י' (ש U+05E9).
      expect(_titles(result), ['רמב"ן', 'רש"י']);
      // ב-book-level אין `targetLineIndex` משמעותי → ה-repository אינו
      // מקבע segment. הצרכן יפתור ל-ref.segment בזמן הקליק.
      expect(result.every((e) => e.targetSegment == null), isTrue);
      expect(lineCalls, 1);
      expect(bookCalls, 1);
    });

    test('sourceLineId = 0 — book-level מיידי, targetSegment=null', () async {
      var lineCalls = 0;
      var bookCalls = 0;
      final repo = _repoWith(
        bySourceLine: (lineId) async {
          lineCalls++;
          return const [];
        },
        byBook: (bookId) async {
          bookCalls++;
          return [
            {'targetBookTitle': 'רש"י'},
          ];
        },
      );

      final result = await repo.getCommentatorsForResult(_ref(segment: 5));

      expect(result.single.title, 'רש"י');
      expect(result.single.targetSegment, isNull);
      expect(lineCalls, 0);
      expect(bookCalls, 1);
    });

    test(
        'book-level — refs עם אותו bookId אך segment שונה משתפים cache בלי '
        'הזלגת segment', () async {
      // רגרסיה: לפני התיקון, ה-repository קיבע `targetSegment = ref.segment`
      // לרשומות book-level. הקאש (מפתח=`bookId:sourceLineId`) היה משותף בין
      // שני refs כאלה — וכך הקליק על תוצאה שנייה היה פותח את ה-segment
      // של התוצאה הראשונה. עכשיו ה-repository מחזיר `null` למסלול book-level
      // והצרכן (הדיאלוג) פותר את ה-fallback מקומית.
      var bookCalls = 0;
      final repo = _repoWith(byBook: (bookId) async {
        bookCalls++;
        return [
          {'targetBookTitle': 'רש"י'},
        ];
      });

      final first = await repo.getCommentatorsForResult(_ref(segment: 5));
      final second = await repo.getCommentatorsForResult(_ref(segment: 17));

      // הקאש משותף — שאילתה אחת בלבד, אבל ה-segment נשאר null לשניהם.
      expect(bookCalls, 1);
      expect(first.single.targetSegment, isNull);
      expect(second.single.targetSegment, isNull);
      // וודאי זהות אובייקטים: אותה רשימה מהקאש.
      expect(identical(first, second), isTrue);
    });

    test('מיון לפי דורות: עם injection של [getBookEra]', () async {
      // ה-DB מחזיר 4 מפרשים בסדר שרירותי. ה-eraResolver ממפה כל אחד לדור
      // אחר. אנו מאמתים שהמיון הוא: chazal → rishonim → acharonim → modern.
      // השמות לא ממוינים אלפביתית — לכן אם המיון נשבר, הסדר ישתנה.
      final repo = _repoWith(
        byBook: (id) async => [
          {'targetBookTitle': 'מחבר מודרני'},
          {'targetBookTitle': 'משנה'},
          {'targetBookTitle': 'רמב"ם'},
          {'targetBookTitle': 'חתם סופר'},
        ],
        era: (title) async {
          switch (title) {
            case 'משנה':
              return CommentaryEra.chazal;
            case 'רמב"ם':
              return CommentaryEra.rishonim;
            case 'חתם סופר':
              return CommentaryEra.acharonim;
            case 'מחבר מודרני':
              return CommentaryEra.modern;
            default:
              return CommentaryEra.other;
          }
        },
      );

      final result = await repo.getCommentatorsForResult(_ref());

      expect(_titles(result), ['משנה', 'רמב"ם', 'חתם סופר', 'מחבר מודרני']);
    });

    test('מיון אלפביתי בתוך אותו דור', () async {
      // כל המפרשים באותו דור (rishonim) → סדר אלפביתי גובר.
      final repo = _repoWith(
        byBook: (id) async => [
          {'targetBookTitle': 'רש"י'},
          {'targetBookTitle': 'אבן עזרא'},
          {'targetBookTitle': 'רמב"ן'},
        ],
        era: (title) async => CommentaryEra.rishonim,
      );

      final result = await repo.getCommentatorsForResult(_ref());

      // אלפביתי עברי: 'אבן עזרא' (א) < 'רמב"ן' (ר+מ) < 'רש"י' (ר+ש).
      expect(_titles(result), ['אבן עזרא', 'רמב"ן', 'רש"י']);
    });

    test('מסיר כפילויות לפי (targetBookTitle, targetBookId) — שומר על הראשון',
        () async {
      // אם אותו (title, bookId) מופיע פעמיים, אנחנו שומרים על ה-row הראשון
      // (כולל ה-targetLineIndex שלו). זה חשוב לסגמנט-level: שני קישורים שונים
      // לאותו מפרש שונים זה מזה רק ב-targetLineIndex, אנחנו רוצים את הראשון.
      final repo = _repoWith(
        bySourceLine: (id) async => [
          {
            'targetBookTitle': 'רש"י',
            'targetBookId': 50,
            'targetLineIndex': 100,
          },
          {
            'targetBookTitle': 'רש"י',
            'targetBookId': 50,
            'targetLineIndex': 999,
          },
          {
            'targetBookTitle': 'אבן עזרא',
            'targetBookId': 60,
            'targetLineIndex': 50,
          },
        ],
      );

      final result = await repo.getCommentatorsForResult(_ref(sourceLineId: 1));

      expect(_titles(result), ['אבן עזרא', 'רש"י']);
      final segmentByTitle = {for (final e in result) e.title: e.targetSegment};
      expect(segmentByTitle['רש"י'], 100); // ראשון, לא 999
      expect(segmentByTitle['אבן עזרא'], 50);
    });

    test(
        'שני מפרשים בעלי אותה כותרת ו-targetBookId שונה — שניהם נשמרים '
        '(P1 רגרסיה)', () async {
      // המקרה שהדיפף נועד לתקן: book table יכול להכיל שני book records נפרדים
      // עם אותה כותרת (למשל "רש"י" על תורה ועל בבלי). dedupe לפי title בלבד
      // היה זורק אחד, וגם resolve לפי id בדיאלוג לא היה משנה — כי הרשומה
      // נעלמת לפני שה-UI רואה אותה. כעת dedupe לפי (title, bookId) שומר את שניהם.
      final repo = _repoWith(
        bySourceLine: (id) async => [
          {
            'targetBookTitle': 'רש"י',
            'targetBookId': 100,
            'targetLineIndex': 10,
          },
          {
            'targetBookTitle': 'רש"י',
            'targetBookId': 200,
            'targetLineIndex': 20,
          },
        ],
      );

      final result = await repo.getCommentatorsForResult(_ref(sourceLineId: 1));

      expect(result, hasLength(2),
          reason: 'שני מפרשים בעלי targetBookId שונה לא יכולים להתאחד');
      // כל אחד שומר את ה-bookId וה-targetSegment שלו (אסור שהם יתערבבו).
      final byBookId = {for (final e in result) e.bookId: e};
      expect(byBookId[100], isNotNull);
      expect(byBookId[100]!.targetSegment, 10);
      expect(byBookId[200], isNotNull);
      expect(byBookId[200]!.targetSegment, 20);
      // שני המופעים נושאים את אותה כותרת — אסור שהדיפף ישנה את התווית.
      expect(result.every((e) => e.title == 'רש"י'), isTrue);
    });

    test(
        'rows ללא targetBookId — נחשבים אותו "ספר" ומתאחדים '
        '(תאימות לאחור)', () async {
      // אם DB ישן לא מחזיר targetBookId, כל ה-rows באותו title חולקים מפתח
      // dedupe (title, null) — והשני מסונן. זה משחזר את ההתנהגות הקודמת ולא
      // יוצר רעש בתפריט כשאין מידע מבדל.
      final repo = _repoWith(
        bySourceLine: (id) async => [
          {'targetBookTitle': 'רש"י', 'targetLineIndex': 11},
          {'targetBookTitle': 'רש"י', 'targetLineIndex': 22},
        ],
      );

      final result = await repo.getCommentatorsForResult(_ref(sourceLineId: 1));

      expect(result, hasLength(1));
      expect(result.single.bookId, isNull);
      expect(result.single.targetSegment, 11);
    });

    test('targetBookTitle ריק/null — מדלג', () async {
      final repo = _repoWith(
          byBook: (id) async => [
                {'targetBookTitle': null},
                {'targetBookTitle': ''},
                {'targetBookTitle': 'רש"י'},
              ]);

      final result = await repo.getCommentatorsForResult(_ref());

      expect(_titles(result), ['רש"י']);
    });

    test('cache — קריאה שנייה לא מבצעת שאילתה נוספת', () async {
      var bookCalls = 0;
      final repo = _repoWith(byBook: (id) async {
        bookCalls++;
        return [
          {'targetBookTitle': 'רש"י'},
        ];
      });

      final first = await repo.getCommentatorsForResult(_ref());
      final second = await repo.getCommentatorsForResult(_ref());

      expect(_titles(first), ['רש"י']);
      expect(_titles(second), ['רש"י']);
      expect(bookCalls, 1);
    });

    test('cache — מפרידים לפי (bookId, sourceLineId)', () async {
      var lineCalls = 0;
      var bookCalls = 0;
      final repo = _repoWith(
        bySourceLine: (lineId) async {
          lineCalls++;
          return [
            {'targetBookTitle': 'רש"י על פסוק', 'targetLineIndex': 7},
          ];
        },
        byBook: (bookId) async {
          bookCalls++;
          return [
            {'targetBookTitle': 'רש"י על הספר'},
          ];
        },
      );

      final withLine =
          await repo.getCommentatorsForResult(_ref(sourceLineId: 42));
      final withoutLine = await repo.getCommentatorsForResult(_ref());

      expect(_titles(withLine), ['רש"י על פסוק']);
      expect(withLine.single.targetSegment, 7);
      expect(_titles(withoutLine), ['רש"י על הספר']);
      expect(lineCalls, 1);
      expect(bookCalls, 1);
    });

    test('ספרים שונים — לא מערבבים cache', () async {
      var bookCalls = 0;
      final repo = _repoWith(byBook: (bookId) async {
        bookCalls++;
        return [
          {'targetBookTitle': 'מפרש לספר $bookId'},
        ];
      });

      final r1 = await repo.getCommentatorsForResult(_ref(bookId: 10));
      final r2 = await repo.getCommentatorsForResult(_ref(bookId: 20));

      expect(_titles(r1), ['מפרש לספר 10']);
      expect(_titles(r2), ['מפרש לספר 20']);
      expect(bookCalls, 2);
    });

    test('בלי injection ובלי DB — מחזיר ריק בלי לזרוק', () async {
      // ה-repository ייפול ל-`SqliteDataProvider.instance.repository` שמחזיר
      // null כאשר ה-DB לא מאותחל (כמו בסביבת טסט). המתודה אמורה להחזיר ריק
      // ולא לזרוק.
      final repo = FindRefRepository();
      final result = await repo.getCommentatorsForResult(_ref());
      expect(result, isEmpty);
    });
  });
}
