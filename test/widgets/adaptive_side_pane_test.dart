import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/adaptive_side_pane.dart';
import 'package:otzaria/widgets/resizable_drag_handle.dart';

void main() {
  testWidgets('AdaptiveSidePane calls onPaneResizeEnd after dragging',
      (tester) async {
    double paneWidth = 300;
    var resizeEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SizedBox(
                  width: 1200,
                  height: 700,
                  child: AdaptiveSidePane(
                    isOpen: true,
                    alignment: AlignmentDirectional.centerEnd,
                    paneWidth: paneWidth,
                    minMainContentWidth: 420,
                    onClose: () {},
                    mainContent: const SizedBox.expand(),
                    paneContent: const Text('pane'),
                    isResizable: true,
                    onPaneWidthChanged: (nextWidth) {
                      setState(() {
                        paneWidth = nextWidth;
                      });
                    },
                    onPaneResizeEnd: () {
                      resizeEnded = true;
                    },
                    autoHandleResponsiveVisibility: false,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ResizableDragHandle), const Offset(-40, 0));
    await tester.pumpAndSettle();

    expect(resizeEnded, isTrue);
    expect(paneWidth, isNot(300));
  });
}
