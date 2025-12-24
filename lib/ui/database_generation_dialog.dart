import 'package:flutter/material.dart';
import 'database_generation_screen.dart';

/// פונקציה להצגת דיאלוג יצירת מסד נתונים
void showDatabaseGenerationDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Stack(
          children: [
            const DatabaseGenerationScreen(),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'סגור',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
