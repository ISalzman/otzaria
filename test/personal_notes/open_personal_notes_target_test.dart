import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/personal_notes/utils/open_personal_notes_target.dart';

class _RecordingPersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _RecordingPersonalNotesBloc(super.initialState) {
    on<PersonalNotesEvent>((event, emit) => events.add(event));
  }

  final List<PersonalNotesEvent> events = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('פתיחת יעד מנקה סינון, טוענת את ספר המפרש ומרחיבה את השורה', () async {
    final bloc = _RecordingPersonalNotesBloc(
      const PersonalNotesState.initial().copyWith(
        showOnlyVisible: true,
        searchQuery: 'חיפוש קודם',
      ),
    );
    addTearDown(bloc.close);

    openPersonalNotesTarget(
      bloc,
      bookId: 'רש"י',
      categoryId: 9,
      lineNumber: 7,
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.events, hasLength(4));
    expect(bloc.events[0], isA<ToggleShowOnlyVisible>());
    expect(bloc.events[1], const UpdateSearchQuery(''));
    expect(bloc.events[2], const LoadPersonalNotes('רש"י', categoryId: 9));
    expect(bloc.events[3], const RequestExpandNotesForLine(7));
  });
}
