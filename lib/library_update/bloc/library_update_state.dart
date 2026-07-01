part of 'library_update_bloc.dart';

enum LibraryUpdateStatus {
  /// מצב מנוחה — אין פעולה פעילה.
  idle,

  /// בודק זמינות עדכון מול GitHub.
  checking,

  /// מוריד קובץ patch.
  downloading,

  /// מאמת/מחיל את העדכון על ה-DB.
  applying,

  /// מרענן את ה-runtime וה-caches.
  refreshing,

  /// הסתיים — ראה [LibraryUpdateState.hasUpdate].
  completed,

  /// נדרש אישור משתמש להורדה מלאה גדולה.
  needsFullConfirmation,

  /// מצב חסום שדורש פעולה ידנית.
  blocked,

  /// שגיאה.
  error,
}

class LibraryUpdateState extends Equatable {
  final LibraryUpdateStatus status;
  final String message;

  /// `true` אם הוחל עדכון בפועל (לצורך הפעלת ריענון ספרייה/אינדוקס ב-UI).
  final bool hasUpdate;

  final int stepIndex;
  final int totalSteps;
  final int? bytesDownloaded;
  final int? bytesTotal;

  /// התוכנית שנבחרה — זמינה במצב [LibraryUpdateStatus.needsFullConfirmation].
  final LibraryUpdatePlan? plan;

  final String? errorMessage;

  const LibraryUpdateState({
    this.status = LibraryUpdateStatus.idle,
    this.message = 'בדוק עדכוני ספרייה',
    this.hasUpdate = false,
    this.stepIndex = 0,
    this.totalSteps = 0,
    this.bytesDownloaded,
    this.bytesTotal,
    this.plan,
    this.errorMessage,
  });

  bool get isBusy =>
      status == LibraryUpdateStatus.checking ||
      status == LibraryUpdateStatus.downloading ||
      status == LibraryUpdateStatus.applying ||
      status == LibraryUpdateStatus.refreshing;

  LibraryUpdateState copyWith({
    LibraryUpdateStatus? status,
    String? message,
    bool? hasUpdate,
    int? stepIndex,
    int? totalSteps,
    int? bytesDownloaded,
    int? bytesTotal,
    LibraryUpdatePlan? plan,
    String? errorMessage,
  }) {
    return LibraryUpdateState(
      status: status ?? this.status,
      message: message ?? this.message,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      stepIndex: stepIndex ?? this.stepIndex,
      totalSteps: totalSteps ?? this.totalSteps,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      plan: plan ?? this.plan,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        hasUpdate,
        stepIndex,
        totalSteps,
        bytesDownloaded,
        bytesTotal,
        plan,
        errorMessage,
      ];
}
