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

אם הwidget הוא singleton (מופיע פעם אחת בלבד בממשק, כמו כפתורי title bar), אפשר להצמיד את ה-key ישירות ללא תנאי:

```dart
IconButton(
  key: tourTitleBarHistoryButtonTargetKey,
  icon: const Icon(FluentIcons.history_24_regular),
  ...
)
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

ב-`main_window_screen.dart` יש שני מנגנוני resolver:

**resolver לפי `step.area`** — מטפל ב-area שלם, עובד עם `switch`:

```dart
case 'my_new_button':
  return _rectForGlobalKey(tourMyButtonTargetKey);
```

**resolver לפי `step.id`** — override ספציפי לשלב, בדיקת `if` לפני ה-`switch`. משמש כשצריך התנהגות מיוחדת שלא מתאימה לכל שלבי ה-area:

```dart
if (step.id == 'my_special_step') {
  return _rectForGlobalKey(tourSpecialTargetKey);
}
// ... ה-switch על step.area ממשיך אחריו
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

**כלל האצבע:** אם כל השלבים ב-area מאירים את אותם widgets — השתמש ב-resolver לפי `area`. אם רק שלב אחד דורש אזורים שונים — הוסף override לפי `step.id` לפני ה-`switch`.

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

### פתיחת תת-תפריט אוטומטית

