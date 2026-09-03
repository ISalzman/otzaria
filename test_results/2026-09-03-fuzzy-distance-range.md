# issue #1120 — שדה המרחק בחיפוש מקורב הציע 0–30 אך המנוע מכבד רק 0–2

תאריך: 2026-09-03 | ענף: `fix/fuzzy-distance-range-1120` | קומיט אימות: `aad3092b`

## הבאג שאומת

הדיווח כלל שני חלקים: הצעת ניסוח/עיצוב לשדה (לא באג) וטענה שערכים 3–30
אינם משנים דבר. החלק השני אומת בקוד: `SearchEngineGateway._fuzzyDistance`
חותך את המרחק ל-`clamp(0, 2)` לפני שהוא מגיע למנוע, בעוד ה-`SpinBox`
ב-`FuzzyDistance` הציע `max: 30` גם במקורב. בנוסף, מעבר למקורב ממצב אחר
שמר מרווח-מילים ידני (למשל 7) — ערך שאינו קיים במקורב.

## הפתרון

הטווח המרבי הוגדר במקום אחד — `kMaxFuzzyDistance = 2` ב-`search_configuration.dart`
— ומשמש את המנוע (במקום המספר הקשיח), את השדה (`max` לפי מצב החיפוש:
2 במקורב, 30 בשאר) ואת ה-BLoC (`_resolveDistanceForModeChange` מצמצם מרחק
ידני במעבר למקורב). מעבר למתקדם/מדויק שומר את המרחק הידני כמו קודם.

הצעות העיצוב שבדיווח (תווית "רמת דיוק", אחוזים, מיון ברירת-מחדל לפי
רלוונטיות) אינן באגים ולא טופלו כאן.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/search/fuzzy_distance_range_test.dart` (חדש) | ה-SpinBox: 30 במדויק, 2 במקורב; BLoC: מרווח 7 ← מעבר למקורב ← ≤2 |
| `test/search/search_bloc_facet_counts_test.dart` | הבדיקה "שומר מרחק ידני" הותאמה לחוזה: נשמר במעבר למתקדם, מצומצם ל-2 במעבר למקורב |

הבדיקות החדשות נכשלו על `dev` (max=30, distance=7) ועוברות עם התיקון.
בדיקות ממוקדות `test/search/` + `test/tabs/models/`: 670 עברו; הכשל היחיד
מלבד ההתאמה לעיל — `search_scope_menu_search_actions_test`, ה-flake המוכר.

## אימות ויזואלי

המסך היה נעול (LogonUI) בזמן העבודה ולא ניתן היה לצלם; ההוכחה היא בדיקת
הווידג'ט על השדה עצמו (`SpinBox.max`) בשני המצבים.

## סוויטה מלאה

`flutter test`: **11,609 עברו, 13 נכשלו, 9 דולגו** (ריצה של 77 דק' על מחשב
נעול ועמוס). הכשלים: הבסיס הסביבתי המוכר (release_packaging,
‏3×file_sync_compaction, ‏personal_notes_file_backed_book, ‏plugin_spec_freshness,
‏search_scope_menu flake, ‏change_location_dialog, ‏plugin_side_panel שאינו
מתקמפל ב-`dev`), ועוד ארבעה flakes-תחת-עומס שעוברים בהרצה מבודדת
(`text_book_bloc_test` ×2, `text_encoding_performance_test`,
`raised_markers_perf_test`). אפס רגרסיות.
