# מערכת התוספים לאוצריא - תכנון ארכיטקטוני מלא

## מטרה

לבנות מערכת תוספים אמיתית, יציבה ומאובטחת, שמאפשרת:

- הוספת תוסף דרך כפתור `+` תחת מסך "כלים"
- הופעת התוסף כלשונית חדשה באותו מסך
- גישה מבוקרת של התוסף לנתוני האפליקציה
- ביצוע פעולות על האפליקציה עצמה
- פרסום נתונים חזרה מהתוסף אל האפליקציה, כך שהאפליקציה תוכל לצרוך אותם גם מחוץ ל-WebView
- תמיכה עתידית בעדכונים, הרשאות, ניהול התקנה, בדיקות ותיעוד SDK

המסמך הזה מחליף את התכנון הראשוני הקצר, ומגדיר ארכיטקטורה ברמת יישום.

---

## החלטת יסוד

### מה לא נעשה

לא נטען קוד Dart דינמי בזמן ריצה.

הסיבה:

- Flutter בפרודקשן עובד ב-AOT
- אי אפשר להוסיף Widgets, BLoC או קוד Dart חדש בלי build חדש של האפליקציה
- ניסיון "לעקוף" את זה ייצור מערכת לא יציבה, לא ניידת, ולא מתוחזקת

### מה כן נעשה

התוספים יהיו Web Apps ארוזים, שירוצו בתוך `WebView`, וידברו עם ה-host של אוצריא דרך גשר JavaScript ↔ Dart.

החלטה חשובה:

- לפיתוח מהיר אפשר לתמוך ב-HTML בודד
- לפורמט הרשמי של מערכת התוספים חייבים להשתמש בחבילה ארוזה, לא בקובץ `.html` בודד

הפורמט הרשמי יהיה:

- קובץ `.otzplugin`
- בפועל: קובץ ZIP עם manifest, קובץ כניסה, assets וקבצי SDK נלווים

זה פותר בעיות של:

- גרסאות
- אייקון ושם
- הרשאות
- כמה קבצים ו-assets
- בדיקת תאימות
- עדכון והסרה
- storage נפרד לכל תוסף

---

## כלים וטכנולוגיות

### צד האפליקציה

- `flutter_inappwebview`
  - מנוע WebView רב-פלטפורמי עם bridge טוב ל-JS
  - תומך בהזרקת JS, JavaScript handlers, intercept לבקשות, שליטה בטעינה וקבלת אירועים
  - מתאים יותר מ-`webview_flutter` לצרכים של host API והרשאות

- `file_picker`
  - כבר קיים בפרויקט
  - ישמש לבחירת קובץ `.otzplugin`

- `archive`
  - כבר קיים בפרויקט
  - ישמש לחילוץ חבילות תוסף

- `crypto`
  - כבר קיים בפרויקט
  - ישמש לבדיקת hash/integrity של חבילת התוסף

- `package_info_plus`
  - כבר קיים בפרויקט
  - ישמש לבדוק תאימות `minAppVersion` / `maxAppVersion`

- `path`, `path_provider`, `AppPaths`
  - לניהול תיקיות התקנה, cache ו-storage

- `sqlite3`
  - כבר קיים בפרויקט ומשמש גם באזורים אחרים
  - ישמש ל-DB ייעודי של מערכת התוספים

- `logging`
  - ל-logs של runtime, install flow, permissions ו-bridge

### צד כותב התוסף

- HTML/CSS/JavaScript
- מומלץ מאוד: TypeScript + Vite
- ה-SDK של אוצריא יסופק כקובץ `otzaria_plugin.js` ו-`otzaria_plugin.d.ts`

הערה:

- אוצריא לא צריכה Node.js בזמן ריצה
- Node/Vite הם כלי פיתוח של כותב התוסף בלבד

---

## אילוצים שמגיעים מהקוד הקיים

### מסך "כלים" קיים וסטטי

כיום `lib/tools/more_screen.dart` מחזיק:

- רשימת טאבים סטטית (`final List<_TabInfo> _tabs`)
- רשימת עמודים שנבנית פעם אחת ב-`initState` (`late final List<Widget> _pages`)
- `TabController` עם אורך קבוע

לכן כל מערכת תוספים חייבת להפוך את המסך הזה למסך מבוסס registry, ולא מבנה שנבנה פעם אחת עם אורך קבוע בזמן `initState`.

המשמעות המעשית:

- `_tabs` לא יכול להישאר static-only
- `_pages` לא יכול להישאר `late final`
- שינוי במספר התוספים בזמן ריצה מחייב יצירה מחדש של `TabController`

### הניווט והקריאה כבר מנוהלים דרך BLoC

הקוד הקיים כבר מגדיר היטב את ערוצי הפעולה:

- פתיחת ספר בפועל נעשית דרך `openBook()` ב-`lib/utils/open_book.dart`
- פתיחת טאבים נעשית דרך `TabsBloc` ו-`AddTab`
- מעבר למסך עיון נעשה דרך `NavigationBloc`
- חיפוש מלא נעשה דרך `SearchRepository`
- הערות אישיות מנוהלות דרך `PersonalNotesRepository` / `PersonalNotesBloc`
- הגדרות מנוהלות דרך `SettingsRepository` / `SettingsBloc`
- מצב לוח השנה מנוהל דרך `CalendarCubit`

המסקנה:

- לתוסף אסור לקבל גישה ישירה לאובייקטים פנימיים
- הוא חייב לעבוד רק דרך Host API רשמי
- ה-Host API ימופה פנימה לרכיבים הקיימים

### קיימת תשתית טובה ל-storage ו-DB

הפרויקט כבר עובד עם:

- `AppPaths`
- `Hive`
- `sqlite3`
- `PersonalNotesDatabase`

לכן אין צורך להמציא שכבת persistence חדשה. יש להוסיף DB ייעודי לתוספים ולהישען על התבניות הקיימות.

---

## עקרון הארכיטקטורה

המערכת תחולק ל-6 שכבות:

1. שכבת חבילה
2. שכבת registry
3. שכבת runtime
4. שכבת bridge / Host API
5. שכבת published data
6. שכבת UI וניהול

### 1. שכבת חבילה

אחראית על:

- בחירת קובץ תוסף
- חילוץ
- validation
- בדיקת manifest
- בדיקת תאימות
- יצירת תיקיית התקנה

### 2. שכבת registry

אחראית על:

- רשימת תוספים מותקנים
- enabled/disabled
- סדר הופעה ב"כלים"
- הרשאות שניתנו
- גרסה מותקנת
- נתיבי התקנה ו-storage

### 3. שכבת runtime

אחראית על:

- יצירת `InAppWebView`
- טעינת entrypoint
- הזרקת SDK
- lifecycle של התוסף
- suspend/resume/dispose

### 4. שכבת bridge / Host API

