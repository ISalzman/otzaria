import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_notes_sidebar.dart';
import 'package:otzaria/widgets/feedback/scrollable_positioned_list_scrollbar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../test_helpers/memory_cache_provider.dart';

/// רגרסיה: חלונית ההערות הייתה `ListView` בלי מסילה משלה, ולכן קיבלה את פס
/// הגלילה האוטומטי של הפאנל — שנדחף לקצה החיצוני, כלומר לשמאל. באותה חלונית
/// לשונית המפרשים הציגה מסילה בימין, וכל לשונית הראתה את הפס בצד אחר.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  PersonalNote note(int index) => PersonalNote(
    id: 'note-$index',
    bookId: 'ספר בדיקה',
    lineNumber: index + 1,
    displayTitle: 'הערה בשורה ${index + 1}',
    lastKnownLineNumber: index + 1,
    status: PersonalNoteStatus.located,
    content: 'תוכן הערה $index',
    contentPlain: 'תוכן הערה $index',
    contentFormat: PersonalNoteContentFormat.plain,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpSidebar(WidgetTester tester, {int noteCount = 30}) async {
    final notesBloc = _StubNotesBloc(
      List.generate(noteCount, note),
    );
    addTearDown(notesBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          // האפליקציה כולה RTL (locale he_IL); בלי זה הצד נמדד הפוך.
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BlocProvider<PersonalNotesBloc>.value(
              value: notesBloc,
              child: PersonalNotesSidebar(
                bookId: 'ספר בדיקה',
                onNavigateToLine: (_) {},
                visibleLineIndices: const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('המסילה בקצה ימין של החלונית, לא בשמאל', (tester) async {
    await pumpSidebar(tester);

    final barRect = tester.getRect(
      find.byType(ScrollablePositionedListScrollbar),
    );
    final listRect = tester.getRect(find.byType(ScrollablePositionedList));

    expect(
      listRect.right,
      lessThan(barRect.right),
      reason: 'המסילה חייבת לתפוס את הקצה הימני והרשימה להצטמצם לפניה',
    );
    expect(
      listRect.left,
      barRect.left,
      reason: 'אין מסילה בקצה השמאלי — הרשימה מגיעה עד לשם',
    );
  });

  testWidgets('המסילה והרשימה חולקות offsetController', (tester) async {
    // הערה ארוכה עשויה להיות גבוהה מהמסך. בלי ה-offsetController האגודל נוחת
    // רק על גבולות פריטים, וגרירה בתוך הערה כזו אינה מזיזה כלום.
    await pumpSidebar(tester);

    final bar = tester.widget<ScrollablePositionedListScrollbar>(
      find.byType(ScrollablePositionedListScrollbar),
    );
    final list = tester.widget<ScrollablePositionedList>(
      find.byType(ScrollablePositionedList),
    );

    expect(bar.offsetController, isNotNull);
    expect(bar.offsetController, same(list.scrollOffsetController));
  });

  testWidgets('אין מה לגלול — אין מסילה ואין צמצום של הרשימה', (tester) async {
    await pumpSidebar(tester, noteCount: 1);

    final barRect = tester.getRect(
      find.byType(ScrollablePositionedListScrollbar),
    );
    final listRect = tester.getRect(find.byType(ScrollablePositionedList));

    expect(listRect.right, barRect.right);
  });
}

class _StubNotesBloc extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _StubNotesBloc(this.notes) : super(const PersonalNotesState.initial()) {
    on<PersonalNotesEvent>((event, emit) {
      if (event is LoadPersonalNotes) {
        emit(
          state.copyWith(
            bookId: event.bookId,
            locatedNotes: notes,
            isLoading: false,
          ),
        );
      }
    });
  }

  final List<PersonalNote> notes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
