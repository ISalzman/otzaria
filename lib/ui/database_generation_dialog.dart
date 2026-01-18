import 'package:flutter/material.dart';
import 'package:otzaria/widgets/reusable_items_dialog.dart';
import 'database_generation_screen.dart';

/// פונקציה להצגת דיאלוג יצירת מסד נתונים
///
/// הדיאלוג מאפשר למשתמש ליצור מסד נתונים חדש לספרייה
/// כולל אפשרויות לבחירת ספרים, מעקב אחר התקדמות ועוד
void showDatabaseGenerationDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ReusableItemsDialog(
      title: 'יצירת מסד נתונים',
      child: DatabaseGenerationScreen(),
    ),
  );
}
