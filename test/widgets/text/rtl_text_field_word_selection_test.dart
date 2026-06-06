import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

/// בודק בחירה ברמת מילה (Ctrl/Alt+Shift+חץ) ב-[RtlTextField] בכיווניות RTL:
/// בעברית offset 0 מימין; חץ שמאל ויזואלי = offset עולה.
void main() {
  Future<TextEditingController> pumpField(WidgetTester tester,
      {String text = 'אבג דהו זחט'}) async {
    final controller = TextEditingController(text: text);
    final focusNode = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: RtlTextField(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    return controller;
  }

  Future<void> wordSelect(WidgetTester tester, LogicalKeyboardKey arrow) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(arrow);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  Future<void> charSelect(WidgetTester tester, LogicalKeyboardKey arrow) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(arrow);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  testWidgets('Ctrl+Shift+חץ שמאל בוחר מילה לכיוון הסוף (offset עולה)',
      (tester) async {
    final controller = await pumpField(tester);
    // קורסר בתחילת הטקסט (offset 0, הצד הימני).
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    // חץ שמאל ויזואלי → מילה קדימה ב-offset: "אבג" (0..3).
    await wordSelect(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 3);

    // עוד אחד → "אבג דהו" (0..7).
    await wordSelect(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.extentOffset, 7);
  });

  testWidgets('Ctrl+Shift+חץ ימין מצמצם מילה לכיוון ההתחלה (offset יורד)',
      (tester) async {
    final controller = await pumpField(tester);
    // בחירה "אבג דהו" (extent בקצה השמאלי, offset 7).
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
    await tester.pump();

    // חץ ימין ויזואלי → מילה אחורה ב-offset: extent 7 → 4.
    await wordSelect(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 4);
  });

  testWidgets('בחירת מילה עוצרת בפיסוק (לא רק ברווח)', (tester) async {
    // 'אבג, דהו' — offset של הפסיק הוא 3. גבול-מילה לפי רווח-בלבד היה בולע
    // את הפסיק (extent=4); הטיפול המובנה של Flutter עוצר במילה (extent=3).
    final controller = await pumpField(tester, text: 'אבג, דהו');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await wordSelect(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 3,
        reason: 'בחירת מילה צריכה לעצור לפני הפסיק, לא לבלוע אותו');
  });

  testWidgets('בחירת תו מכבדת אשכול-גרפמה (ניקוד אינו נחצה)', (tester) async {
    // 'אָב' = א + קמץ (ָ) + ב. אשכול-הגרפמה "אָ" משתרע על code units 0-1.
    // תזוזה גרפמה-מודעת מ-offset 0 קדימה צריכה לדלג את כל האשכול (→2), ולא
    // לעצור באמצע בין האות לניקוד (offset 1).
    final controller = await pumpField(tester, text: 'אָב');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    // חץ שמאל ויזואלי → קדימה ב-offset.
    await charSelect(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 2,
        reason: 'התזוזה חייבת לדלג על האות+ניקוד כיחידה אחת');
  });

  testWidgets('חץ ימין ב-offset 0 אינו קורס (אין אינדקס שלילי)',
      (tester) async {
    // ויזואלית-ימין מ-offset 0 = אחורה אל מעבר לתחילת הטקסט. אסור להעביר
    // אינדקס שלילי ל-CharacterBoundary; נשארים ב-0.
    final controller = await pumpField(tester, text: 'אבג');
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await charSelect(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.selection.extentOffset, 0);
  });
}
