import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// שער הבנייה מחדש של עץ תצוגת הספר.
///
/// המלכוד המרכזי: `buildWhen` על ווידג'ט פנימי אינו מונע בנייה כשההורה
/// נבנה — הוא רק מקפיא את המצב שנמסר. לכן השער חייב לשבת גם בשורש העץ,
/// ובדיקה שמאמתת רק את הפרדיקט הטהור תעבור גם כשהשער כולו חסר תועלת.
void main() {
  group('textBookStateDiffersBeyondVisibleIndices', () {
    test('תזוזת גלילה בלבד אינה מצדיקה בנייה מחדש', () {
      final before = _loaded();
      final after = before.copyWith(visibleIndices: const [7, 8, 9]);

      expect(textBookStateDiffersBeyondVisibleIndices(before, after), isFalse);
    });

    test('כותרת שהשתנתה עם הגלילה כן מצדיקה בנייה מחדש', () {
      final before = _loaded();
      final after = before.copyWith(
        visibleIndices: const [7, 8, 9],
        currentTitle: 'סימן ב',
      );

      expect(textBookStateDiffersBeyondVisibleIndices(before, after), isTrue);
    });

    test('בחירת שורה מצדיקה בנייה מחדש', () {
      final before = _loaded();

      expect(
        textBookStateDiffersBeyondVisibleIndices(
          before,
          before.copyWith(selectedIndex: 4),
        ),
        isTrue,
      );
    });

    test('מעבר מצב קריאה רציף מצדיק בנייה מחדש', () {
      final before = _loaded();
      final after = before.copyWith(
        continuousReadingMode: !before.continuousReadingMode,
        visibleIndices: const [3],
      );

      expect(textBookStateDiffersBeyondVisibleIndices(before, after), isTrue);
    });

    test('מצב שאינו טעון תמיד נבנה', () {
      final loaded = _loaded();
      final initial = TextBookInitial.named(
        TextBook(title: 'ספר'),
        0,
        false,
        const [],
      );

      expect(textBookStateDiffersBeyondVisibleIndices(initial, loaded), isTrue);
      expect(textBookStateDiffersBeyondVisibleIndices(loaded, initial), isTrue);
    });

    test('copyWith מכסה כל שדה שמשתתף בהשוואה', () {
      // ההשוואה בנויה על כך ש-copyWith משמר כל שדה ב-props. שדה שיתווסף
      // ל-props ולא ל-copyWith יחזור לברירת המחדל, ההשוואה תראה "זהה",
      // ובנייה תיחסם בטעות בדיוק כשהיא נדרשת.
      final state = _loaded();

      expect(state.copyWith(), equals(state));
    });
  });

  group('שער הבנייה בעץ ווידג\'טים', () {
    testWidgets('שער בשורש מונע בנייה של כל תת-העץ', (tester) async {
      final cubit = _StateCubit(_loaded());
      var rootBuilds = 0;
      var leafBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: BlocBuilder<_StateCubit, TextBookState>(
              buildWhen: textBookStateDiffersBeyondVisibleIndices,
              builder: (context, _) {
                rootBuilds++;
                return BlocBuilder<_StateCubit, TextBookState>(
                  buildWhen: textBookStateDiffersBeyondVisibleIndices,
                  builder: (context, _) {
                    leafBuilds++;
                    return const SizedBox();
                  },
                );
              },
            ),
          ),
        ),
      );

      final baseline = leafBuilds;
      for (var i = 0; i < 5; i++) {
        cubit.scrollTo([i, i + 1]);
        await tester.pump();
      }

      expect(rootBuilds, 1, reason: 'השורש נבנה רק בפריים הראשון');
      expect(
        leafBuilds,
        baseline,
        reason: 'תזוזת גלילה אינה בונה מחדש את העלה',
      );

      await cubit.close();
    });

    testWidgets('הסרת השער מהשורש מבטלת גם את השער בעלה', (tester) async {
      // מתעד למה השער חייב לשבת בשורש: `buildWhen` בעלה אינו עוצר בנייה
      // שמגיעה מההורה, ובנוסף מוסר לו מצב ישן.
      final cubit = _StateCubit(_loaded());
      var leafBuilds = 0;
      List<int>? leafSaw;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: BlocBuilder<_StateCubit, TextBookState>(
              builder: (context, _) {
                return BlocBuilder<_StateCubit, TextBookState>(
                  buildWhen: textBookStateDiffersBeyondVisibleIndices,
                  builder: (context, state) {
                    leafBuilds++;
                    leafSaw = (state as TextBookLoaded).visibleIndices;
                    return const SizedBox();
                  },
                );
              },
            ),
          ),
        ),
      );

      final baseline = leafBuilds;
      cubit.scrollTo(const [41, 42]);
      await tester.pump();

      expect(
        leafBuilds,
        greaterThan(baseline),
        reason: 'העלה נבנה למרות buildWhen, כי ההורה נבנה',
      );
      expect(
        leafSaw,
        isNot(const [41, 42]),
        reason: 'ובנוסף הוא מקבל מצב ישן — לכן אין להסתמך על שער בעלה בלבד',
      );

      await cubit.close();
    });
  });
}

class _StateCubit extends Cubit<TextBookState> {
  _StateCubit(super.initialState);

  void scrollTo(List<int> visibleIndices) {
    final current = state as TextBookLoaded;
    emit(current.copyWith(visibleIndices: visibleIndices));
  }
}

TextBookLoaded _loaded() => TextBookLoaded(
  book: TextBook(title: 'ספר בדיקה'),
  content: const ['שורה א', 'שורה ב'],
  contentVersion: 1,
  fontSize: 20,
  showLeftPane: false,
  showSplitView: false,
  showTzuratHadafView: false,
  showPageShapeView: true,
  activeCommentators: const [],
  commentatorGroups: const [],
  availableCommentators: const [],
  rareCommentators: const {},
  links: const [],
  linksByLine: const {},
  visibleLinks: const [],
  selectedLinkTypes: const {},
  tableOfContents: const [],
  removeNikud: false,
  removePunctuation: false,
  isTanach: false,
  nikudExemptByTanach: false,
  punctuationExemptByTanach: false,
  supportsContinuousReadingMode: false,
  continuousReadingMode: false,
  readingSegments: const [],
  visibleIndices: const [0],
  selectedIndices: const {},
  pinLeftPane: false,
  searchText: '',
  searchOptions: const {},
  alternativeWords: const {},
  spacingValues: const {},
  searchMode: SearchMode.exact,
  searchDistance: 0,
  matchPolicy: SearchMatchPolicy.standard,
  scrollController: ItemScrollController(),
  positionsListener: ItemPositionsListener.create(),
  linksLoading: false,
  hasLinksFile: false,
  highlightText: '',
);
