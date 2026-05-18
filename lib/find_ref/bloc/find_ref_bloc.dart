import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/find_ref/bloc/find_ref_event.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/find_ref/bloc/find_ref_state.dart';
import 'package:otzaria/find_ref/repository/db_reference_result.dart';
import 'package:otzaria/models/books.dart';

class FindRefBloc extends Bloc<FindRefEvent, FindRefState> {
  final FindRefRepository findRefRepository;

  FindRefBloc({required this.findRefRepository}) : super(FindRefInitial()) {
    // restartable: כל SearchRefRequested חדש מבטל handler קודם שעדיין רץ.
    // כך הקלדה מהירה לא יכולה להוביל לכך ש-fetch ישן יחליף תוצאות חדשות
    // (race condition כשה-DB מחזיר תוצאות בסדר לא צפוי).
    on<SearchRefRequested>(_onSearchRefRequested, transformer: restartable());
    on<ClearSearchRequested>(_onClearSearchRequested);
    on<OpenBookRequested>(_onOpenBookRequested);
  }

  Future<void> _onSearchRefRequested(
      SearchRefRequested event, Emitter<FindRefState> emit) async {
    if (event.refText.length < 2) {
      emit(const FindRefSuccess([]));
      return;
    }
    emit(FindRefLoading());
    try {
      final List<DbReferenceResult> refs = await findRefRepository.findRefs(
        event.refText,
        includePersonalBooks: event.includePersonalBooks,
      );
      // emit.isDone יהיה true אם ה-handler בוטל ע"י restartable
      // (event חדש הגיע באמצע ה-fetch). במצב כזה לא נpath את התוצאות
      // המיושנות.
      if (emit.isDone) return;
      emit(FindRefSuccess(refs));
    } catch (e) {
      if (emit.isDone) return;
      emit(FindRefError(e.toString()));
    }
  }

  void _onClearSearchRequested(
      ClearSearchRequested event, Emitter<FindRefState> emit) {
    emit(FindRefInitial());
  }

  void _onOpenBookRequested(
      OpenBookRequested event, Emitter<FindRefState> emit) {
    final book = event.book;
    final index = event.index;
    emit(
        FindRefBookOpening(book: book, index: index)); // Emit BookOpening state
  }
}

class FindRefBookOpening extends FindRefState {
  // Define BookOpening state
  final Book book;
  final int index;

  const FindRefBookOpening({required this.book, required this.index});

  @override
  List<Object> get props => [book, index];
}
