import 'package:flutter/widgets.dart';

/// גודל הפענוח בפיקסלים פיזיים לתמונה שמוצגת ב-[logicalSize] פיקסלים לוגיים.
///
/// מיועד ל-`cacheWidth`/`cacheHeight` של `Image`. בלי זה פלאטר מפענח כל קובץ
/// ברזולוציה המלאה שלו — לוגו של 2480×3508 בריבוע 50 תופס 35MB במקום 127KB.
///
/// [context] - הקשר שממנו נלקח `devicePixelRatio` של המסך
/// [logicalSize] - הגודל שבו התמונה מוצגת בפועל, בפיקסלים לוגיים
int imageDecodeSize(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context)).ceil();
