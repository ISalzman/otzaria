import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/text_book/bloc/heading_detection_event.dart';
import 'package:otzaria/text_book/bloc/heading_detection_state.dart';
import 'package:otzaria/text_book/heading_repository.dart';

/// BLoC לניהול זיהוי וניהול כותרות
class HeadingDetectionBloc
    extends Bloc<HeadingDetectionEvent, HeadingDetectionState> {
  final HeadingRepository repository;

  HeadingDetectionBloc({required this.repository})
      : super(const HeadingDetectionInitial()) {
    on<DetectHeadingsRequested>(_onDetectHeadingsRequested);
    on<LoadHeadingsRequested>(_onLoadHeadingsRequested);
    on<DeleteHeadingRequested>(_onDeleteHeadingRequested);
    on<ClearAutoHeadingsRequested>(_onClearAutoHeadingsRequested);
    on<ConvertToManualRequested>(_onConvertToManualRequested);
    on<UpdateHeadingLevelRequested>(_onUpdateHeadingLevelRequested);
  }

  /// מטפל בבקשה לזיהוי כותרות
  Future<void> _onDetectHeadingsRequested(
    DetectHeadingsRequested event,
    Emitter<HeadingDetectionState> emit,
  ) async {
    emit(const HeadingDetectionInProgress());

    try {
      final headings = await repository.detectAndSaveHeadings(
        bookId: event.bookId,
        content: event.content,
        maxWords: event.maxWords,
        headingLevel: event.headingLevel,
        isMarkdown: event.isMarkdown,
      );

      emit(HeadingDetectionSuccess(
        headings: headings,
        bookId: event.bookId,
      ));
    } catch (e) {
      emit(HeadingDetectionFailure('שגיאה בזיהוי כותרות: ${e.toString()}'));
    }
  }

  /// מטפל בבקשה לטעינת כותרות
  Future<void> _onLoadHeadingsRequested(
    LoadHeadingsRequested event,
    Emitter<HeadingDetectionState> emit,
  ) async {
    emit(const HeadingDetectionInProgress());

    try {
      final headings = await repository.getHeadingsForBook(
        event.bookId,
        source: event.source,
      );

      emit(HeadingsLoaded(
        headings: headings,
        bookId: event.bookId,
      ));
    } catch (e) {
      emit(HeadingDetectionFailure('שגיאה בטעינת כותרות: ${e.toString()}'));
    }
  }

  /// מטפל בבקשה למחיקת כותרת
  Future<void> _onDeleteHeadingRequested(
    DeleteHeadingRequested event,
    Emitter<HeadingDetectionState> emit,
  ) async {
    try {
      await repository.deleteHeading(event.bookId, event.headingId);
      emit(HeadingDeleted(event.headingId));
    } catch (e) {
      emit(HeadingDetectionFailure('שגיאה במחיקת כותרת: ${e.toString()}'));
    }
  }

  /// מטפל בבקשה למחיקת כותרות אוטומטיות
  Future<void> _onClearAutoHeadingsRequested(
    ClearAutoHeadingsRequested event,
    Emitter<HeadingDetectionState> emit,
  ) async {
    try {
      await repository.clearAutoDetectedHeadings(event.bookId);
      emit(AutoHeadingsCleared(event.bookId));
    } catch (e) {
      emit(HeadingDetectionFailure(
          'שגיאה במחיקת כותרות אוטומטיות: ${e.toString()}'));
    }
  }

  /// מטפל בבקשה להמרת כותרת לידנית
  Future<void> _onConvertToManualRequested(
    ConvertToManualRequested event,
    Emitter<HeadingDetectionState> emit,
  ) async {
    try {
      await repository.convertToManual(event.bookId, event.headingId);
      emit(HeadingConvertedToManual(event.headingId));
    } catch (e) {
      emit(HeadingDetectionFailure('שגיאה בהמרת כותרת: ${e.toString()}'));
    }
  }

  /// מטפל בבקשה לעדכון רמת כותרת
  Future<void> _onUpdateHeadingLevelRequested(
    UpdateHeadingLevelRequested event,
    Emitter<HeadingDetectionState> emit,
  ) async {
    try {
      await repository.updateHeadingLevel(
        event.bookId,
        event.headingId,
        event.newLevel,
      );
      emit(HeadingLevelUpdated(
        headingId: event.headingId,
        newLevel: event.newLevel,
      ));
    } catch (e) {
      emit(HeadingDetectionFailure('שגיאה בעדכון רמת כותרת: ${e.toString()}'));
    }
  }
}
