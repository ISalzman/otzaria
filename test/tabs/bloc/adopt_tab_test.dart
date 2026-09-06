import 'package:flutter/widgets.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/tabs_repository.dart';

import '../../helpers/memory_settings_cache.dart';

/// חלון שהוחזר לשימוש מאמץ כרטיסיה שנגררה אליו.
///
/// ## הבאג
///
/// האימוץ נעשה ב-`CloseAllTabs` ואחריו `AddTab`, ולכן המצב עבר דרך **אפס
/// כרטיסיות**. `ReadingScreen` מאזין בדיוק למעבר הזה
/// (`previous.hasOpenTabs && !current.hasOpenTabs`) ומנווט למסך הספרייה —
/// כלומר כל חלון שכבר היה פתוח פעם ונסגר נחת בספרייה במקום על הכרטיסיה
/// שנגררה אליו. המשתמש דיווח שזה קרה בכל סוגי הכרטיסיות ובשני מסלולי
/// הפתיחה (תפריט וגרירה), ורק בחלון שכבר היה פתוח — כי פתיחה ראשונה
/// עוברת בנקודת הכניסה של החלון המשני, שאין בה כרטיסיות קודמות.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  PdfBookTab pdf(String title, {bool pinned = false}) {
    final tab = PdfBookTab(
      book: PdfBook(title: title, path: '/nonexistent/$title.pdf'),
      pageNumber: 1,
    );
    tab.isPinned = pinned;
    return tab;
  }

  /// אוסף כל מצב שנפלט, כדי שאפשר יהיה לבדוק גם את **הדרך** ולא רק את היעד.
  Future<List<TabsState>> statesFor(
    TabsBloc bloc,
    void Function() act, {
    required int expected,
  }) async {
    final seen = <TabsState>[];
    final sub = bloc.stream.listen(seen.add);
    act();
    while (seen.length < expected) {
      await Future<void>.delayed(Duration.zero);
    }
    await sub.cancel();
    return seen;
  }

  test('AdoptTab אינו מעביר את המצב דרך אפס כרטיסיות', () async {
    final bloc = TabsBloc(repository: _FakeTabsRepository());
    addTearDown(bloc.close);
    bloc.add(ReplaceAllTabs([pdf('ישן א'), pdf('ישן ב')], 0));
    await statesFor(bloc, () {}, expected: 1);

    final states = await statesFor(
      bloc,
      () => bloc.add(AdoptTab(pdf('שנגררה'))),
      expected: 1,
    );

    expect(
      states.map((s) => s.hasOpenTabs),
      everyElement(isTrue),
      reason: 'מעבר דרך "אין כרטיסיות" הוא מה שמנווט למסך הספרייה',
    );
    expect(states.last.tabs.map((t) => t.title), ['שנגררה']);
    expect(states.last.currentTabIndex, 0);
  });

  test('הצמד הישן — CloseAllTabs ואז AddTab — כן עובר דרך אפס', () async {
    // ⚠️ הבדיקה הזו מתעדת את הבאג עצמו. אם היא מתחילה להיכשל, מישהו תיקן
    // את `ReadingScreen` או את `CloseAllTabs`, וייתכן ש-[AdoptTab] מיותר.
    final bloc = TabsBloc(repository: _FakeTabsRepository());
    addTearDown(bloc.close);
    bloc.add(ReplaceAllTabs([pdf('ישן')], 0));
    await statesFor(bloc, () {}, expected: 1);

    final states = await statesFor(bloc, () {
      bloc
        ..add(CloseAllTabs())
        ..add(AddTab(pdf('שנגררה')));
    }, expected: 2);

    expect(states.first.hasOpenTabs, isFalse);
    expect(states.last.hasOpenTabs, isTrue);
  });

  test('כרטיסיה מוצמדת שורדת את האימוץ, כמו ב-CloseAllTabs', () async {
    final bloc = TabsBloc(repository: _FakeTabsRepository());
    addTearDown(bloc.close);
    bloc.add(ReplaceAllTabs([pdf('נעוצה', pinned: true), pdf('רגילה')], 0));
    await statesFor(bloc, () {}, expected: 1);

    final states = await statesFor(
      bloc,
      () => bloc.add(AdoptTab(pdf('שנגררה'))),
      expected: 1,
    );

    expect(states.last.tabs.map((t) => t.title), ['נעוצה', 'שנגררה']);
    expect(
      states.last.currentTab?.title,
      'שנגררה',
      reason: 'הכרטיסיה שהמשתמש גרר היא זו שהוא מצפה לראות',
    );
  });

  test('אימוץ לחלון ריק מוסיף בלי לפגוע', () async {
    final bloc = TabsBloc(repository: _FakeTabsRepository());
    addTearDown(bloc.close);

    final states = await statesFor(
      bloc,
      () => bloc.add(AdoptTab(pdf('שנגררה'))),
      expected: 1,
    );

    expect(states.last.tabs.map((t) => t.title), ['שנגררה']);
    expect(states.last.currentTabIndex, 0);
  });
}

class _FakeTabsRepository extends TabsRepository {
  @override
  List<OpenedTab> loadTabs() => const [];

  @override
  int loadCurrentTabIndex() => 0;

  @override
  Future<void> saveTabs(List<OpenedTab> tabs, int currentTabIndex) async {}

  @override
  Future<void> saveCurrentTabIndex(
    List<OpenedTab> tabs,
    int currentTabIndex,
  ) async {}
}