אחראית על:

- קריאות מהתוסף לאפליקציה
- בדיקות הרשאה
- מיפוי לקריאות Dart אמיתיות
- החזרת JSON לתוסף

### 5. שכבת published data

אחראית על:

- קליטת נתונים שהתוסף מפרסם ל-host
- שמירתם ב-DB
- חשיפתם ל-adapters פנימיים באפליקציה

### 6. שכבת UI וניהול

אחראית על:

- כפתור `+`
- טאב ניהול תוספים
- רשימת תוספים
- enable/disable
- uninstall
- permissions dialog
- error surfaces

---

## פורמט חבילת תוסף

### שם קובץ

פורמט רשמי:

- `*.otzplugin`

בפועל:

- ZIP עם סיומת מותאמת

### מבנה פנימי

```text
my-plugin.otzplugin
├── manifest.json
├── web/
│   ├── index.html
│   ├── main.js
│   ├── style.css
│   └── assets/
├── icon/
│   └── icon.png
└── README.md
```

### `manifest.json`

דוגמה:

```json
{
  "schemaVersion": 1,
  "id": "org.otzaria.halachic_calendar",
  "name": "לוח שנה הלכתי",
  "version": "1.0.0",
  "description": "לוח שנה הלכתי מורחב המבוסס על נתוני אוצריא",
  "author": "Example Author",
  "homepage": "https://example.com",
  "entrypoint": "web/index.html",
  "icon": "icon/icon.png",
  "minAppVersion": "0.9.86",
  "maxAppVersion": null,
  "sdkVersion": "1.x",
  "permissions": [
    "app.info.read",
    "library.books.read",
    "library.content.read",
    "search.fulltext.read",
    "reader.open",
    "notes.read",
    "notes.write",
    "calendar.read",
    "plugin.storage.read",
    "plugin.storage.write",
    "published_data.write",
    "events.subscribe:navigation.changed",
    "events.subscribe:reader.current_book_changed"
  ],
  "network": {
    "enabled": false,
    "allowlist": []
  },
  "contributes": {
    "toolTab": {
      "title": "לוח שנה הלכתי",
      "order": 700,
      "defaultPinned": true
    },
    "publishedDataTypes": [
      "calendar.event"
    ]
  }
}
```

### שדות חובה

- `schemaVersion`
- `id`
- `name`
- `version`
- `entrypoint`
- `permissions`
- `contributes.toolTab`

### שדות חשובים

- `minAppVersion`
- `sdkVersion`
- `network`
- `icon`
- `publishedDataTypes`

### כללי `id`

- יציב לכל חיי התוסף
- ASCII בלבד
- בסגנון reverse-domain
- לא משתנה בין גרסאות

דוגמאות:

- `org.otzaria.halachic_calendar`
- `com.example.seforim_analyzer`

---

## מבנה הקוד החדש בפרויקט

### תיקייה חדשה

```text
lib/plugins/
├── bloc/
│   ├── plugin_system_bloc.dart
│   ├── plugin_system_event.dart
│   └── plugin_system_state.dart
├── models/
│   ├── plugin_manifest.dart
│   ├── installed_plugin.dart
│   ├── plugin_permission_grant.dart
│   ├── plugin_tool_descriptor.dart
│   ├── plugin_rpc_request.dart
│   ├── plugin_rpc_response.dart
│   ├── plugin_published_record.dart
│   └── plugin_runtime_status.dart
├── repository/
│   ├── plugin_registry_repository.dart
│   ├── plugin_package_repository.dart
│   ├── plugin_storage_repository.dart
│   ├── plugin_published_data_repository.dart
│   ├── plugin_runtime_repository.dart
│   └── plugin_permissions_repository.dart
├── services/
│   ├── plugin_installer_service.dart
│   ├── plugin_manifest_validator.dart
│   ├── plugin_runtime_service.dart
│   ├── plugin_permission_service.dart
│   ├── plugin_runtime_dispatcher.dart
│   ├── plugin_sdk_bootstrap.dart
│   └── plugin_uninstall_service.dart
├── bridge/
│   ├── plugin_bridge_handler.dart
│   └── plugin_bridge_adapter.dart
├── storage/
│   └── plugin_system_database.dart
├── view/
│   ├── plugin_tab_page.dart
│   ├── plugin_side_panel.dart
│   ├── plugin_management_screen.dart
│   └── widgets/
│       ├── plugin_install_button.dart
│       ├── plugin_tile.dart
│       ├── plugin_pin_button.dart
│       ├── plugin_permission_dialog.dart
│       ├── plugin_error_card.dart
│       └── plugin_empty_state.dart
└── sdk/
    ├── otzaria_plugin.js
    ├── otzaria_plugin.d.ts
    └── README.md
```

הערה ארכיטקטונית:

- הפרויקט אינו "רק BLoC + Repository"
- יש בו בפועל גם שכבות `services` במספר פיצ'רים, למשל `personal_notes/services`, `tools/calendar/services`, `settings/services`, `indexing/services`
- לכן שכבת `services` כאן מותרת, אבל היא תישאר מצומצמת ל-orchestration/runtime בלבד
- גישה לנתונים תישאר ב-`repository`
- שכבת ה-`bridge` תוגדר כתת-תיקייה נפרדת, לא כחלק מ-`services`
- המיפוי בין bridge לבין repositories/BLoCs לא ייקרא repository, אלא adapter
- החלוקה בתוך ה-bridge תהיה:
  - `PluginBridgeHandler`: קבלת RPC, בדיקות הרשאה ו-routing
  - `PluginBridgeAdapter`: מימוש הפעולות מול repositories ו-BLoCs קיימים

---

## שינויים בקבצים קיימים

### `lib/tools/more_screen.dart`

זהו הקובץ הקריטי ביותר.

#### עיצוב חדש: פאנל תוספים בצד (בסגנון דפדפן)

במקום להוסיף טאב חדש לכל תוסף מותקן (שעלול לגרום לעומס טאבים), המסך יעבוד בצורה הבאה:

**מבנה המסך:**

```text
┌─────────────────────────────────────────────────┐
│ AppBar: [לוח שנה] [שמור וזכור] [מדות..] ... [🧩]│
├─────────────────────────────────────────────────┤
│                                    │ 🧩 תוספים  │
│                                    │ ────────── │
│     תוכן הטאב הנוכחי               │ ⊕ התקן     │
│                                    │ ────────── │
│                                    │ 📅 לוח הלכ│📌│
│                                    │ 📖 מילון+  │⊘│
│                                    │ 🔍 חיפוש+  │⊘│
│                                    │ ────────── │
│                                    │ ⚙ ניהול   │
└─────────────────────────────────────────────────┘
```

**כפתור התוספים (🧩):**

