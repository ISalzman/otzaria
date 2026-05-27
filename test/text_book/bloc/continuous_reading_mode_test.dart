import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// טסטים ללוגיקה הטהורה של החלטות מצב-רצף ב-bloc. השאר (תופעת לוואי של
/// `emit` ושל `buildReadingSegments`) נבדק עקיף דרך טסטי integration אחרים
/// (`reading_segments_test.dart` מבחין שהפונקציה מחזירה ערכים נכונים,
/// בעוד `text_book_bloc_test.dart` הקיים מאמת זרימת state מלאה).
void main() {
  group('computeEffectiveContinuousReading', () {
    test('ביקוש לאפשר על ספר שתומך → מחזיר true', () {
      expect(
        TextBookBloc.computeEffectiveContinuousReading(
          requestedEnabled: true,
          stateSupportsContinuous: true,
        ),
        isTrue,
      );
    });

    test('ביקוש לאפשר על ספר שלא תומך → מחזיר false', () {
      // קריטי: מגן מקיצורי מקלדת/plugins שעלולים לדרוש true גם בספר
      // שאין לו תמיכה (מפרשים וכו'). ה-UI ממילא לא חושף את הכפתור שם,
      // אבל הbloc חייב להגן מקריאות תוכנתיות.
      expect(
        TextBookBloc.computeEffectiveContinuousReading(
          requestedEnabled: true,
          stateSupportsContinuous: false,
        ),
        isFalse,
      );
    });

    test('ביקוש לכבות → false ללא תלות בתמיכה', () {
      expect(
        TextBookBloc.computeEffectiveContinuousReading(
          requestedEnabled: false,
          stateSupportsContinuous: true,
        ),
        isFalse,
      );
      expect(
        TextBookBloc.computeEffectiveContinuousReading(
          requestedEnabled: false,
          stateSupportsContinuous: false,
        ),
        isFalse,
      );
    });
  });

  group('resolvePreservedContinuousReadingMode', () {
    final loadedTrue = _loaded(continuous: true, supports: true);
    final loadedFalse = _loaded(continuous: false, supports: true);

    test('ספר לא תומך → false (גם אם preserve+state מבקשים true)', () {
      expect(
        TextBookBloc.resolvePreservedContinuousReadingMode(
          supportsContinuous: false,
          preserveFlag: true,
          currentState: loadedTrue,
        ),
        isFalse,
      );
    });

    test('preserveFlag=false → false (זה המסלול של _resetPerBookSettings)', () {
      // הבאג שתוקן: לפני התיקון, _resetPerBookSettings לא איפס את מצב
      // הרצף כי ה-bloc תמיד שמר אותו. עכשיו ברירת המחדל היא לאפס,
      // והשמירה אקטיבית רק כש-listener של הגדרות גלובליות מבקש זאת.
      expect(
        TextBookBloc.resolvePreservedContinuousReadingMode(
          supportsContinuous: true,
          preserveFlag: false,
          currentState: loadedTrue,
        ),
        isFalse,
      );
    });

    test('preserveFlag=true + state.continuous=true → מחזיר true', () {
      // מסלול ה-listener על שינוי גופן/ניקוד: אסור לכבות את המצב.
      expect(
        TextBookBloc.resolvePreservedContinuousReadingMode(
          supportsContinuous: true,
          preserveFlag: true,
          currentState: loadedTrue,
        ),
        isTrue,
      );
    });

    test('preserveFlag=true + state.continuous=false → false', () {
      expect(
        TextBookBloc.resolvePreservedContinuousReadingMode(
          supportsContinuous: true,
          preserveFlag: true,
          currentState: loadedFalse,
        ),
        isFalse,
      );
    });

    test('currentState אינו Loaded (Initial/Loading) → false', () {
      // טעינה ראשונית של ספר: אין מה לשמר.
      final initial = TextBookInitial(TextBook(title: 'בראשית'), 0, false, []);
      expect(
        TextBookBloc.resolvePreservedContinuousReadingMode(
          supportsContinuous: true,
          preserveFlag: true,
          currentState: initial,
        ),
        isFalse,
      );

      expect(
        TextBookBloc.resolvePreservedContinuousReadingMode(
          supportsContinuous: true,
          preserveFlag: true,
          currentState: null,
        ),
        isFalse,
      );
    });
  });
}

TextBookLoaded _loaded({
  required bool continuous,
  required bool supports,
}) {
  return TextBookLoaded(
    book: TextBook(title: 'בראשית'),
    showLeftPane: false,
    content: const ['בראשית', 'ברא', 'אלהים'],
    fontSize: 18,
    showSplitView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    visibleLinks: const [],
    linksByLine: const {},
    tableOfContents: const [],
    removeNikud: false,
    supportsContinuousReadingMode: supports,
    continuousReadingMode: continuous,
    visibleIndices: const [0],
    pinLeftPane: false,
    searchText: '',
    searchMode: SearchMode.exact,
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}
