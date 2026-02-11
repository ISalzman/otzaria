import 'package:equatable/equatable.dart';
import 'package:otzaria/models/heading.dart';

/// אירועים עבור זיהוי כותרות
abstract class HeadingDetectionEvent extends Equatable {
  const HeadingDetectionEvent();

  @override
  List<Object?> get props => [];
}

/// בקשה לזיהוי כותרות בספר
class DetectHeadingsRequested extends HeadingDetectionEvent {
  final int bookId;
  final String content;
  final int maxWords;
  final int headingLevel;
  final bool isMarkdown;

  const DetectHeadingsRequested({
    required this.bookId,
    required this.content,
    this.maxWords = 20,
    this.headingLevel = 6,
    this.isMarkdown = false,
  });

  @override
  List<Object?> get props =>
      [bookId, content, maxWords, headingLevel, isMarkdown];
}

/// טעינת כותרות קיימות מהמסד
class LoadHeadingsRequested extends HeadingDetectionEvent {
  final int bookId;
  final HeadingSource? source;

  const LoadHeadingsRequested({
    required this.bookId,
    this.source,
  });

  @override
  List<Object?> get props => [bookId, source];
}

/// מחיקת כותרת
class DeleteHeadingRequested extends HeadingDetectionEvent {
  final int bookId;
  final int headingId;

  const DeleteHeadingRequested({
    required this.bookId,
    required this.headingId,
  });

  @override
  List<Object?> get props => [bookId, headingId];
}

/// מחיקת כל הכותרות האוטומטיות
class ClearAutoHeadingsRequested extends HeadingDetectionEvent {
  final int bookId;

  const ClearAutoHeadingsRequested(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

/// המרת כותרת אוטומטית לידנית
class ConvertToManualRequested extends HeadingDetectionEvent {
  final int bookId;
  final int headingId;

  const ConvertToManualRequested({
    required this.bookId,
    required this.headingId,
  });

  @override
  List<Object?> get props => [bookId, headingId];
}

/// עדכון רמת כותרת
class UpdateHeadingLevelRequested extends HeadingDetectionEvent {
  final int bookId;
  final int headingId;
  final int newLevel;

  const UpdateHeadingLevelRequested({
    required this.bookId,
    required this.headingId,
    required this.newLevel,
  });

  @override
  List<Object?> get props => [bookId, headingId, newLevel];
}