- יופיע בצד שמאל של ה-AppBar (כמו כפתור extensions בדפדפן)
- אייקון: `FluentIcons.puzzle_piece_24_regular`
- לחיצה עליו פותחת/סוגרת פאנל צדדי

**פאנל צדדי (PluginSidePanel):**

- נפתח בצד ימין של המסך (RTL — שמאל ויזואלית)
- רוחב קבוע: ~280px
- בראש הפאנל: כפתור **"⊕ התקן תוסף"** — מפעיל `FilePicker` ו-install flow
- מתחת: רשימת כל התוספים המותקנים, כל אחד מציג:
  - אייקון של התוסף
  - שם התוסף
  - כפתור **נעץ (📌)** — pin/unpin toggle
  - לחיצה על שם התוסף → מעביר לטאב שלו (אם מוצמד) או פותח אותו ב-overlay
- בתחתית: קישור **"⚙ ניהול תוספים"** — פותח את `PluginManagementScreen`

**מנגנון ה-Pin:**

- תוסף **מוצמד (pinned)** = יש לו טאב קבוע בשורת הטאבים
- תוסף **לא מוצמד (unpinned)** = אין לו טאב, אבל אפשר לגשת אליו דרך:
  - לחיצה על שמו בפאנל → פתיחה זמנית בתוך אזור התוכן
  - או פתיחה ב-overlay/drawer
- ברירת מחדל: התוסף יוצמד אוטומטית בהתקנה (`defaultPinned: true` ב-manifest)
- המשתמש יכול לבטל הצמדה בכל עת
- מצב ה-pin נשמר ב-DB (עמודת `pinned` בטבלת `plugin_installation`)

**ההשפעה על TabController:**

הטאבים במסך כלים יהיו:
1. **tools מובנים** — תמיד קיימים, סדר קבוע
2. **תוספים מוצמדים בלבד** — לפי `order` ואז `name`

יש לשנות:

- מעבר ממבנה קשיח של `_tabs` ו-`_pages` ל-`List<ToolDescriptor>`
- `ToolDescriptor` מייצג גם built-in וגם plugin
- רק תוספים עם `pinned == true` נכנסים ל-descriptor list
- יצירה מחדש של `TabController` כאשר מספר הטאבים משתנה (pin/unpin)
- שימור הטאב הפעיל לפי `toolId` יציב, לא לפי index בלבד
- השארת לוגיקת focus של לוח השנה על בסיס `toolId == 'builtin.calendar'`

פתרון מפורש ל-`TabController`:

1. לשמור `selectedToolId` יציב, לא רק `index`
2. בכל שינוי ב-list של descriptors (כולל pin/unpin):
3. לחשב `selectedToolId` נוכחי לפני ההחלפה
4. לבנות רשימת descriptors חדשה (מובנים + מוצמדים)
5. לחשב `newIndex` לפי `selectedToolId`, או `0` אם הטאב נמחק
6. להסיר listener מה-controller הישן
7. לעשות `dispose()` ל-controller הישן
8. ליצור `TabController(length: descriptors.length, initialIndex: newIndex, vsync: this)` חדש
9. לחבר listener מחדש
10. לקרוא `setState()`

כלל חשוב:

- לא עושים hot-swap ל-`TabController`
- יוצרים controller חדש לגמרי
- `PluginTabPage` צריך `ValueKey(toolId)`
- `_pages` צריכים להיבנות מחדש מרשימת descriptors, או להישמר ב-cache לפי `toolId`, אבל לא כ-`late final` קבוע

מבנה מוצע:

```dart
abstract class ToolDescriptor {
  String get toolId;
  String get label;
  Widget get icon;
  int get order;
  Widget buildPage(BuildContext context);
}

class BuiltInToolDescriptor extends ToolDescriptor { ... }
class PluginToolDescriptor extends ToolDescriptor { ... }
```

**פתיחת תוסף לא-מוצמד:**

כשהמשתמש לוחץ על תוסף בפאנל שאינו מוצמד:
- נוצר טאב זמני לתוסף, עם כפתור סגירה (temporary tab)
- זה מאפשר שימוש מהיר בתוסף בלי להצמיד אותו

### `lib/navigation/main_window_screen.dart`

שינויים נדרשים:

- אין צורך לשנות את מודל הניווט הראשי
- כן צריך לוודא ש-`MoreScreen` מאזין ל-`PluginSystemBloc`
- ייתכן שיהיה צורך ב-refresh ל-`_cachedMorePage` אם registry משתנה באופן דינמי

### `lib/main.dart`

יש להוסיף:

- יצירת `PluginSystemDatabase`
- `RepositoryProvider` / `BlocProvider` ל-plugin system
- `initialize()` שתיצור תיקיות plugins
- preload של registry

### `lib/core/app_paths.dart`

יש להוסיף מתודות:

- `getPluginsRootPath()`
- `getInstalledPluginsPath()`
- `getPluginInstallPath(String pluginId)`
- `getPluginDataPath(String pluginId)`
- `getPluginCachePath(String pluginId)`
- `resolvePluginsDbPath()`

### `lib/utils/zip_extractor_service.dart`

לא חובה לשנות, אבל כדאי:

- לחלץ helper ייעודי לחבילות plugin
- לא להשתמש ב-API הקיים "כמו שהוא" בלי ולידציה

מומלץ:

- `PluginInstallerService` ישתמש ב-`archive` ישירות
- `ZipExtractorService` יישאר עבור use-cases כלליים

### `lib/search/search_repository.dart`

לא חייבים לשנות לוגיקה פנימית, אבל צריך לעטוף אותה דרך Host API:

- `PluginBridgeAdapter.searchTexts(...)`

### `lib/utils/open_book.dart`

לא חייבים לחשוף ישירות את הפונקציה הזאת לתוסף, אבל ה-host כן ישתמש בה.

נדרש כאן פתרון מפורש, כי `openBook()` מקבל `BuildContext`.

הפתרון המומלץ:

- להוציא את הלוגיקה הפנימית של `openBook()` ל-coordinator/adapter נפרד שאינו תלוי `BuildContext`
- ה-coordinator יקבל ב-constructor את:
  - `TabsBloc`
  - `NavigationBloc`
  - `HistoryBloc`
  - `SettingsRepository` — נדרש כי `openBook` קורא ל-`Settings.getValue('key-pin-sidebar')` ול-`PageShapeSettingsManager`
- את ה-blocs וה-repository הללו אפשר להזריק מתוך `main.dart` בעת יצירת שכבת התוספים
- `openBook(BuildContext, ...)` יישאר wrapper UI דק בלבד, שישתמש באותו coordinator

כלל תכנוני:

- שכבת ה-bridge לא תשתמש ב-`BuildContext`
- לא תהיה תלות ב-`context.read(...)` מתוך handler של JS
- `navigatorKey.currentContext` יכול לשמש fallback ל-UI surface אם חייבים, אבל לא כמנגנון הליבה של פתיחת ספר

