import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/widgets/layout/adaptive_side_pane.dart';
import 'package:otzaria/widgets/layout/floating_panel.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/widgets/navigation/nav_side_panel.dart';
import '../helpers/memory_settings_cache.dart';

Widget wrap(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: SizedBox(width: 1200, height: 700, child: child),
    ),
  ),
);

// ─── helper ───────────────────────────────────────────────────────────────────

class _NavPanelTabHeaderHost extends StatefulWidget {
  final int initialIndex;
  final bool showPin;
  final bool isPinned;

  const _NavPanelTabHeaderHost({
    this.initialIndex = 0,
    this.showPin = false,
    this.isPinned = false,
  });

  @override
  State<_NavPanelTabHeaderHost> createState() => _NavPanelTabHeaderHostState();
}

class _NavPanelTabHeaderHostState extends State<_NavPanelTabHeaderHost>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavPanelTabHeader(
      controller: _controller,
      tabs: const [
        (
          icon: FluentIcons.link_24_regular,
          iconFilled: FluentIcons.link_24_filled,
          label: 'קישורים',
        ),
        (
          icon: FluentIcons.note_24_regular,
          iconFilled: FluentIcons.note_24_filled,
          label: 'הערות',
        ),
      ],
      isPinned: widget.isPinned,
      onTogglePin: widget.showPin ? () {} : null,
    );
  }
}

Widget _wrap({
  int initialIndex = 0,
  bool showPin = false,
  bool isPinned = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: _NavPanelTabHeaderHost(
        initialIndex: initialIndex,
        showPin: showPin,
        isPinned: isPinned,
      ),
    ),
  );
}

// ─── tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  testWidgets('NavSidePanel כופה את עיצוב חלונית הניווט על AdaptiveSidePane', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            capturedContext = context;
            return NavSidePanel(
              isOpen: true,
              paneWidth: 300,
              minMainContentWidth: 420,
              onClose: () {},
              mainContent: const SizedBox.expand(),
              paneContent: const SizedBox.expand(),
              autoHandleResponsiveVisibility: false,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pane = tester.widget<AdaptiveSidePane>(find.byType(AdaptiveSidePane));
    expect(pane.attachToTopEdge, isTrue);
    expect(pane.paneColor, AppSurfaces.topBarBackground(capturedContext));
    expect(pane.scrollbarTopMargin, 0);
    // מעטפת צמודה — לא חלונית צפה.
    expect(find.byType(FloatingPanel), findsNothing);
  });

  testWidgets('NavPanelToggleButton מחליף אייקון ותיאור לפי מצב החלונית', (
    tester,
  ) async {
    var isOpen = true;

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => NavPanelToggleButton(
            isOpen: isOpen,
            onToggle: () => setState(() => isOpen = !isOpen),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byIcon(FluentIcons.panel_right_contract_24_regular),
      findsOneWidget,
    );
    expect(find.byTooltip('הסתר ניווט'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(FluentIcons.panel_right_24_regular), findsOneWidget);
    expect(find.byTooltip('הצג ניווט'), findsOneWidget);
    expect(isOpen, isFalse);
  });

  group('NavPanelTabHeader - אייקונים', () {
    testWidgets('מציג אייקון filled לטאב הנבחר (index=0)', (tester) async {
      await tester.pumpWidget(_wrap(initialIndex: 0));
      await tester.pump();

      expect(find.byIcon(FluentIcons.link_24_filled), findsOneWidget);
      expect(find.byIcon(FluentIcons.link_24_regular), findsNothing);
    });

    testWidgets('מציג אייקון רגיל לטאב שאינו נבחר', (tester) async {
      await tester.pumpWidget(_wrap(initialIndex: 0));
      await tester.pump();

      // הטאב השני (הערות) אינו נבחר → אייקון רגיל
      expect(find.byIcon(FluentIcons.note_24_regular), findsOneWidget);
      expect(find.byIcon(FluentIcons.note_24_filled), findsNothing);
    });

    testWidgets('אחרי מעבר טאב — האייקון הנבחר מתעדכן', (tester) async {
      await tester.pumpWidget(_wrap(initialIndex: 0));
      await tester.pump();

      // לפני: קישורים נבחר
      expect(find.byIcon(FluentIcons.link_24_filled), findsOneWidget);

      // לוחצים על "הערות"
      await tester.tap(find.text('הערות'));
      await tester.pump();

      // אחרי: הערות נבחר, קישורים רגיל
      expect(find.byIcon(FluentIcons.note_24_filled), findsOneWidget);
      expect(find.byIcon(FluentIcons.link_24_regular), findsOneWidget);
    });

    testWidgets('initialIndex=1 — הטאב השני מקבל אייקון filled', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(initialIndex: 1));
      await tester.pump();

      expect(find.byIcon(FluentIcons.note_24_filled), findsOneWidget);
      expect(find.byIcon(FluentIcons.link_24_regular), findsOneWidget);
    });
  });

  group('NavPanelTabHeader - כפתור pin', () {
    testWidgets('onTogglePin=null — כפתור pin לא מוצג', (tester) async {
      await tester.pumpWidget(_wrap(showPin: false));
      await tester.pump();

      expect(find.byType(NavPanelPinButton), findsNothing);
    });

    testWidgets('onTogglePin מסופק — כפתור pin מוצג', (tester) async {
      await tester.pumpWidget(_wrap(showPin: true));
      await tester.pump();

      expect(find.byType(NavPanelPinButton), findsOneWidget);
    });

    testWidgets('isPinned=true — אייקון pin filled מוצג', (tester) async {
      await tester.pumpWidget(_wrap(showPin: true, isPinned: true));
      await tester.pump();

      expect(find.byIcon(FluentIcons.pin_24_filled), findsOneWidget);
    });

    testWidgets('isPinned=false — אייקון pin regular מוצג', (tester) async {
      await tester.pumpWidget(_wrap(showPin: true, isPinned: false));
      await tester.pump();

      // globalPin=false (Settings לא מוגדר), isPinned=false
      expect(find.byIcon(FluentIcons.pin_24_regular), findsOneWidget);
    });
  });
}
