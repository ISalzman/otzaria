/// מתאם פשוט שמונע הרצת עבודות startup כבדות לפני שהוחלט
/// אם האינדוקס האוטומטי ירוץ, ולפני שהוא הסתיים בפועל.
class StartupWorkGate {
  bool _libraryLoaded = false;
  bool _indexingDecisionResolved = false;
  bool _indexingPendingOrRunning = false;
  bool _startupWorkStarted = false;

  /// מסמן שהספרייה נטענה.
  void markLibraryLoaded() {
    _libraryLoaded = true;
  }

  /// מסמן שהוחלט האם האינדוקס האוטומטי אמור לרוץ.
  void markIndexingDecisionResolved({required bool expectIndexing}) {
    _indexingDecisionResolved = true;
    _indexingPendingOrRunning = expectIndexing;
  }

  /// מעדכן את מצב האינדוקס בפועל.
  void markIndexingRunning(bool isRunning) {
    _indexingPendingOrRunning = isRunning;
  }

  /// מחזיר `true` פעם אחת בלבד, ורק כאשר בטוח להתחיל עבודות startup נוספות.
  bool consumeStartPermission() {
    if (_startupWorkStarted ||
        !_libraryLoaded ||
        !_indexingDecisionResolved ||
        _indexingPendingOrRunning) {
      return false;
    }

    _startupWorkStarted = true;
    return true;
  }
}