### `lib/personal_notes/repository/personal_notes_repository.dart`

ישמש לקריאות תוסף:

- list
- add
- update
- delete

### `lib/settings/engine/settings_repository.dart`

מומלץ להוסיף:

- מפתחות הגדרות למערכת תוספים
- `keyPluginsEnabled`
- `keyPluginsDeveloperMode`
- `keyPluginsAllowUnsigned`
- `keyPluginsAllowNetworkByDefault` אם בכלל יידרש

### `lib/tools/calendar/ulits/calendar_cubit.dart`

ישמש כ-consumer של published data מסוג:

- `calendar.event`

לא דרך גישה ישירה של JS ל-cubit, אלא דרך adapter ב-Dart.

---

## DB ייעודי למערכת התוספים

### החלטה

למערכת התוספים יהיה DB נפרד, למשל:

- `plugins_host.db`

הסיבה:

- לא לערבב storage של תוספים עם DB הספרים
- לא לערבב עם DB ההערות האישיות
- מאפשר schema ברור, migrations ו-clean uninstall

### טבלאות

#### `plugin_installation`

- `plugin_id TEXT PRIMARY KEY`
- `name TEXT NOT NULL`
- `version TEXT NOT NULL`
- `install_path TEXT NOT NULL`
- `entrypoint_path TEXT NOT NULL`
- `icon_path TEXT`
- `enabled INTEGER NOT NULL`
- `pinned INTEGER NOT NULL DEFAULT 1` — האם התוסף מוצמד כטאב במסך כלים
- `manifest_json TEXT NOT NULL`
- `installed_at TEXT NOT NULL`
- `updated_at TEXT NOT NULL`

#### `plugin_permission_grant`

- `plugin_id TEXT NOT NULL`
- `permission TEXT NOT NULL`
- `granted INTEGER NOT NULL`
- `granted_at TEXT NOT NULL`
- `PRIMARY KEY (plugin_id, permission)`

#### `plugin_kv_store`

- `plugin_id TEXT NOT NULL`
- `namespace TEXT NOT NULL`
- `key TEXT NOT NULL`
- `value_json TEXT NOT NULL`
- `updated_at TEXT NOT NULL`
- `PRIMARY KEY (plugin_id, namespace, key)`

#### `plugin_published_record`

- `plugin_id TEXT NOT NULL`
- `type TEXT NOT NULL`
- `scope TEXT NOT NULL`
- `record_key TEXT NOT NULL`
- `payload_json TEXT NOT NULL`
- `version INTEGER NOT NULL DEFAULT 1`
- `created_at TEXT NOT NULL`
- `updated_at TEXT NOT NULL`
- `expires_at TEXT`
- `PRIMARY KEY (plugin_id, type, scope, record_key)`

#### `plugin_runtime_log`

אופציונלי, ל-debug:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `plugin_id TEXT NOT NULL`
- `level TEXT NOT NULL`
- `message TEXT NOT NULL`
- `created_at TEXT NOT NULL`

### למה צריך גם `plugin_kv_store` וגם `plugin_published_record`

- `plugin_kv_store`
  - storage פרטי של התוסף
  - לא מיועד לצריכה ע"י שאר האפליקציה

- `plugin_published_record`
  - נתונים שהתוסף מפרסם במבנה מוסכם
  - כן מיועדים לצריכה ע"י host adapters ומסכים אחרים

---

## Flow ההתקנה

### צעד 1: בחירת קובץ

במסך "כלים" לחיצה על `+` תפעיל:

- `FilePicker.platform.pickFiles()`
- סינון לקבצים מסוג `.otzplugin`

### צעד 2: חילוץ לתיקיית temp

הקובץ יחולץ קודם ל-temp:

- validation לפני install
- אין לכתוב ישר לתיקיית installed

### צעד 3: ולידציה

יש לבדוק:

- קיים `manifest.json`
- `entrypoint` קיים
- `id` תקין
- `version` תקין
- `schemaVersion` נתמך
- `minAppVersion` נתמך
- `permissions` חוקיות
- אין path traversal
- כל paths בחבילה נשארים תחת root

### צעד 4: בדיקת עדכון

אם קיים כבר plugin עם אותו `id`:

- אם הגרסה זהה: לשאול אם לדרוס
- אם גרסה גבוהה יותר: update in place
- אם גרסה נמוכה יותר: לחסום או לבקש אישור downgrade

### צעד 5: העברה ל-install path

תיקיית היעד:

- `<plugins_root>/installed/<plugin_id>/current/`

אפשרות טובה יותר לעתיד:

- `<plugins_root>/installed/<plugin_id>/<version>/`
- symlink/marker ל-`current`

ל-MVP מספיק:

- `current/`

### צעד 6: שמירה ב-registry

כתיבה ל-DB:

- `plugin_installation`
- הרשאות ברירת מחדל

### צעד 7: רענון ה-UI

- `PluginSystemBloc` emits state חדש
- `MoreScreen` מוסיף טאב חדש

---

## Lifecycle של תוסף

### מצבים

- `installed`
- `loaded`
- `active`
- `suspended`
- `error`
- `disabled`
- `uninstalled`

### כללים

- תוסף נטען רק כשפותחים את הטאב שלו
- אין להריץ את כל התוספים מראש בפתיחת האפליקציה
- כשהטאב מוסתר, אפשר להשאיר את ה-WebView חי לזמן קצר
- אם יש הרבה תוספים פתוחים, יש לבצע dispose על LRU runtimes

### אירועי lifecycle שהתוסף יקבל

- `plugin.ready`
- `plugin.visible`
- `plugin.hidden`
- `plugin.suspended`
- `plugin.resumed`
- `plugin.unloading`

---

## ה-SDK שהתוסף יקבל

### API ברמת JavaScript

```javascript
const app = window.Otzaria;

const books = await app.call('library.findBooks', {
  query: 'כניסת שבת',
  limit: 20
});

await app.call('reader.openBook', {
  bookId: 'שולחן ערוך',
  index: 0,
  searchQuery: ''
});

await app.call('publishedData.upsert', {
  type: 'calendar.event',
  scope: 'global',
  key: 'halachic-calendar-2026-03-27',
  payload: {
    title: 'ערב שבת',
    startsAt: '2026-03-27T16:00:00+02:00'
  }
});

app.on('reader.current_book_changed', (payload) => {
  console.log(payload);
});
```

### Boot payload

בטעינה הראשונית התוסף יקבל snapshot:

