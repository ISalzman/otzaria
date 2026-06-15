// טסט רגרסיה לפתיחת דיאלוג הגדרות צורת הדף דרך ה-notifier:
// כפתור גלגל השיניים בסרגל העליון (TextBookScreen) רק מסמן בקשה ב-notifier,
// ו-PageShapeScreen הוא שפותח את הדיאלוג — עם onSettingsChanged מחווט, כדי
// שכל שינוי בדיאלוג יוחל על המסך בעדכון חי בלי להמתין לסגירתו.
// (רגרסיה: בעבר הכפתור פתח את הדיאלוג בעצמו בלי החיווט החי, והשינויים
// הופיעו רק אחרי סגירת הדיאלוג.)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/page_shape/page_shape_screen.dart';
import 'package:otzaria/text_book/view/page_shape/page_shape_settings_dialog.dart';
import 'package:otzaria/text_book/view/page_shape/utils/page_shape_settings_manager.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../test_helpers/memory_cache_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets(
      'בקשת פתיחה דרך openSettingsNotifier פותחת את הדיאלוג עם עדכון חי מחווט',
      (tester) async {
    final openSettingsNotifier = ValueNotifier<int>(0);
    addTearDown(openSettingsNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TextBookBloc>.value(
              value: _TestTextBookBloc(_loadedState()),
            ),
            BlocProvider<PersonalNotesBloc>.value(
              value: _TestPersonalNotesBloc(
                const PersonalNotesState(
                  isLoading: false,
                  bookId: 'ספר בדיקה',
                  locatedNotes: [],
                  missingNotes: [],
                  errorMessage: null,
                  filteredLocatedNotes: [],
                  filteredMissingNotes: [],
                ),
              ),
            ),
            BlocProvider<SettingsBloc>.value(
              value: _TestSettingsBloc(SettingsState.initial()),
            ),
          ],
          child: PageShapeScreen(
            openBookCallback: (_) {},
            openSettingsNotifier: openSettingsNotifier,
          ),
        ),
      ),
    );

    // המתנה לסיום טעינת התצורה (DefaultCommentators מחזיר ריק ללא DB)
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageShapeSettingsDialog), findsNothing);

    // לחיצה על כפתור גלגל השיניים בסרגל העליון מתורגמת להעלאת ה-notifier
    openSettingsNotifier.value++;
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageShapeSettingsDialog), findsOneWidget);

    // החיווט החי: הדיאלוג חייב לקבל onSettingsChanged כדי שהמסך יתעדכן
    // תוך כדי שינוי, ולא רק אחרי סגירת הדיאלוג.
    final dialog = tester.widget<PageShapeSettingsDialog>(
      find.byType(PageShapeSettingsDialog),
    );
    expect(dialog.onSettingsChanged, isNotNull);
  });

  testWidgets('כשל טעינת מפרש תחתון אינו שומר הסתרה גלובלית', (tester) async {
    const missingCommentator = 'מפרש בדיקה שלא קיים במאגר';

    await PageShapeSettingsManager.saveConfiguration(
      'ספר בדיקה',
      const {
        'left': null,
        'right': null,
        'bottom': missingCommentator,
        'bottomRight': null,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TextBookBloc>.value(
              value: _TestTextBookBloc(
                _loadedState(
                  availableCommentators: const [missingCommentator],
                ),
              ),
            ),
            BlocProvider<PersonalNotesBloc>.value(
              value: _TestPersonalNotesBloc(
                const PersonalNotesState(
                  isLoading: false,
                  bookId: 'ספר בדיקה',
                  locatedNotes: [],
                  missingNotes: [],
                  errorMessage: null,
                  filteredLocatedNotes: [],
                  filteredMissingNotes: [],
                ),
              ),
            ),
            BlocProvider<SettingsBloc>.value(
              value: _TestSettingsBloc(SettingsState.initial()),
            ),
          ],
          child: PageShapeScreen(openBookCallback: (_) {}),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(
      Settings.getValue<bool>('page_shape_global_visibility_bottom'),
      isNot(false),
    );
    expect(
      Settings.getValue<bool>('page_shape_use_book_settings_ספר בדיקה'),
      isNot(true),
    );
  });
}

TextBookLoaded _loadedState({
  List<String> availableCommentators = const ['רש"י על ספר בדיקה'],
}) {
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
    showLeftPane: false,
    content: const ['שורה א'],
    fontSize: 18,
    showSplitView: false,
    showPageShapeView: true,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: availableCommentators,
    links: const [],
    visibleLinks: const [],
    linksByLine: const {},
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0],
    selectedIndex: 0,
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _TestPersonalNotesBloc(super.initialState) {
    on<PersonalNotesEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
