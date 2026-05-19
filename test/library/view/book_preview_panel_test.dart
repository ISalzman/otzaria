// טסטים ל-[BookPreviewPanel] — מגנים על ההתנהגות הקריטית של הפאנל:
//
//  1. מצב ריק כשאין ספר נבחר.
//  2. ספר חיצוני — הכפתור "פתח בעיון" קורא ל-onOpenInReader(0).
//  3. PDF עם קובץ שלא קיים — מציג הודעת שגיאה ושומר על ה-toolbar.
//  4. ה-toolbar מכיל את שלושת הכפתורים עם ה-tooltips הנכונים.
//  5. לחיצה על "פתח בעיון" ב-toolbar קוראת ל-onOpenInReader.
//  6. לחיצה על כפתורי zoom ב-toolbar **לא** קוראת ל-onOpenInReader
//     (ההפרדה בין toolbar לתוכן שעליו חיים ה-double-tap).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/library/view/book_preview_panel.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/widgets/buttons/action_buttons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
  });

  Future<void> pumpPreview(
    WidgetTester tester, {
    Book? book,
    void Function(int index)? onOpenInReader,
  }) async {
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());
    addTearDown(() async {
      // לסגור את ה-bloc אחרי הפירוק של ה-widget
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await settingsBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: BlocProvider<SettingsBloc>.value(
            value: settingsBloc,
            child: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: BookPreviewPanel(
                  book: book,
                  onOpenInReader: onOpenInReader,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // pump לאתחול ה-state
    await tester.pump();
  }

  group('BookPreviewPanel', () {
    testWidgets('מציג מצב ריק כשאין ספר נבחר', (tester) async {
      await pumpPreview(tester, book: null);

      expect(find.text('בחר ספר לתצוגה מקדימה'), findsOneWidget);
    });

    testWidgets(
        'ExternalLibraryBook — כפתור "פתח בעיון" קורא ל-onOpenInReader(0)',
        (tester) async {
      int? receivedIndex;
      final book = ExternalLibraryBook(
        title: 'ספר חיצוני לדוגמה',
        id: 1,
        link: 'https://example.com/book',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (index) => receivedIndex = index,
      );

      // הכפתור מסוג RecommendedActionButton — מומש בפועל ע"י FilledButton.icon.
      // נוודא שגם כותרת הספר וגם הכפתור קיימים.
      expect(find.text('ספר חיצוני לדוגמה'), findsOneWidget);
      final openButton =
          find.widgetWithText(RecommendedActionButton, 'פתח בעיון');
      expect(openButton, findsOneWidget);

      await tester.tap(openButton);
      await tester.pump();

      expect(receivedIndex, 0);
    });

    testWidgets('PdfBook עם קובץ שאינו קיים מציג "הספר איננו קיים"',
        (tester) async {
      final book = PdfBook(
        title: 'ספר PDF שלא קיים',
        path:
            '/tmp/this/path/definitely/does/not/exist_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );

      await pumpPreview(tester, book: book);

      expect(find.text('הספר איננו קיים'), findsOneWidget);
    });

    testWidgets('PdfBook — ה-toolbar מכיל את שלושת ה-tooltips הנכונים',
        (tester) async {
      final book = PdfBook(
        title: 'PDF חסר',
        path: '/tmp/missing_pdf_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );

      await pumpPreview(tester, book: book);

      // ToolbarActionButton עוטף את הכפתור ב-Tooltip עם message שווה ל-tooltip.
      expect(
        find.byTooltip('הגדל טקסט'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('הקטן טקסט'),
        findsOneWidget,
      );
      expect(
        find.byTooltip('פתח בעיון (או לחץ פעמיים על הספר)'),
        findsOneWidget,
      );
    });

    testWidgets(
        'PdfBook — לחיצה על "פתח בעיון" ב-toolbar קוראת ל-onOpenInReader',
        (tester) async {
      int? receivedIndex;
      final book = PdfBook(
        title: 'PDF חסר',
        path: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (index) => receivedIndex = index,
      );

      final openButton = find.byTooltip('פתח בעיון (או לחץ פעמיים על הספר)');
      expect(openButton, findsOneWidget);

      // _pdfController.isReady=false (אין PDF אמיתי) — fallback ל-1.
      await tester.tap(openButton);
      await tester.pump();

      expect(receivedIndex, isNotNull,
          reason: 'הכפתור חייב להפעיל את ה-callback');
      expect(receivedIndex, 1, reason: 'fallback של עמוד 1 כאשר ה-PDF לא מוכן');
    });

    testWidgets(
        'PdfBook — לחיצה על כפתור zoom ב-toolbar לא קוראת ל-onOpenInReader',
        (tester) async {
      int? receivedIndex;
      final book = PdfBook(
        title: 'PDF חסר',
        path: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (index) => receivedIndex = index,
      );

      // tap on zoom-in
      await tester.tap(find.byTooltip('הגדל טקסט'));
      await tester.pump();
      // tap on zoom-out
      await tester.tap(find.byTooltip('הקטן טקסט'));
      await tester.pump();

      expect(receivedIndex, isNull, reason: 'כפתורי zoom אסור שיפתחו את הספר');
    });

    testWidgets('PdfBook — האייקונים בכפתורי zoom וב-"פתח בעיון" נכונים',
        (tester) async {
      final book = PdfBook(
        title: 'PDF חסר',
        path: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );

      await pumpPreview(tester, book: book);

      // לוודא שהתמונה הסמלית של כל אחד מהכפתורים אכן קיימת בעץ ה-widget.
      expect(find.byIcon(FluentIcons.zoom_in_24_regular), findsOneWidget);
      expect(find.byIcon(FluentIcons.zoom_out_24_regular), findsOneWidget);
      expect(find.byIcon(FluentIcons.open_24_regular), findsOneWidget);
    });

    testWidgets('TextBook — GestureDetector ייעודי וה-toolbar נמצאים לפי Key',
        (tester) async {
      // ה-TextBookBloc הפנימי ייפתח עם TextBookRepository אמיתי שינסה לקרוא
      // קובץ שלא קיים; זה ידחה את הטעינה ל-TextBookError. אנו רק בודקים
      // שהמבנה החיצוני (GestureDetector + Toolbar) נבנה נכון.
      final book = TextBook(
        title: 'ספר טקסט לבדיקה',
        filePath: '/tmp/missing_text_${DateTime.now().microsecondsSinceEpoch}',
      );

      await pumpPreview(tester, book: book);

      // finder ייעודי לפי Key — לא 'findsWidgets' מעורפל.
      expect(
        find.byKey(const Key('book_preview_panel_double_tap_area')),
        findsOneWidget,
        reason: 'GestureDetector ייעודי עם onDoubleTap חייב להיות בעץ',
      );
      expect(
        find.byKey(const Key('book_preview_panel_text_toolbar')),
        findsOneWidget,
        reason: 'ה-toolbar הייעודי ל-TextBook חייב להיות בעץ',
      );
    });

    testWidgets('TextBook — דאבל-טפ על אזור התוכן קורא ל-onOpenInReader',
        (tester) async {
      int? receivedIndex;
      var callCount = 0;
      final book = TextBook(
        title: 'ספר טקסט',
        filePath: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (index) {
          callCount++;
          receivedIndex = index;
        },
      );

      final doubleTapArea =
          find.byKey(const Key('book_preview_panel_double_tap_area'));
      expect(doubleTapArea, findsOneWidget);

      // דאבל-טפ אמיתי — שני gestures רצופים בתוך kDoubleTapTimeout (300ms).
      final position = tester.getCenter(doubleTapArea);
      final g1 = await tester.startGesture(position);
      await g1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g2 = await tester.startGesture(position);
      await g2.up();
      // מאפשרים לכל ה-timers של ה-recognizer להסתיים (kDoubleTapTimeout=300ms).
      await tester.pump(const Duration(milliseconds: 350));

      expect(callCount, 1, reason: 'דאבל-טפ אמור להפעיל את ה-callback פעם אחת');
      expect(receivedIndex, 0, reason: 'ה-tab החדש נוצר עם index=0');
    });

    testWidgets(
        'TextBook — שתי לחיצות מהירות על כפתור zoom ב-toolbar לא קוראות ל-onOpenInReader',
        (tester) async {
      var callCount = 0;
      final book = TextBook(
        title: 'ספר טקסט',
        filePath: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (_) => callCount++,
      );

      // למקד את ה-finder ל-zoom button בתוך ה-toolbar הייעודי בלבד.
      final toolbar = find.byKey(const Key('book_preview_panel_text_toolbar'));
      final zoomInInToolbar = find.descendant(
        of: toolbar,
        matching: find.byTooltip('הגדל טקסט'),
      );
      expect(zoomInInToolbar, findsOneWidget);

      final position = tester.getCenter(zoomInInToolbar);
      final g1 = await tester.startGesture(position);
      await g1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g2 = await tester.startGesture(position);
      await g2.up();
      await tester.pump();

      expect(
        callCount,
        0,
        reason: 'שתי לחיצות על כפתור zoom ב-toolbar אסור שיפתחו את הספר',
      );
    });

    testWidgets(
        'TextBook — לחיצה על "פתח בעיון" ב-toolbar קוראת ל-onOpenInReader',
        (tester) async {
      int? receivedIndex;
      final book = TextBook(
        title: 'ספר טקסט',
        filePath: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (index) => receivedIndex = index,
      );

      // finder ייעודי דרך ה-toolbar שלנו.
      final toolbar = find.byKey(const Key('book_preview_panel_text_toolbar'));
      final openInToolbar = find.descendant(
        of: toolbar,
        matching: find.byTooltip('פתח בעיון (או לחץ פעמיים על הספר)'),
      );
      expect(openInToolbar, findsOneWidget);

      await tester.tap(openInToolbar);
      await tester.pump();

      // ה-tab החדש נוצר עם index=0 (ראה _createNewTab).
      expect(receivedIndex, 0);
    });

    testWidgets(
        'PdfBook — שתי לחיצות מהירות על כפתור zoom ב-toolbar לא קוראות ל-onOpenInReader',
        (tester) async {
      var callCount = 0;
      final book = PdfBook(
        title: 'PDF חסר',
        path: '/tmp/missing_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );

      await pumpPreview(
        tester,
        book: book,
        onOpenInReader: (_) => callCount++,
      );

      final zoomIn = find.byTooltip('הגדל טקסט');
      expect(zoomIn, findsOneWidget);

      final position = tester.getCenter(zoomIn);
      final g1 = await tester.startGesture(position);
      await g1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g2 = await tester.startGesture(position);
      await g2.up();
      await tester.pump();

      expect(
        callCount,
        0,
        reason: 'דאבל-קליק על כפתור zoom ב-toolbar אסור שיפתח את הספר',
      );
    });
  });
}

// ── Fakes / helpers ─────────────────────────────────────────────────────────

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryCacheProvider extends CacheProvider {
  final Map<String, Object?> _values = {};

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Set getKeys() => _values.keys.toSet();

  @override
  bool? getBool(String key, {bool? defaultValue}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  double? getDouble(String key, {double? defaultValue}) =>
      _values[key] as double? ?? defaultValue;

  @override
  int? getInt(String key, {int? defaultValue}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key, {String? defaultValue}) =>
      _values[key] as String? ?? defaultValue;

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value is T) return value;
    return defaultValue;
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> removeAll() async {
    _values.clear();
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String? value) async {
    _values[key] = value;
  }
}
