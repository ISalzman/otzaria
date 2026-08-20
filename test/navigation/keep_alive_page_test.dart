import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/navigation/view/main_window_screen.dart'
    show KeepAlivePage;

/// עמוד סטטפולי שמדווח כמה פעמים אותחל — אתחול שני = ה-State הקודם נזרק.
class _LifecycleProbe extends StatefulWidget {
  final List<String> initLog;
  final String name;

  const _LifecycleProbe({required this.initLog, required this.name});

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.initLog.add(widget.name);
  }

  @override
  Widget build(BuildContext context) => Text('probe-${widget.name}');
}

/// הרנס שמדמה את מסך הראשי: PageView שאינו נגלל ידנית, בתוך תיבה שמידותיה
/// משתנות — פריים של 0x0 מדמה מזעור חלון ב-Windows (view בגודל אפס).
class _Harness extends StatefulWidget {
  final List<Widget> pages;

  const _Harness({super.key, required this.pages});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Size size = const Size(400, 400);
  final controller = PageController(initialPage: 1);

  void resizeTo(Size newSize) => setState(() => size = newSize);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Center(
        child: SizedBox.fromSize(
          size: size,
          child: PageView(
            controller: controller,
            physics: const NeverScrollableScrollPhysics(),
            children: widget.pages,
          ),
        ),
      ),
    );
  }
}

void main() {
  group(
    'KeepAlivePage — עמוד PageView שורד פריים שבו ה-viewport מאבד אותו',
    () {
      testWidgets('בלי KeepAlivePage העמוד הפעיל נזרק בפריים 0x0 (בקרה)', (
        tester,
      ) async {
        final initLog = <String>[];
        final harnessKey = GlobalKey<_HarnessState>();
        await tester.pumpWidget(
          _Harness(
            key: harnessKey,
            pages: [
              _LifecycleProbe(initLog: initLog, name: 'library'),
              _LifecycleProbe(initLog: initLog, name: 'reading'),
            ],
          ),
        );
        expect(initLog, ['reading']);

        harnessKey.currentState!.resizeTo(Size.zero);
        await tester.pump();
        harnessKey.currentState!.resizeTo(const Size(400, 400));
        await tester.pump();

        // הבקרה מתעדת את מנגנון הבאג: אתחול שני = ה-State הקודם אבד.
        // (בפריים ה-0x0 ה-viewport בונה את עמוד 0, לכן 'library' מופיע גם הוא.)
        expect(initLog.where((n) => n == 'reading'), hasLength(2));
      });

      testWidgets('עם KeepAlivePage ה-State שורד פריים 0x0 ואינו מאותחל מחדש', (
        tester,
      ) async {
        final initLog = <String>[];
        final harnessKey = GlobalKey<_HarnessState>();
        await tester.pumpWidget(
          _Harness(
            key: harnessKey,
            pages: [
              KeepAlivePage(
                key: const ValueKey('page-library'),
                child: _LifecycleProbe(initLog: initLog, name: 'library'),
              ),
              KeepAlivePage(
                key: const ValueKey('page-reading'),
                child: _LifecycleProbe(initLog: initLog, name: 'reading'),
              ),
            ],
          ),
        );
        expect(initLog, ['reading']);

        harnessKey.currentState!.resizeTo(Size.zero);
        await tester.pump();
        harnessKey.currentState!.resizeTo(const Size(400, 400));
        await tester.pump();

        expect(initLog.where((n) => n == 'reading'), hasLength(1));
        expect(find.text('probe-reading'), findsOneWidget);
      });
    },
  );
}
