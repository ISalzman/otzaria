# מדריך מפתח: הוספת פריטים לסיור המודרך

מסמך זה מיועד למי שרוצה להוסיף, לשנות או לחבר שלבים חדשים לסיור המודרך באוצריה.

## מבנה הקבצים

הסיור בנוי מכמה שכבות:

- `lib/tour/models/tour_step.dart` - הגדרת `TourStep`, אזורי spotlight ופעולות מעבר.
- `lib/tour/models/tour_steps.dart` - רשימת השלבים, הטקסטים והסדר.
- `lib/tour/bloc/tour_cubit.dart` - התחלה, מעבר שלבים, דילוג, סיום ו-autoplay.
- `lib/tour/tour_target_keys.dart` - מזהי `GlobalKey` לאלמנטים שרוצים לסמן בחלון השקוף.
- `lib/tour/view/tour_overlay_screen.dart` - ציור ה-overlay, מיקום הכרטיס ופתרון target rects.
- `lib/navigation/main_window_screen.dart` - ביצוע פעולות לפני שלב: ניווט למסך, פתיחת דיאלוג, פתיחת תפריט וכו'.

## סוגי שלבים

יש שני סוגים עיקריים:

1. שלב הסבר כללי במרכז המסך:

```dart
const TourStep(
  id: 'welcome',
  title: 'כותרת',
  body: 'טקסט הסבר קצר',
  area: TourSpotlightArea.center,
  isDialog: true,
)
```

2. שלב שמסמן אזור במסך:

```dart
const TourStep(
  id: 'library_search',
  title: 'חיפוש מהיר בספרייה',
  body: 'הקלד כאן שם ספר, מחבר או נושא.',
  area: TourSpotlightArea.librarySearch,
  action: TourStepAction.openLibrary,
)
```

`id` חייב להיות יציב וייחודי. הוא משמש למעבר בין שלבים, בדיקות, resolver-ים, ונקודות טיפול מיוחדות.

## הוספת שלב חדש

1. הוסף ערך ל-`TourSpotlightArea` אם צריך אזור חדש ב-`tour_step.dart`.
2. הוסף ערך ל-`TourStepAction` אם צריך פעולה לפני הצגת השלב.
3. הוסף את ה-`TourStep` במקום המתאים ב-`TourSteps.build`.
4. אם יש פעולה חדשה, טפל בה ב-`_handleTourStepChanged` ב-`main_window_screen.dart`.
5. אם צריך spotlight מדויק, הוסף `GlobalKey` או resolver.
6. עדכן או הוסף בדיקות ב-`test/tour/tour_cubit_test.dart`.

דוגמה:

```dart
const TourStep(
  id: 'my_new_button',
  title: 'פעולה חדשה',
  body: 'כאן מסבירים מה הכפתור עושה.',
  area: TourSpotlightArea.myNewButton,
  action: TourStepAction.openRelevantScreen,
)
```

## סימון לחצן או widget בחלון השקוף

כאשר רוצים שה-spotlight ייצמד ל-widget אמיתי, משתמשים ב-`GlobalKey`.

### 1. הוספת key

בדרך כלל מוסיפים ל-`lib/tour/tour_target_keys.dart`:

```dart
final GlobalKey tourMyButtonTargetKey = GlobalKey(
  debugLabel: 'tour_my_button_target',
);
```

אם היעד נמצא במסך שיכולים להיות ממנו כמה מופעים במקביל, למשל קורא טקסט או PDF, לא מצמידים key גלובלי לכל המופעים. מוסיפים פרמטר כמו `enableTourTargets`, ומצמידים את ה-key רק למופע הפעיל:

```dart
IconButton(
  key: widget.enableTourTargets ? tourMyButtonTargetKey : null,
  icon: const Icon(FluentIcons.search_24_regular),
  onPressed: _handleSearch,
)
```

זה מונע שגיאת `Duplicate GlobalKey` כשפתוחים כמה טאבים.

### 2. הצמדת key ל-widget

אם ה-widget לא מקבל `key` ישירות, עטוף אותו ב-`KeyedSubtree`:

```dart
KeyedSubtree(
  key: tourMyPanelTargetKey,
  child: MyPanel(...),
)
```

### 3. חיבור ה-key ל-resolver

ב-`main_window_screen.dart`, הוסף טיפול ב-`_exactTourTargetRect`:

```dart
case 'my_new_button':
  return _rectForGlobalKey(tourMyButtonTargetKey);
```

אם יש כמה אזורים שצריך להאיר יחד, השתמש ב-`_resolveTourTargetRects`:

