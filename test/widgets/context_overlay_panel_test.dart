import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/layout/context_overlay_panel.dart';

class _OverlayHarness extends StatefulWidget {
  final bool deferChildBuildOnOpen;
  final bool preserveChildStateOnClose;

  const _OverlayHarness({
    super.key,
    required this.deferChildBuildOnOpen,
    required this.preserveChildStateOnClose,
  });

  @override
  State<_OverlayHarness> createState() => _OverlayHarnessState();
}

class _OverlayHarnessState extends State<_OverlayHarness> {
  bool _isOpen = false;

  void open() {
    setState(() {
      _isOpen = true;
    });
  }

  void close() {
    setState(() {
      _isOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(),
              ContextOverlayPanel(
                isOpen: _isOpen,
                onClose: close,
                deferChildBuildOnOpen: widget.deferChildBuildOnOpen,
                preserveChildStateOnClose: widget.preserveChildStateOnClose,
                child: const Text(
                  'תוכן הפאנל',
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('דוחה את בניית התוכן לפריים הבא כאשר deferChildBuildOnOpen פעיל',
      (tester) async {
    final key = GlobalKey<_OverlayHarnessState>();

    await tester.pumpWidget(
      _OverlayHarness(
        key: key,
        deferChildBuildOnOpen: true,
        preserveChildStateOnClose: false,
      ),
    );

    key.currentState!.open();
    await tester.pump();

    expect(find.text('תוכן הפאנל'), findsNothing);

    await tester.pump();

    expect(find.text('תוכן הפאנל'), findsOneWidget);
  });

  testWidgets('שומר את התוכן אחרי סגירה כאשר preserveChildStateOnClose פעיל',
      (tester) async {
    final key = GlobalKey<_OverlayHarnessState>();

    await tester.pumpWidget(
      _OverlayHarness(
        key: key,
        deferChildBuildOnOpen: true,
        preserveChildStateOnClose: true,
      ),
    );

    key.currentState!.open();
    await tester.pump();
    await tester.pump();

    expect(find.text('תוכן הפאנל'), findsOneWidget);

    key.currentState!.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('תוכן הפאנל'), findsOneWidget);
  });
}