אם השלב מצביע על פריט בתת-תפריט (submenu), פתח גם אותו אחרי שהתפריט הראשי נפתח — בתוך post-frame נוסף:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  (tourTabSideBySideMenuItemTargetKey.currentState as dynamic)
      ?.openSubmenu(() {
    if (!mounted) return;
    _scheduleTourTargetRebuilds(remainingFrames: 4);
  });
});
```

הסדר חשוב: תפריט ראשי → `_bringTourOverlayToFront` → `_scheduleTourTargetRebuilds` → פתיחת תת-תפריט → `_scheduleTourTargetRebuilds` שוב. כל שלב בpost-frame נפרד, כי כל אחד דורש שה-widget הקודם כבר בעץ.

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

## טיפים חיים (Live Tips)

מערכת הטיפים החיים מציגה הצעות קצרות ומבוססות-הקשר **מחוץ לסיור המודרך הרגיל** — כלומר, גם לאחר שסיים המשתמש את הסיור, ואפילו כשהסיור אינו פעיל. הטיפים מופיעים ככרטיס צף (`LiveTipCard`) מעל הממשק, ומוסתרים עם לחיצה על "הבנתי" או X.

### קבצים רלוונטיים

| קובץ | תפקיד |
|------|--------|
| `lib/tour/models/live_tip.dart` | הגדרת `LiveTipId`, `TourInteractionType`, `TourInteraction`, `LiveTipSpec` ורשימת `liveTipSpecs` |
| `lib/tour/bloc/tour_cubit.dart` | לוגיקת הטיפות: `recordInteraction`, `_maybeShowLiveTip`, `_resolveNextLiveTip`, `dismissLiveTip` |
| `lib/tour/bloc/tour_state.dart` | שדות הסטייט: `activeLiveTipId`, `shownTips`, `resolvedTips` |
| `lib/tour/view/tour_overlay_screen.dart` | הצגת `_LiveTipOverlay` כשאין סיור פעיל אך יש טיפ פעיל |
| `lib/tour/widgets/live_tip_card.dart` | ה-widget של כרטיס הטיפ |

### מחזור חיים של טיפ

```
פעולת משתמש (tab change, text select, וכו')
        │
        ▼
tourCubit.recordInteraction(TourInteraction(...))
        │
        ├─ _rememberInteraction   → שמור ב-_recentInteractions (30 שניות אחרונות)
        ├─ _updateDerivedSignals  → עדכן מונים/דגלים פנימיים
        └─ _maybeShowLiveTip      → בדוק אם להציג טיפ

אם יש טיפ מתאים → emit(state.copyWith(activeLiveTipId: ...))
                        │
                        ▼
               TourOverlayScreen מציג _LiveTipOverlay

המשתמש לוחץ "הבנתי" → dismissLiveTip() → clearLiveTip: true
```

### הגדרת טיפ קיים — `LiveTipSpec`

כל טיפ מוגדר ב-`liveTipSpecs` ב-`live_tip.dart`:

```dart
LiveTipSpec(
  id: LiveTipId.sideBySideSuggestion,
  area: TourSpotlightArea.tabs,
  title: 'השוואה בין שני ספרים',
  description: 'נראה שאתה מדלג שוב ושוב בין אותם ספרים...',
),
```

- `id` — ערך מ-`LiveTipId`, ייחודי לכל טיפ.
- `area` — `TourSpotlightArea` שמגדיר היכן ממוקם הכרטיס על המסך.
- `title` / `description` — הטקסט שמוצג למשתמש.

### הוספת טיפ חדש — שלב אחר שלב

#### 1. הוסף ערך ל-`LiveTipId`

```dart
// lib/tour/models/live_tip.dart
enum LiveTipId {
  sideBySideSuggestion,
  dictionaryContextMenuHint,
  commentaryHint,
  myNewTip,  // ← הוסף כאן
}
```

#### 2. הוסף אירוע מתאים ל-`TourInteractionType` (אם נדרש)

```dart
enum TourInteractionType {
  currentTabChanged,
  openedTextBook,
  sideBySideEnabled,
  textSelected,
  dictionaryUsed,
  commentaryAvailable,
  commentaryUsed,
  myNewEvent,  // ← רק אם צריך אירוע חדש
}
```

#### 3. הוסף `LiveTipSpec` לרשימה

```dart
const List<LiveTipSpec> liveTipSpecs = [
  // ... טיפים קיימים ...
  LiveTipSpec(
    id: LiveTipId.myNewTip,
    area: TourSpotlightArea.reading,  // בחר אזור מתאים
    title: 'כותרת הטיפ',
    description: 'הסבר קצר ומועיל למשתמש.',
  ),
];
```

#### 4. עדכן את `_updateDerivedSignals` ב-`tour_cubit.dart`

```dart
case TourInteractionType.myNewEvent:
  // לדוגמה: סמן שמשתמשנו בפיצ'ר, ולכן הטיפ כבר לא רלוונטי
  _markTipResolved(LiveTipId.myNewTip);
  break;
```

#### 5. הוסף תנאי ב-`_resolveNextLiveTip`

```dart
LiveTipId? _resolveNextLiveTip() {
  // ... תנאים קיימים ...

  if (_canShowTip(LiveTipId.myNewTip) && _myNewCondition()) {
    return LiveTipId.myNewTip;
  }

  return null;
}
```

הסדר בפונקציה הוא סדר העדיפויות — טיפ שמופיע קודם ינצח.

#### 6. שלח אירועים מהמקום הנכון בקוד

מכל widget שרלוונטי:

```dart
context.read<TourCubit>().recordInteraction(
  TourInteraction(
    type: TourInteractionType.myNewEvent,
    primaryValue: optionalStringContext,  // אם נדרש
  ),
);
```

#### 7. הוסף בדיקה ב-`test/tour/tour_cubit_test.dart`

```dart
test('shows myNewTip after condition is met', () async {
  final cubit = TourCubit();
  await cubit.recordInteraction(
    TourInteraction(type: TourInteractionType.myNewEvent),
  );
  expect(cubit.state.activeLiveTipId, LiveTipId.myNewTip);
  cubit.close();
});
```

### כללי שליטה — מתי טיפ מוצג ומתי לא

| מצב | תוצאה |
|-----|--------|
| הסיור פעיל (`isActive == true`) | לא מציגים טיפ |
| יש כבר טיפ פעיל (`hasActiveLiveTip`) | לא מציגים טיפ נוסף |
| הטיפ כבר הוצג (`shownTips`) | לא מציגים שוב |
| הטיפ נפתר (`resolvedTips`) | לא מציגים בכלל |
| הסיור הסתיים/דולג, ותנאי הטיפ מתקיים | מציגים |

`shownTips` — טיפ שנראה פעם אחת לא יחזור (גם אם המשתמש לא ביצע את הפעולה המוצעת).  
`resolvedTips` — טיפ שהמשתמש ביצע את הפעולה שלו (נפתר), לא יוצג לעולם.

### `primaryValue` — ערך הקשרי

ב-`TourInteraction` אפשר להעביר `primaryValue: 'שם ספר'` כדי לצמד את האירוע לספר/לטאב מסוים. ה-cubit משתמש בזה לדוגמה כדי לוודא שהסיכוי למפרשים הגיע מאותו הספר:

```dart
if (_commentaryOpportunityBook == null ||
    _commentaryOpportunityBook == interaction.primaryValue) {
  _commentaryOpportunityScore++;
}
```

### `_recentInteractions` — חלון זמן

האינטראקציות האחרונות נשמרות בחלון של **30 שניות**. כך ניתן לזהות דפוסים (כמו דילוג בין שני ספרים) מבלי שאירועים ישנים ישפיעו.

```dart
final cutoff = interaction.timestamp.subtract(const Duration(seconds: 30));
_recentInteractions.removeWhere((i) => i.timestamp.isBefore(cutoff));
```

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
