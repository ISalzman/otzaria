import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/navigation/app_top_bar.dart';
import 'package:otzaria/widgets/navigation/nav_panel_search.dart';
import 'package:otzaria/widgets/navigation/nav_side_panel.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';
import '../helpers/memory_settings_cache.dart';

/// חלונית מדומה: סרגל בסרגל העליון + שתי לשוניות שמפרסמות פעולות חיפוש.
class _Host extends StatefulWidget {
  final bool isOpen;
  final bool showPin;
  final bool isPinned;

  const _Host({
    this.isOpen = true,
    this.showPin = false,
    this.isPinned = false,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  final NavPanelSearchHost host = NavPanelSearchHost();
  final navController = TextEditingController();
  final searchController = TextEditingController();
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    tabs.addListener(() => host.activeTab = tabs.index);
  }

  @override
  void dispose() {
    tabs.dispose();
    host.dispose();
    navController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "הסרגל העליון": הסרגל ואחריו אייקון הפתיחה.
        SizedBox(
          height: 56,
          child: Row(
            children: [
              NavPanelSearchBar(
                host: host,
                isOpen: widget.isOpen,
                paneWidth: 300,
                isPinned: widget.isPinned,
                onTogglePin: widget.showPin ? () {} : null,
              ),
              // אייקון הפתיחה/סגירה — מחוץ לרוחב הסרגל.
              const Icon(Icons.menu),
            ],
          ),
        ),
        Expanded(
          child: NavPanelSearchScope(
            host: host,
            child: Column(
              children: [
                TabBar(
                  controller: tabs,
                  tabs: const [
                    Tab(text: 'ניווט'),
                    Tab(text: 'חיפוש'),
                    Tab(text: 'דפים'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabs,
                    children: [
                      NavPanelSearchSlot(
                        index: 0,
                        child: NavPanelSearchPublisher(
                          delegate: NavPanelSearchDelegate(
                            controller: navController,
                            hintText: 'איתור כותרת...',
                          ),
                          child: const Text('תוכן ניווט'),
                        ),
                      ),
                      NavPanelSearchSlot(
                        index: 1,
                        child: NavPanelSearchPublisher(
                          delegate: NavPanelSearchDelegate(
                            controller: searchController,
                            hintText: 'חיפוש בספר...',
                          ),
                          child: const Text('תוכן חיפוש'),
                        ),
                      ),
                      // לשונית בלי פעולת חיפוש.
                      const NavPanelSearchSlot(
                        index: 2,
                        child: Text('תמונות עמודים'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget wrap(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: SizedBox(width: 1200, height: 700, child: child),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // NavPanelPinButton קורא את הגדרת הנעיצה הגלובלית.
  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  testWidgets('הסרגל מציג את פעולת הלשונית הפעילה ומתחלף במעבר לשונית', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pumpAndSettle();

    // לשונית 0 — שדה אחד בלבד, בסרגל שמעל החלונית.
    expect(find.byType(OtzariaSearchField), findsOneWidget);
    expect(find.text('איתור כותרת...'), findsOneWidget);

    await tester.tap(find.text('חיפוש'));
    await tester.pumpAndSettle();

    // הפעולה התחלפה לזו של הלשונית הנבחרת — והסרגל נשאר יחיד.
    expect(find.byType(OtzariaSearchField), findsOneWidget);
    expect(find.text('חיפוש בספר...'), findsOneWidget);
    expect(find.text('איתור כותרת...'), findsNothing);
  });

  testWidgets('חלונית סגורה — הסרגל מכווץ לרוחב 0', (tester) async {
    await tester.pumpWidget(wrap(const _Host(isOpen: false)));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(NavPanelSearchBar)).width, 0);
  });

  testWidgets('חלונית פתוחה — הסרגל ברוחב החלונית (פחות ריווח הסרגל העליון)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pumpAndSettle();

    // הסרגל העליון מרווח את פריטיו מהדופן, ולכן הרוחב מפצה עליו כדי
    // שהשפה הפנימית תתיישר לשפת החלונית.
    expect(
      tester.getSize(find.byType(NavPanelSearchBar)).width,
      300 - AppTopBar.horizontalPadding(false),
    );
  });

  testWidgets('מחוץ לחלונית ניווט אין הגבהה — הלשונית מציירת שדה מקומי', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            final delegate = NavPanelSearchDelegate(
              controller: controller,
              hintText: 'איתור כותרת...',
            );
            return Column(
              children: [
                if (!NavPanelSearch.isHoisted(context))
                  NavPanelLocalSearchField(delegate: delegate),
                const Text('תוכן'),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OtzariaSearchField), findsOneWidget);
  });

  testWidgets('לשונית בלי חיפוש — הסרגל נשאר מוצג ומושבת', (tester) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pumpAndSettle();

    final fieldBefore = tester.widget<OtzariaSearchField>(
      find.byType(OtzariaSearchField),
    );
    expect(fieldBefore.enabled, isTrue);

    await tester.tap(find.text('דפים'));
    await tester.pumpAndSettle();

    // הסרגל לא נעלם ולא התכווץ — רק התוכן שבתוכו הושבת.
    expect(
      tester.getSize(find.byType(NavPanelSearchBar)).width,
      300 - AppTopBar.horizontalPadding(false),
    );
    final field = tester.widget<OtzariaSearchField>(
      find.byType(OtzariaSearchField),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('מעבר לשונית אינו בונה מחדש את השדה — אותו element נשמר', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pumpAndSettle();

    final elementBefore = tester.element(find.byType(OtzariaSearchField));

    await tester.tap(find.text('חיפוש'));
    await tester.pumpAndSettle();

    expect(
      tester.element(find.byType(OtzariaSearchField)),
      same(elementBefore),
      reason: 'הסרגל נשאר מורכב; רק התוכן הפנימי שלו מתחלף',
    );
  });

  testWidgets('כפתור הנעיצה יושב בסרגל, בתוך רוחב החלונית', (tester) async {
    await tester.pumpWidget(
      wrap(const _Host(showPin: true, isPinned: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavPanelPinButton), findsOneWidget);
    expect(find.byIcon(FluentIcons.pin_24_filled), findsOneWidget);

    final bar = tester.getRect(find.byType(NavPanelSearchBar));
    final pin = tester.getRect(find.byType(NavPanelPinButton));
    expect(bar.contains(pin.center), isTrue);

    // אייקון הפתיחה נשאר מחוץ לסרגל.
    final toggle = tester.getRect(find.byIcon(Icons.menu));
    expect(bar.contains(toggle.center), isFalse);
  });

  testWidgets('onTogglePin=null — אין כפתור נעיצה', (tester) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pumpAndSettle();

    expect(find.byType(NavPanelPinButton), findsNothing);
  });

  testWidgets('בלי נעיצה: השדה מתיישר לשוליים של תוכן החלונית משני הצדדים', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const _Host()));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(NavPanelSearchBar));
    final field = tester.getRect(find.byType(OtzariaSearchField));
    expect(bar.right - field.right, greaterThan(0));
    expect(field.left - bar.left, greaterThan(0));
  });

  testWidgets('עם נעיצה: רווח בין השדה לכפתור, והכפתור גולש אל השוליים', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const _Host(showPin: true)));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(NavPanelSearchBar));
    final field = tester.getRect(find.byType(OtzariaSearchField));
    final pin = tester.getRect(find.byType(NavPanelPinButton));

    // הכפתור אינו נצמד לשדה...
    expect(field.left - pin.right, greaterThan(0));
    // ...וגולש אל השוליים הפנימיים, כדי לא להתרחק מאייקון הסגירה.
    expect(pin.left, bar.left);
    // השדה מוותר על השוליים החיצוניים לטובת הרווח הזה.
    expect(bar.right, field.right);
  });
}