```dart
if (step.id == 'my_complex_step') {
  return [
    if (_rectForGlobalKey(tourFirstTargetKey) case final rect?) rect,
    if (_rectForGlobalKey(tourSecondTargetKey) case final rect?) rect,
  ];
}
```

## אזור משוער ללא key

אם אין widget יציב להצמד אליו, אפשר להשתמש באזור מחושב ב-`tourTargetRectFor` בתוך `tour_overlay_screen.dart`:

```dart
case TourSpotlightArea.myArea:
  rect = Rect.fromLTWH(110, 80, width - 220, 78);
```

העדף `GlobalKey` כשהיעד קיים בעץ ה-widgets. אזור מחושב מתאים רק לאזורי layout יציבים.

## פעולות לפני הצגת שלב

`TourStepAction` מגדיר מה צריך לקרות לפני שהשלב מוצג: מעבר למסך, פתיחת דיאלוג, פתיחת תפריט, בחירת טאב וכו'.

דוגמה ב-`_handleTourStepChanged`:

```dart
case TourStepAction.openSettings:
  context.read<NavigationBloc>().add(
        const NavigateToScreen(Screen.settings),
      );
```

אם הפעולה דורשת שהמסך ייבנה לפני שמחפשים את היעד, השתמש ב-post-frame callback:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  _scheduleTourTargetRebuilds(remainingFrames: 4);
});
```

`_scheduleTourTargetRebuilds` חשוב אחרי פתיחת דיאלוגים, תפריטים, טאבים או scroll, כי ה-rect זמין רק אחרי שה-widget כבר בעץ.

## פתיחת תפריטים ופריטי תפריט

לתפריטים יש שני דפוסים:

- `ResponsiveActionBar` מקבל `overflowButtonKey` ו-`menuItemKeysByTooltip`.
- `AppContextMenuRegion` מקבל `menuItemKeysByLabel`.

דוגמה:

```dart
ResponsiveActionBar(
  overflowButtonKey: tourOverflowTargetKey,
  menuItemKeysByTooltip: {
    'חיפוש': tourOverflowSearchTargetKey,
    'הדפסה': tourOverflowPrintTargetKey,
  },
  actions: actions,
  alwaysInMenu: menuActions,
  maxVisibleButtons: maxButtons,
)
```

אם צריך לפתוח תפריט אוטומטית לפני השלב, עשה זאת ב-`main_window_screen.dart`, ואז הבא את overlay הסיור קדימה:

```dart
state?.showMenu();
_bringTourOverlayToFront();
_scheduleTourTargetRebuilds(remainingFrames: 3);
```

## מסך הסבר ללא spotlight

למסך הסבר במרכז השתמש ב-`isDialog: true` וב-`TourSpotlightArea.center`.
שלבים כאלה אינם נספרים בנקודות ההתקדמות (`progressSteps`) אם הם מוגדרים כדיאלוג.

```dart
TourStep(
  id: 'restart_welcome',
  title: 'הסיור המודרך',
  body: 'לחץ "אני מוכן" כשתהיה מוכן להתחיל.',
  area: TourSpotlightArea.center,
  isDialog: true,
)
```

## סיור מלא מול סיור מקוצר

`TourSteps.build` מקבל `libraryLoaded`.
שלבים שדורשים ספרייה טעונה צריכים להופיע רק בתוך:

```dart
if (libraryLoaded) {
  steps.addAll([
    // שלבים שתלויים בספרייה
  ]);
}
```

אם מוסיפים שלב שמותר גם בלי ספרייה, הוסף אותו אחרי הבלוק הזה.
אם מוסיפים שלב שקשור למסך הספרייה הריקה, הוסף אותו לענף `!libraryLoaded`.

## בדיקות חובה

אחרי שינוי בסיור:

```bash
flutter analyze
flutter test test\tour\tour_cubit_test.dart
dart format <files you changed>
```

הוסף בדיקה כאשר:

- מספר השלבים משתנה.
- נוסף `TourSpotlightArea` עם חישוב `Rect`.
- משתנה לוגיקת `tour_status`.
- נוסף behavior כמו autoplay, דילוג, restart או מעבר ידני.

## רשימת בדיקה לפני קומיט

- `id` חדש הוא ייחודי ויציב.
- כל טקסט עברי ב-widget חדש כולל `textDirection: TextDirection.rtl`.
- icons חדשים הם רק מ-`fluentui_system_icons`.
- לא הוצמד `GlobalKey` גלובלי לכמה מופעים במקביל.
- אם היעד מופיע רק אחרי ניווט/תפריט/דיאלוג, יש post-frame ו-`_scheduleTourTargetRebuilds`.
- שלבים שתלויים בספרייה נמצאים רק במסלול `libraryLoaded`.
- `flutter analyze` ובדיקות הסיור עוברים.