```json
{
  "plugin": {
    "id": "org.otzaria.halachic_calendar",
    "version": "1.0.0"
  },
  "app": {
    "version": "0.9.86",
    "platform": "windows",
    "locale": "he-IL",
    "textDirection": "rtl"
  },
  "theme": {
    "mode": "light",
    "colorScheme": {
      "primary": "#6750A4",
      "onPrimary": "#FFFFFF",
      "secondary": "#625B71",
      "onSecondary": "#FFFFFF",
      "surface": "#FFFBFE",
      "onSurface": "#1C1B1F",
      "surfaceContainerHighest": "#E6E0E9",
      "error": "#B3261E",
      "onError": "#FFFFFF",
      "outline": "#79747E"
    },
    "typography": {
      "fontFamily": "Frank Ruhl Libre",
      "fontSize": 25,
      "lineHeight": 1.5,
      "commentatorsFontFamily": "Shofar",
      "commentatorsFontSize": 22
    }
  },
  "permissions": [
    "library.books.read",
    "reader.open"
  ]
}
```

המטרה:

- שהתוסף לא יצטרך לנחש theme/locale/platform
- לאפשר UI שמתיישר עם האפליקציה

---

## Host API - קריאות קריאה

### `app.info.read`

Methods:

- `app.getInfo`
- `app.getTheme` — מחזיר `colorScheme` מלא + `typography` (כמו ב-boot payload)
- `app.getLocale`

### `library.books.read`

Methods:

- `library.findBooks`
- `library.getBookMetadata`
- `library.listRecentBooks`

מימוש פנימי:

- `DataRepository.instance`
- `HistoryBloc` אם צריך recent items

### `library.content.read`

Methods:

- `library.getBookContent`
- `library.getBookToc`

כלל חשוב:

- לא להחזיר ספר שלם כברירת מחדל אם הוא גדול
- API צריך לתמוך ב:
  - `offset`
  - `limit` — עם `maxLimit = 5000` שנאכף בצד ה-host, גם אם התוסף מבקש יותר
  - `section`

### `search.fulltext.read`

Methods:

- `search.fullText`

מימוש פנימי:

- `SearchRepository.searchTexts`

### `calendar.read`

Methods:

- `calendar.getSelectedDate`
- `calendar.getDailyTimes` — כולל שקיעה, צאת הכוכבים, חצות וכו'
- `calendar.getHalachicTimes` — זמנים הלכתיים מלאים ליום נתון
- `calendar.getJewishDate` — המרה בין תאריך עברי ולועזי
- `calendar.getEvents`

מימוש פנימי:

- `CalendarCubit.state`

### `settings.read`

Methods:

- `settings.get`
- `settings.getMany`

כלל:

- גישה רק ל-allowlist של keys
- לא לחשוף secrets או מפתחות חיצוניים

Allowlist מפורש ב-V1 (keys שתוסף **יכול** לקרוא):

- `key-dark-mode`
- `key-follow-system-theme`
- `key-swatch-color` / `key-dark-swatch-color`
- `key-font-size` / `key-font-family`
- `key-commentators-font-family` / `key-commentators-font-size`
- `key-line-height`
- `key-selected-city`
- `key-calendar-type`
- `key-show-teamim`
- `key-default-nikud`
- `key-remove-nikud-tanach`
- `key-replace-holy-names`
- `key-library-view-mode`
- `key-align-tabs-to-right`
- `key-copy-with-headers` / `key-copy-header-format`

Blocklist (keys שתוסף **לא יכול** לקרוא — מסוננים גם עם allowlist כבטחון נוסף):

- `key-protected-mode-password-hash` — סיסמה
- `key-google-calendar-client-secret` — secret
- `key-google-calendar-credentials-json` — credentials
- `key-db-effective-path` — נתיב DB
- `key-library-path` — נתיב ספרייה
- `key-index-path` — נתיב אינדקס
- `key-backup-path` — נתיב גיבוי
- `key-hebrew-books-path` — נתיב חיצוני
- `key-error-report-sender-email` — PII

### `notes.read`

Methods:

- `notes.list`
- `notes.getBookNotesSummary`

מימוש פנימי:

- `PersonalNotesRepository`

---

## Host API - פעולות על האפליקציה

### `reader.open`

Methods:

- `reader.openBook`
- `reader.openBookAtRef`
- `reader.getCurrentState` — מחזיר את הספר הפתוח כרגע, אינדקס נוכחי, וטאבים פתוחים. חשוב כי תוסף שנטען אחרי שספר כבר פתוח מפספס את ה-event `reader.current_book_changed`

מימוש פנימי:

- `PluginBridgeAdapter.openBook(...)`
- coordinator פנימי שמוזן ב-`TabsBloc`, `NavigationBloc`, `HistoryBloc`, `SettingsRepository`
- `openBook(BuildContext, ...)` נשאר wrapper בלבד לצרכי UI רגיל

### `navigation.write`

Methods:

- `navigation.goTo`

ערכים חוקיים:

- `library`
- `reading`
- `more`
- `settings`

### `notes.write`

Methods:

- `notes.add`
- `notes.update`
- `notes.delete`

מימוש פנימי:

- `PersonalNotesRepository`

### `ui.feedback`

Methods:

- `ui.showMessage` — הודעת toast רגילה
- `ui.showSuccess` — הודעת הצלחה עם אייקון ✓
- `ui.showError` — הודעת שגיאה עם אייקון ✗
- `ui.showConfirm` — דיאלוג מודאלי עם שני כפתורים (ביטול/אישור). מחזיר `Promise<{confirmed: boolean}>`. מימוש דרך `showTwoActionsDialog`
- `ui.showWarning` — דיאלוג אזהרה עם subtitle באדום. מימוש דרך `showWarningDialog`

מימוש פנימי:

- `UiSnack.show`
- `UiSnack.showSuccess`
- `UiSnack.showError`
- `showTwoActionsDialog` / `showWarningDialog` מ-`custom_ui_components.dart`

הערה חשובה: `showConfirm` ו-`showWarning` דורשים `BuildContext`. ניתן להגיע אליו דרך `navigatorKey.currentContext` שכבר קיים ב-`UiSnack`. ה-bridge ישתמש באותו מנגנון.

### `plugin.storage.read` / `plugin.storage.write`

Methods:

- `storage.get`
- `storage.set`
- `storage.remove`
- `storage.list`

ה-storage הזה פרטי לתוסף ולא משותף עם שאר האפליקציה.

---

## Host API - פרסום נתונים מהתוסף אל האפליקציה

זהו החלק שחסר לגמרי במסמך הראשוני, והוא קריטי.

### למה צריך שכבה כזאת

אם התוסף הוא רק WebView, והוא רק "צורך" נתונים, הוא נשאר כלי מבודד.

כדי שתהיה אינטגרציה אמיתית, התוסף חייב להיות מסוגל:

- לפרסם מידע שהאפליקציה תשמור
- לאפשר למסכים אחרים באפליקציה לקרוא את המידע הזה
- לייצר נתונים שישרדו גם כשהתוסף לא פתוח

### API

Methods:

- `publishedData.upsert`
- `publishedData.remove`
- `publishedData.listOwn`

