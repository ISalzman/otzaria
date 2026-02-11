import 'package:equatable/equatable.dart';
import 'package:otzaria/models/heading.dart';

/// מצבים עבור זיהוי כותרות
abstract class HeadingDetectionState extends Equatable {
  const HeadingDetectionState();

  @override
  List<Object?> get props => [];
}

/// מצב התחלתי
class HeadingDetectionInitial extends HeadingDetectionState {
  const HeadingDetectionInitial();
}

/// בתהליך זיהוי או טעינה
class HeadingDetectionInProgress extends HeadingDetectionState {
  const HeadingDetectionInProgress();
}

/// זיהוי הצליח
class HeadingDetectionSuccess extends HeadingDetectionState {
  final List<Heading> headings;
  final int bookId;

  const HeadingDetectionSuccess({
    required this.headings,
    required this.bookId,
  });

  @override
  List<Object?> get props => [headings, bookId];
}

/// כותרות נטענו בהצלחה
class HeadingsLoaded extends HeadingDetectionState {
  final List<Heading> headings;
  final int bookId;

  const HeadingsLoaded({
    required this.headings,
    required this.bookId,
  });

  @override
  List<Object?> get props => [headings, bookId];
}

/// כותרת נמחקה בהצלחה
class HeadingDeleted extends HeadingDetectionState {
  final int headingId;

  const HeadingDeleted(this.headingId);

  @override
  List<Object?> get props => [headingId];
}

/// כותרות אוטומטיות נמחקו
class AutoHeadingsCleared extends HeadingDetectionState {
  final int bookId;

  const AutoHeadingsCleared(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

/// כותרת הומרה לידנית
class HeadingConvertedToManual extends HeadingDetectionState {
  final int headingId;

  const HeadingConvertedToManual(this.headingId);

  @override
  List<Object?> get props => [headingId];
}

/// רמת כותרת עודכנה
class HeadingLevelUpdated extends HeadingDetectionState {
  final int headingId;
  final int newLevel;

  const HeadingLevelUpdated({
    required this.headingId,
    required this.newLevel,
  });

  @override
  List<Object?> get props => [headingId, newLevel];
}

/// שגיאה בזיהוי או בפעולה
class HeadingDetectionFailure extends HeadingDetectionState {
  final String error;

  const HeadingDetectionFailure(this.error);

  @override
  List<Object?> get props => [error];
}
