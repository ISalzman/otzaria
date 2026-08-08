import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';

class _DelayedRepository implements PersonalNotesRepository {
  final requests = <String, Completer<List<PersonalNote>>>{};

  @override
  Future<List<PersonalNote>> loadNotes(String bookId, {int? categoryId}) {
    return requests
        .putIfAbsent(
          bookId,
          Completer<List<PersonalNote>>.new,
        )
        .future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('תוצאת טעינה ישנה אינה דורסת יעד הערות חדש', () async {
    final repository = _DelayedRepository();
    final bloc = PersonalNotesBloc(repository: repository);
    addTearDown(bloc.close);

    bloc.add(const LoadPersonalNotes('מפרש'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LoadPersonalNotes('ספר ראשי'));
    await Future<void>.delayed(Duration.zero);

    repository.requests['ספר ראשי']!.complete(const []);
    await Future<void>.delayed(Duration.zero);
    repository.requests['מפרש']!.complete(const []);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.bookId, 'ספר ראשי');
  });
}