### מודל הנתון

כל record חייב להכיל:

- `type`
- `scope`
- `key`
- `payload`

### `type`

סוגי נתונים נתמכים ב-V1:

- `calendar.event`
- `saved.query`
- `note.draft`
- `reference.link`
- `tool.badge`

אפשר להרחיב בהמשך.

### `scope`

ערכים:

- `global`
- `workspace:<id>`
- `book:<bookId>`

### דוגמה

```javascript
await Otzaria.call('publishedData.upsert', {
  type: 'calendar.event',
  scope: 'global',
  key: 'hebcal:2026-03-27:sunset',
  payload: {
    title: 'שקיעה',
    startsAt: '2026-03-27T18:11:00+02:00',
    source: 'לוח שנה הלכתי',
    importance: 'high'
  }
});
```

---

## איך האפליקציה עצמה תשתמש בנתוני תוספים

### דרך Adapters

לא ניתן ולא כדאי שכל מקום באפליקציה יקרא JSON גולמי מטבלת plugins.

צריך שכבת adapters ב-Dart:

- `PluginCalendarAdapter`
- `PluginSavedQueryAdapter`
- `PluginReferenceLinksAdapter`
- `PluginToolBadgeAdapter`

### `PluginCalendarAdapter`

תפקיד:

- לקרוא `plugin_published_record` מסוג `calendar.event`
- להמיר ל-`CustomEvent` או מודל תואם
- להזרים ל-`CalendarCubit`

### `PluginSavedQueryAdapter`

תפקיד:

- לקרוא `saved.query`
- לחשוף אותם למסך חיפוש בעתיד

### `PluginReferenceLinksAdapter`

תפקיד:

- לקרוא `reference.link`
- לאפשר בעתיד אינטגרציה למסכי ספר

### `PluginToolBadgeAdapter`

תפקיד:

- לאפשר לתוסף לעדכן badge בטאב שלו או במסך הניהול

דוגמה:

- "3 אירועים חדשים"
- "נדרש חיבור מחדש"

### עיקרון חשוב

התוסף לא משנה state פנימי של האפליקציה ישירות.

במקום זה:

- הוא מפרסם record
- adapter פנימי קורא את ה-record
- האפליקציה מעדכנת את עצמה דרך המודלים הקיימים שלה

זה מונע coupling שביר.

---

## Dispatch אירועים לתוספים

### מה ה-Host ישדר לתוספים

Topics נתמכים ב-V1:

- `navigation.changed`
- `reader.current_book_changed`
- `theme.changed` — נשלח כשהמשתמש משנה צבע ערכת נושא, מצב כהה/בהיר, או פונט. ה-payload כולל את ה-`colorScheme` וה-`typography` המלאים (כמו ב-boot payload)
- `settings.changed` — נשלח כשהגדרה כלשהי משתנה. כולל `{key, newValue}` רק עבור keys שב-allowlist
- `calendar.date_changed`
- `workspace.changed`
- `plugin.permissions_changed`

### מה התוסף יכול לעשות

- subscribe לנושאים שמותרים לו
- להגיב לשינויים
- לרענן UI
- לפרסם נתונים חדשים

### מה התוסף לא יעשה

- לא יאזין לכל האירועים ללא הרשאה
- לא יוכל "להתערב" ב-BLoC פנימי

### מימוש

- לא יתווסף event bus כללי חדש שמקביל ל-BLoC
- `PluginSystemBloc` יהיה נקודת התיאום
- `PluginSystemBloc` יאזין לשינויים ממקורות קיימים כמו:
  - `NavigationBloc`
  - `TabsBloc`
  - `SettingsBloc`
  - `WorkspaceBloc`
  - `CalendarCubit`
- `PluginRuntimeService` / `plugin_runtime_dispatcher.dart` ישמרו subscriptions פר-plugin
- dispatch בפועל לתוסף ייעשה דרך `evaluateJavascript`

---

## אבטחה והרשאות

זה החלק הקריטי ביותר אחרי ה-bridge.

### עקרונות

- default deny
- כל method ב-Host API מחייב permission
- אין גישה ישירה ל-file system
- אין גישה ישירה ל-DB
- אין גישה ישירה ל-BLoCs
- רשת חסומה כברירת מחדל
- rate limiting — כללי עבור כל method. ב-V1 מספיק throttle פשוט: מקסימום 100 קריאות/שנייה לכל plugin, עם burst buffer של 50. חריגה תחזיר `error.rate_limited`
- timeout — כל קריאת bridge חייבת להסתיים תוך 30 שניות. חריגה תחזיר `error.timeout`

### סוגי הרשאות

- `app.info.read`
- `library.books.read`
- `library.content.read`
- `search.fulltext.read`
- `reader.open`
- `navigation.write`
- `notes.read`
- `notes.write`
- `calendar.read`
- `settings.read`
- `plugin.storage.read`
- `plugin.storage.write`
- `published_data.write`
- `events.subscribe:<topic>`
- `network.access`

### הרשאות granular

בעתיד אפשר להעמיק:

- `settings.read:keySelectedCity`
- `notes.read:book:<bookId>`
- `network.access:https://api.example.com`

אבל ב-V1 מספיק מודל ביניים פשוט וברור.

### רשת

ברירת מחדל:

- `network.enabled = false`

אם מופעל:

- חובה allowlist של domains
- ה-WebView צריך לחסום כל בקשה שאינה ב-allowlist

### local file access

התוסף יוכל לטעון רק:

- קבצים מתוך תיקיית ההתקנה שלו
- `data:`
- `blob:`
- `about:blank`

לא:

- `file:///` חופשי
- גישה לנתיבי מערכת
- גישה לתיקיית הספרים של אוצריא

### חסימת iframe ו-sandbox escape

- ה-WebView ישתמש ב-`shouldOverrideUrlLoading` כדי לחסום כל ניווט ל-URL שאינו:
  - `file://` בתוך תיקיית ההתקנה של אותו תוסף
  - `data:`, `blob:`, `about:blank`
- יצירת `<iframe>` שמצביע ל-`file:///` חיצוני תיחסם
- JavaScript `window.open()` ייחסם

### CSP

מומלץ לדרוש מהתוסף `Content-Security-Policy` ב-HTML שלו.

ב-V1:

- לא נחסום התקנה בלי CSP
- אבל נתריע במסך הניהול

### חתימות

ל-MVP:

- integrity hash בלבד

ל-V2:

- חתימת מפתח ציבורי

---

## אינטגרציה עם ה-UI

### מסך "כלים" — עיצוב פאנל תוספים

המסך עובר שינוי עיצובי משמעותי. במקום להוסיף טאב חדש לכל תוסף (עומס), המסך עובד בשילוב פאנל צדדי:

**רכיבים:**

