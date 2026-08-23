import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';

/// שדה "איתור ספר" בחלונית סינון התוצאות. הסינון עצמו נעשה ב-
/// SearchNavigationTree מול הספרים שיש להם תוצאות; ה-bloc רק מפרסם את
/// השאילתה. הטסט מקבע שאין כאן שום עבודה אסינכרונית — חיפוש ספרייה בכל
/// הקלדה שרף כשנייה של CPU לכל תו ועיכב את רענון העץ עד שהסתיים.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateFilterQuery — פרסום סינכרוני, בלי חיפוש ספרייה', () {
    test('השאילתה זמינה ב-state מיד, בלי המתנה לפעולה אסינכרונית', () async {
      final bloc = SearchBloc();
      addTearDown(bloc.close);

      bloc.add(UpdateFilterQuery('פסקי הראש'));
      // מיקרו-משימה אחת בלבד: זו ההשהיה שנדרשת לתור האירועים של ה-bloc.
      // כל await נוסף במסלול (חיפוש ספרייה) היה מחמיץ את הבדיקה.
      await Future<void>.value();

      expect(bloc.state.filterQuery, 'פסקי הראש');
    });

    test('כל אורך שאילתה מפורסם, כולל תו בודד וריקון', () async {
      final bloc = SearchBloc();
      addTearDown(bloc.close);

      for (final q in ['פ', 'פס', 'פסקי הראש', '']) {
        bloc.add(UpdateFilterQuery(q));
        await Future<void>.value();
        expect(bloc.state.filterQuery, q, reason: 'שאילתה: "$q"');
      }
    });

    test('הקלדת מילה שלמה מתעכלת כולה בפחות מ-100ms', () async {
      final bloc = SearchBloc();
      addTearDown(bloc.close);

      const typed = 'פסקי הראש';
      for (var i = 1; i <= typed.length; i++) {
        bloc.add(UpdateFilterQuery(typed.substring(0, i)));
      }

      // התקרה היא השמירה האמיתית כאן: חיפוש ספרייה לכל תו לקח מאות
      // מילישניות לתו, ותור של עשרה תווים לא היה מספיק לה בשום מכונה.
      await expectLater(
        bloc.stream.firstWhere((s) => s.filterQuery == typed),
        completes,
      ).timeout(const Duration(milliseconds: 100));

      expect(bloc.state.filterQuery, typed);
    });
  });
}
