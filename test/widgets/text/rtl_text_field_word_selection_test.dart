import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

/// בודק בחירה ברמת מילה (Ctrl/Alt+Shift+חץ) ב-[RtlTextField] בכיווניות RTL:
/// בעברית offset 0 מימין; חץ שמאל ויזואלי = offset עולה.
void main() {
  Future<TextEditingController> pumpField(WidgetTester tester) async {
    final controller = TextEditingController(text: 'אבג דהו זחט');
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
    controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 7);
    await tester.pump();

    // חץ ימין ויזואלי → מילה אחורה ב-offset: extent 7 → 4.
    await wordSelect(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 4);
  });
}
