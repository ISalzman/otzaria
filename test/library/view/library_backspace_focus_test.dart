import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/view/library_browser.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

/// issue #1061 — Backspace בשדה חיפוש הספרייה מחק את כל השורה: זיהוי
/// "שדה טקסט בפוקוס" בדק את `primaryFocus.context.widget`, אבל צומת
/// הפוקוס של TextField נקשר לווידג'ט Focus פנימי — הזיהוי החזיר false,
/// וה-Backspace סווג כ"פוקוס מחוץ לשדה" שסוגר את החיפוש כולו.
void main() {
  testWidgets('שדה החיפוש ממוקד — הזיהוי מכיר בו כשדה טקסט', (tester) async {
    final node = FocusNode(debugLabel: 'library-search');
    final controller = TextEditingController(text: 'חידושי הרשבע');
    addTearDown(() {
      node.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtzariaSearchField(
            controller: controller,
            hintText: 'איתור ספר',
            focusNode: node,
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);

    expect(
      isEditableTextFocusTarget(),
      isTrue,
      reason: 'הפוקוס בשדה — Backspace חייב להישאר מחיקת תו',
    );

    expect(
      resolveLibraryBackspaceAction(
        isEditableTextFocused: isEditableTextFocusTarget(),
        isLibrarySearchFocused: node.hasFocus,
        isSearchTextEmpty: controller.text.isEmpty,
      ),
      LibraryBackspaceAction.none,
      reason: 'שדה ממוקד עם טקסט — אסור לנקות את החיפוש',
    );
  });

  testWidgets('שדה ממוקד וריק — Backspace עדיין עולה תיקייה (התנהגות #899)', (
    tester,
  ) async {
    final node = FocusNode();
    final controller = TextEditingController();
    addTearDown(() {
      node.dispose();
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtzariaSearchField(
            controller: controller,
            hintText: 'איתור ספר',
            focusNode: node,
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();

    expect(
      resolveLibraryBackspaceAction(
        isEditableTextFocused: isEditableTextFocusTarget(),
        isLibrarySearchFocused: node.hasFocus,
        isSearchTextEmpty: controller.text.isEmpty,
      ),
      LibraryBackspaceAction.navigateUp,
    );
  });

  testWidgets('הפוקוס מחוץ לכל שדה — הזיהוי מחזיר false', (tester) async {
    final buttonNode = FocusNode();
    addTearDown(buttonNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElevatedButton(
            focusNode: buttonNode,
            onPressed: () {},
            child: const Text('כפתור'),
          ),
        ),
      ),
    );
    buttonNode.requestFocus();
    await tester.pump();

    expect(isEditableTextFocusTarget(), isFalse);
  });
}
