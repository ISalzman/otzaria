import 'package:equatable/equatable.dart';

abstract class EmptyLibraryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PickDirectoryRequested extends EmptyLibraryEvent {}

class PickArchiveFileRequested extends EmptyLibraryEvent {}

class DownloadLibraryRequested extends EmptyLibraryEvent {}

/// בודק מקום פנוי בהתקנה וקובע אם כפתור ההורדה זמין.
/// נשלח בעת טעינת המסך.
class CheckDiskSpaceRequested extends EmptyLibraryEvent {}

class DeleteZipAnswered extends EmptyLibraryEvent {
  final bool shouldDelete;
  final String zipPath;
  final String extractedPath;

  DeleteZipAnswered({
    required this.shouldDelete,
    required this.zipPath,
    required this.extractedPath,
  });

  @override
  List<Object?> get props => [shouldDelete, zipPath, extractedPath];
}

/// בחירת קובץ seforim.db ישירות דרך file picker (SAF-aware).
/// משמש כאשר הגישה לנתיב הפיזי נכשלת ב-Android Scoped Storage.
class PickDbFileRequested extends EmptyLibraryEvent {
  /// תיקיית הספרייה שנבחרה (תישמר ב-keyLibraryPath)
  final String libraryPath;

  /// הנתיב הפנימי שאליו יועתק הקובץ
  final String internalDbPath;

  /// הנתיב החיצוני המקורי של seforim.db (למחיקה אם shouldMove == true)
  final String externalDbPath;

  /// אם true — ינסה למחוק את הקובץ החיצוני המקורי לאחר ההעתקה.
  final bool shouldMove;

  PickDbFileRequested({
    required this.libraryPath,
    required this.internalDbPath,
    required this.externalDbPath,
    this.shouldMove = false,
  });

  @override
  List<Object?> get props =>
      [libraryPath, internalDbPath, externalDbPath, shouldMove];
}