1. **שורת טאבים** — tools מובנים + תוספים **מוצמדים בלבד**
2. **כפתור תוספים (🧩)** — בצד שמאל של ה-AppBar, פותח/סוגר פאנל
3. **פאנל צדדי** — רשימת כל התוספים עם pin/unpin

### סדר הטאבים

הסדר יהיה:

1. tools מובנים — תמיד ראשונים
2. תוספים **מוצמדים** בלבד, לפי `contributes.toolTab.order`
3. tie-breaker לפי `name`

תוספים לא-מוצמדים לא מופיעים בשורת הטאבים כלל.

### כפתור התוספים (🧩)

יופיע בצד שמאל של ה-AppBar של "כלים".

- אייקון: `FluentIcons.puzzle_piece_24_regular`
- לחיצה פותחת/סוגרת את פאנל התוספים
- badge קטן עם מספר התוספים המותקנים (אופציונלי)

### פאנל תוספים (PluginSidePanel)

רוחב: ~280px, נפתח בצד שמאל.

מבנה:

1. **כותרת:** "תוספים" עם כפתור סגירה
2. **כפתור "⊕ התקן תוסף חדש"** — בראש הפאנל
   - מפעיל `FilePicker` לבחירת `.otzplugin`
   - install flow
   - dialog הרשאות אם נדרשות
3. **רשימת תוספים מותקנים** — כל פריט מציג:
   - אייקון (מתוך `icon/icon.png` בחבילה)
   - שם התוסף
   - כפתור **נעץ (📌)** — toggle pin/unpin
   - לחיצה על שם → פתיחת התוסף (אם מוצמד — מעבר לטאב, אם לא — פתיחה זמנית)
4. **קישור "⚙ ניהול תוספים"** — בתחתית, פותח `PluginManagementScreen`

### מנגנון Pin — כללים

- תוסף **מוצמד** = יש לו טאב קבוע בשורת הטאבים
- תוסף **לא מוצמד** = זמין רק דרך הפאנל, בלחיצה נפתח כ-overlay/temporary
- ברירת מחדל: `defaultPinned: true` ב-manifest ← מוצמד אוטומטית בהתקנה
- המשתמש יכול לשנות pin בכל עת דרך הפאנל
- מצב pin נשמר בשדה `pinned` בטבלת `plugin_installation`
- `PluginSystemBloc` מנהל events `PinPluginRequested` / `UnpinPluginRequested`

### מסך ניהול תוספים

nנגיש דרך קישור בתחתית הפאנל הצדדי. מציג:

- רשימת תוספים מותקנים
- enable/disable
- uninstall
- update info
- permissions (צפייה ושינוי)
- storage size
- open logs

### רכיבי UI קיימים שיש לכבד בעת מימוש

- הודעות משתמש דרך `UiSnack`
- דיאלוגים דרך `custom_ui_components`
- כפתורי פעולה דרך `RecommendedActionButton` / `NeutralActionButton`
- אייקונים של Fluent בלבד
- צבעים דרך `Theme.of(context).colorScheme` בלבד, ללא hardcoded colors

---

## מבנה runtime של plugin tab

### `PluginTabPage`

אחראי על:

- יצירת `InAppWebView`
- טעינת entrypoint המקומי
- רישום JS handlers
- הזרקת SDK
- הצגת error UI אם קרה failure

### טוען את הקבצים מאיפה

נתיב טעינה:

- `<plugins_root>/installed/<plugin_id>/current/web/index.html`

### עליית עמוד

בעת `onLoadStop`:

- הזרקת boot payload
- dispatch `plugin.ready`

---

## API פנימי ב-Dart

### `PluginSystemBloc`

אחראי על:

- load installed plugins
- install plugin
- uninstall plugin
- enable/disable plugin
- pin/unpin plugin
- refresh registry

Events:

- `LoadPlugins`
- `InstallPluginRequested`
- `EnablePluginRequested`
- `DisablePluginRequested`
- `PinPluginRequested`
- `UnpinPluginRequested`
- `UninstallPluginRequested`
- `RefreshPlugins`

### `PluginInstallerService`

אחראי על:

- חילוץ temp
- validation
- copy/install
- registry update

### `PluginRuntimeService`

אחראי על:

- runtime controller לכל plugin
- lifecycle
- runtime status

### `PluginBridgeHandler`

אחראי על:

- קבלת RPC מה-JS
- permission checks
- route ל-method handler

### `PluginBridgeAdapter`

אחראי על:

- מימוש methods בפועל
- mapping ל-repositories וה-BLoCs הקיימים

### `PluginPublishedDataRepository`

אחראי על:

- upsert/remove/list ל-records שפורסמו

---

## דפוס קריאה מומלץ ב-bridge

### צד JavaScript

```javascript
await Otzaria.call('library.getBookContent', {
  bookId: 'משנה תורה, הלכות שבת',
  offset: 0,
  limit: 200
});
```

### צד Flutter

```dart
controller.addJavaScriptHandler(
  handlerName: 'otzariaHostCall',
  callback: (arguments) async {
    final request = PluginRpcRequest.fromDynamic(arguments.first);
    final response = await _pluginBridgeHandler.handle(
      pluginId: pluginId,
      request: request,
    );
    return response.toJson();
  },
);
```

### תשובה אחידה

```json
{
  "ok": true,
  "result": {
    "items": []
  },
  "error": null
}
```

או:

```json
{
  "ok": false,
  "result": null,
  "error": {
    "code": "permission_denied",
    "message": "Permission notes.write was not granted"
  }
}
```

---

## שיקולי ביצועים

### לא לחשוף ספר שלם כברירת מחדל

כי:

- WebView + JS + JSON serialization של טקסטים עצומים עלולים להיות יקרים

במקום זה:

- pagination
- section-based fetch
- TOC-driven fetch
- `maxLimit = 5000` נאכף בצד ה-host, בלי קשר למה שהתוסף מבקש

### cache

יש להחזיק cache ב-Dart עבור:

- manifest טעון
- permissions
- runtime instances

### logs

מומלץ logger נפרד:

- `Logger('PluginSystem')`
- `Logger('PluginBridge')`
- `Logger('PluginRuntime')`

### rate limiting

- throttle כללי: מקסימום 100 קריאות/שנייה לכל plugin
- burst buffer: 50 קריאות
- חריגה: `error.rate_limited` מוחזר לתוסף
- מימוש: counter פשוט ב-`PluginBridgeHandler` עם sliding window

---

## תאימות פלטפורמות

### Windows

- נדרש לוודא קיום WebView2 runtime
- `flutter_inappwebview` נשען עליו

### Linux

- נדרש לוודא זמינות runtime של WebKitGTK
- חובה לבדוק packaging של הפצה

### macOS / iOS

- WKWebView
- טעינת קבצים מקומיים חייבת להיעשות עם read access תקין לתיקיית התוסף
- זהו אזור שדורש בדיקת אינטגרציה מוקדמת

