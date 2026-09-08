import 'package:pdfrx/pdfrx.dart';

/// delegate הגלילה הפיזיקלי של pdfrx עם אפשרות עצירה: יעד הגלילה שלו נקבע
/// ב-translation של הזום הישן, ואחרי שינוי זום הוא מזיז את המסמך (issue #1258).
class StoppablePdfScrollPhysicsProvider
    extends PdfViewerScrollInteractionDelegateProvider {
  StoppablePdfScrollPhysicsProvider({
    PdfViewerScrollInteractionDelegateProvider? inner,
  }) : _inner =
           inner ?? const PdfViewerScrollInteractionDelegateProviderPhysics();

  final PdfViewerScrollInteractionDelegateProvider _inner;
  PdfViewerScrollInteractionDelegate? _delegate;

  @override
  PdfViewerScrollInteractionDelegate create() => _delegate = _inner.create();

  /// עוצר אנימציית גלילה/זום שבדרך; ללא delegate פעיל אין פעולה.
  void stop() => _delegate?.stop();

  // זהות לפי המופע: pdfrx יוצר delegate חדש בכל שינוי provider, והמסך מחזיק
  // מופע יחיד לכל חיי ה-viewer.
  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}
