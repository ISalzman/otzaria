import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/services/commentary_service.dart';

// המבחנים בודקים את ההתנהגות האמיתית של
// [FindRefRepository.getCommentatorsForResult] — לא שכפול מקומי.
// אנחנו מזרקים את ה-DB callbacks דרך ה-constructor (selectCommentatorsBySourceLine /
// selectCommentatorsByBook / getBookEra) ובודקים שהקוד האמיתי בוחר את ה-callback
// הנכון, ממיין לפי דורות, מוסיף ל-cache, ומכבד את התנאים של PDF / bookId<=0 /
// isUserBook.
//
// במבחנים ללא [getBookEra] אנו מסתמכים על fallback ל-CommentaryService.getBookEra:
// בסביבת טסט SqliteDataProvider אינו מאותחל ולכן הוא מחזיר CommentaryEra.other
// לכל המפרשים — מה שגורר מיון אלפביתי על פי `String.compareTo`.

DbReferenceResult _ref({
  int bookId = 10,
  int sourceLineId = 0,
  bool isPdf = false,
  bool isUserBook = false,
}) =>
    DbReferenceResult(
      title: 'בראשית',
      reference: 'בראשית פרק א',
      segment: 1,
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
            {'targetBookTitle': 'רש"י'},
            {'targetBookTitle': 'אבן עזרא'},
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
      expect(result, ['אבן עזרא', 'רש"י']);
      expect(lineCalls, 1);
      expect(bookCalls, 0);
    });

    test('segment חוזר ריק → fallback ל-book-level', () async {
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
        _ref(sourceLineId: 42),
      );

      // fallback אלפביתי: 'רמב"ן' (מ U+05DE) < 'רש"י' (ש U+05E9).
      expect(result, ['רמב"ן', 'רש"י']);
      expect(lineCalls, 1);
      expect(bookCalls, 1);
    });

    test('sourceLineId = 0 — שאילתה מיידית ב-book-level', () async {
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

      final result = await repo.getCommentatorsForResult(_ref());

      expect(result, ['רש"י']);
      expect(lineCalls, 0);
      expect(bookCalls, 1);
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

      expect(result, ['משנה', 'רמב"ם', 'חתם סופר', 'מחבר מודרני']);
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
      expect(result, ['אבן עזרא', 'רמב"ן', 'רש"י']);
    });

    test('מסיר כפילויות לפי targetBookTitle', () async {
      final repo = _repoWith(
          byBook: (id) async => [
                {'targetBookTitle': 'רש"י'},
                {'targetBookTitle': 'רש"י'},
                {'targetBookTitle': 'אבן עזרא'},
              ]);

      final result = await repo.getCommentatorsForResult(_ref());

      expect(result, ['אבן עזרא', 'רש"י']);
    });

    test('targetBookTitle ריק/null — מדלג', () async {
      final repo = _repoWith(
          byBook: (id) async => [
                {'targetBookTitle': null},
                {'targetBookTitle': ''},
                {'targetBookTitle': 'רש"י'},
              ]);

      final result = await repo.getCommentatorsForResult(_ref());

      expect(result, ['רש"י']);
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

      expect(first, ['רש"י']);
      expect(second, ['רש"י']);
      expect(bookCalls, 1);
    });

    test('cache — מפרידים לפי (bookId, sourceLineId)', () async {
      var lineCalls = 0;
      var bookCalls = 0;
      final repo = _repoWith(
        bySourceLine: (lineId) async {
          lineCalls++;
          return [
            {'targetBookTitle': 'רש"י על פסוק'},
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

      expect(withLine, ['רש"י על פסוק']);
      expect(withoutLine, ['רש"י על הספר']);
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

      expect(r1, ['מפרש לספר 10']);
      expect(r2, ['מפרש לספר 20']);
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
