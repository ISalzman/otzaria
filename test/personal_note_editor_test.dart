import 'dart:convert';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_editor.dart';

void main() {
  testWidgets('כפתור bold פועל גם כ-toggle ומסיר עיצוב קיים', (tester) async {
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
    await tester.pump();

    expect(_deltaHasAttribute(controller, quill.Attribute.bold), isTrue);

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
    await tester.pump();

    expect(_deltaHasAttribute(controller, quill.Attribute.bold), isFalse);
  });

  testWidgets('לחיצה על כפתור עיצוב מחזירה פוקוס לעורך', (tester) async {
    // רגרסיה: בעבר לחיצה על IconButton בטולבר גזלה פוקוס מ-QuillEditor
    // ובדסקטופ הפוקוס לא חזר אוטומטית, כי skipRequestKeyboard לבדו לא
    // מספיק כש-_keyboardVisible תמיד true בדסקטופ. הפתרון: _toggleAttribute
    // קורא ידנית editorFocusNode.requestFocus() בסוף.
    final focusNode = FocusNode(debugLabel: 'editor');
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      quill.ChangeSource.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: focusNode,
            scrollController: ScrollController(),
            autofocus: true,
            linkableNotes: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue,
        reason: 'autofocus אמור היה לתפוס פוקוס בהתחלה');

    await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue,
        reason: 'לחיצה על הטולבר חייבת להשאיר את הפוקוס על העורך');
  });

  test('QuillController מוגדר עם enableExternalRichPaste=false', () {
    // רגרסיה: ב-Otzaria העתקה ללוח יוצרת גם HTML מעוצב. כשהדבקנו לעורך
    // הערות, Quill קרא את ה-HTML והעיצוב נדבק לטקסט וגרר את ההמשך
    // לאותו עיצוב. הפתרון: לכבות את ההדבקה החיצונית של rich text.
    final controller = buildPersonalNoteEditorController(
      initialContent: '',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    expect(
      // ignore: experimental_member_use
      controller.quillController.config.clipboardConfig?.enableExternalRichPaste,
      isFalse,
    );

    controller.quillController.dispose();
  });

  testWidgets('QuillEditor מוגדר ללא תפריט סלקציה אוטומטי', (tester) async {
    // רגרסיה: Quill מציגה אוטומטית תפריט copy/paste בסיום גרירה בדסקטופ.
    // בהערות אישיות זה מציק (יש לנו טולבר משלנו וקיצורי מקלדת).
    // הפתרון: enableSelectionToolbar: false ב-QuillEditorConfig.
    final controller = buildPersonalNoteEditorController(
      initialContent: 'שלום עולם',
      initialFormat: PersonalNoteContentFormat.plain,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteEditorBody(
            controller: controller,
            focusNode: FocusNode(),
            scrollController: ScrollController(),
            autofocus: false,
            linkableNotes: const [],
          ),
        ),
      ),
    );

    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    expect(editor.config.enableSelectionToolbar, isFalse);
  });
}

bool _deltaHasAttribute(
  PersonalNoteEditorController controller,
  quill.Attribute attribute,
) {
  final operations = jsonDecode(
    jsonEncode(controller.quillController.document.toDelta().toJson()),
  ) as List<dynamic>;

  for (final operation in operations) {
    final attributes = (operation as Map<String, dynamic>)['attributes'];
    if (attributes is Map<String, dynamic> &&
        attributes.containsKey(attribute.key)) {
      return true;
    }
  }

  return false;
}