### Android

- Android WebView
- local file loading אפשרי, אך יש לחסום גישה לנתיבים חיצוניים

### מסקנה

מומלץ לבצע rollout בפועל לפי הסדר:

1. Windows
2. Linux/macOS
3. Android
4. iOS

לא כי iOS "לא אפשרי", אלא כי שם ה-edge-cases של local file access עדינים יותר.

---

## תוכנית יישום בשלבים

## שלב 0 - POC של WebView

מטרה:

- לוודא ש-`flutter_inappwebview` עובד על כל הפלטפורמות לפני כתיבת קוד

משימות:

- הוספת `flutter_inappwebview` ל-pubspec
- יצירת מסך בדיקה פשוט עם WebView שטוען HTML מקומי
- רישום JS handler ובדיקת bridge דו-כיווני
- בדיקה על: Windows, macOS, Linux, Android (iOS ב-V2)

Definition of done:

- WebView נטען, JS bridge עובד, `evaluateJavascript` מחזיר תשובה — על לפחות 3 פלטפורמות

## שלב 1 - תשתית install, registry ופאנל תוספים

מטרה:

- אפשר להתקין תוסף
- התוסף מופיע בפאנל תוספים
- אפשר להצמיד (pin) ולהסיר הצמדה (unpin)
- אין עדיין Host API עשיר

משימות:

- יצירת `lib/plugins/`
- DB ייעודי (כולל שדה `pinned`)
- `AppPaths` חדשים
- `PluginSystemBloc` (כולל pin/unpin events)
- install/uninstall
- שינוי `MoreScreen`: הוספת כפתור 🧩 ופאנל צדדי
- שינוי `MoreScreen`: dynamic tabs עבור תוספים מוצמדים
- טעינת `index.html` בתוך WebView

Definition of done:

- אפשר לבחור `.otzplugin`
- התוסף מופיע בפאנל צדדי
- אפשר להצמיד — ואז הטאב מופיע
- אפשר להסיר הצמדה — ואז הטאב נעלם
- אפשר לפתוח תוסף לא-מוצמד דרך הפאנל
- אפשר לפתוח את ה-HTML המקומי

## שלב 2 - Host API קריאה ופקודות בסיס

מטרה:

- התוסף יכול לצרוך נתונים ולפתוח ספרים

משימות:

- `app.getInfo` / `app.getTheme` (עם ColorScheme מלא)
- `library.findBooks`
- `library.getBookMetadata`
- `search.fullText`
- `reader.openBook` / `reader.getCurrentState`
- `ui.showMessage` / `ui.showSuccess` / `ui.showError` / `ui.showConfirm`
- `storage.get/set`

Definition of done:

- תוסף דוגמה יכול לחפש ספרים, לפתוח ספר ולהציג תוצאות

## שלב 3 - published data ו-dispatch אירועים

מטרה:

- התוסף יכול לתת נתונים חזרה לאפליקציה

משימות:

- `publishedData.upsert/remove`
- `PluginCalendarAdapter`
- `navigation.changed`
- `reader.current_book_changed`

Definition of done:

- תוסף יכול לפרסם אירועי לוח שנה והם נראים במסך הלוח

## שלב 4 - permissions management ו-hardening

מטרה:

- מערכת בטוחה וניתנת לניהול

משימות:

- permissions UI
- revoke permissions
- network allowlist
- runtime logs
- better error surfaces

## שלב 5 - SDK ותיעוד

מטרה:

- לאפשר לאחרים לכתוב תוספים בלי לקרוא את קוד אוצריא

משימות:

- `sdk/otzaria_plugin.js`
- `sdk/otzaria_plugin.d.ts`
- example plugin
- מדריך packaging

---

## בדיקות

### Unit tests

יש להוסיף:

- manifest validator
- installer service
- permission checks
- published data repository
- plugin DB migrations

### Widget tests

- `MoreScreen` עם dynamic tabs ופאנל צדדי
- מצב בלי תוספים (פאנל ריק)
- מצב עם תוספים מוצמדים (טאבים מופיעים)
- מצב עם תוספים לא-מוצמדים (רק בפאנל)
- מעבר pin ↔ unpin (טאב מתווסף/נמחק)

### Integration tests

עם fixture plugin:

- install
- load
- call host API
- publish data
- uninstall

### Manual QA

- Windows
- Linux
- macOS
- Android
- iOS

### בדיקת regression חשובה

לוודא שלא נשברה שום פונקציונליות של הטאבים המובנים ב-`MoreScreen`, במיוחד:

- לוח שנה
- החזרת focus
- Gematria
- הערות אישיות

---

## מה לא להכניס ל-V1

- טעינת Dart דינמית
- תוספים שמזריקים Flutter widgets
- background execution אמיתי של JS בכל הפלטפורמות
- גישה חופשית ל-file system
- גישה חופשית לאינטרנט
- שינוי state פנימי של BLoC ישירות מתוך plugin

---

## החלטות סופיות

### החלטה 1

פורמט הייצור הרשמי יהיה `.otzplugin`, לא `.html` בודד.

### החלטה 2

ה-runtime יהיה `flutter_inappwebview`.

### החלטה 3

המערכת תהיה מבוססת Host API רשמי, עם permissions ו-default deny.

### החלטה 4

נתונים שהתוסף רוצה להחזיר לאפליקציה יזרמו דרך `publishedData`, לא דרך שינוי state פנימי ישיר.

### החלטה 5

`MoreScreen` יעבור מארכיטקטורה קשיחה לארכיטקטורת registry, עם פאנל תוספים צדדי בסגנון דפדפן ומנגנון pin/unpin.

### החלטה 6

למערכת התוספים יהיה DB נפרד ו-storage נפרד.

### החלטה 7

תוספים לא יוסיפו טאב אוטומטית. במקום זה: פאנל צדדי עם pin/unpin — רק תוספים מוצמדים מקבלים טאב.

---

## התוצאה הרצויה

בסוף המהלך, אוצריא תקבל מערכת תוספים עם התכונות הבאות:

- התקנה מקובץ
- ניהול מסודר של תוספים דרך פאנל צדדי בסגנון דפדפן
- מנגנון pin/unpin שמונע עומס טאבים
- WebView runtime יציב
- API מסודר לנתוני אוצריא (כולל theme מלא, הגדרות עם allowlist, לוח שנה הלכתי)
- API מסודר לפעולות על אוצריא (כולל דיאלוגים מודאליים)
- channel מסודר לפרסום נתונים חזרה אל אוצריא
- אבטחה עם rate limiting, timeout, ו-sandbox
- תכנון שמתאים לקוד הקיים, ולא מערכת מקבילה מנותקת

זהו התכנון הנכון למערכת תוספים בפרויקט הזה.
