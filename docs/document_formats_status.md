# פורמטי מסמכים — ארכיטקטורה ומצב תמיכה

מסמך זה מתאר **איך** בנויה תמיכת הפורמטים באוצריא ו**מה** נתמך בה.
חוזה ההמרה עצמו — איזה אלמנט הופך לאיזה HTML, ובאילו פורמטים — מתועד
בנפרד ב-[`document_conversion_matrix.md`](document_conversion_matrix.md).
הרקע להכרעות סביב ‎.doc‎ הבינארי מתועד ב-
[`legacy_word_doc_research.md`](legacy_word_doc_research.md).
זיהוי הקידוד של קובץ טקסט גולמי — השכבה שדרכה עובר `txt` — מתועד ב-
[`text_encoding_detection.md`](text_encoding_detection.md).

## הפורמטים הנתמכים

מקור האמת הוא `kProductionBookFormats` ב-`lib/utils/file/document_format.dart`;
הטבלה כאן נגזרת ממנו.

| פורמט | מנוע ההמרה | קבוע הגרסה |
|---|---|---|
| `txt` | קריאה ישירה (זיהוי קידוד) | — |
| `pdf` | צנרת נפרדת; אינו טקסט | — |
| `epub` | `epub_to_otzaria.dart` | `kEpubConverterVersion` |
| `md`, `markdown` | `markdown_to_otzaria.dart` | `kMarkdownConverterVersion` |
| `docx`, `docm`, `dotx`, `dotm` | `docx_to_otzaria.dart` (OOXML) | `kOoxmlWordConverterVersion` |
| `xml` | `word_xml_to_otzaria.dart` → מנוע OOXML | `kWordXmlConverterVersion` |
| `odt` | `odt_to_otzaria.dart` | `kOdtConverterVersion` |
| `rtf` | `rtf_to_otzaria.dart` | `kRtfConverterVersion` |
| `doc`, `dot` | `legacy_word_to_otzaria.dart` (CFB + FIB) | `kLegacyWordConverterVersion` |
| `wbk` | נקבע לפי תוכן: OOXML או Word בינארי | לפי המנוע שנבחר |

## עקרונות הארכיטקטורה

### 1. `fileType` הוא זהות, לא תווית

`fileType` שנשמר ב-DB הוא הסיומת הקנונית **בדיוק כפי שהיא**: `docm` נשאר
`docm` ואינו ממופה ל-`docx`, גם כששני הפורמטים עוברים את אותו מנוע. הסיבה:
`fileType` הוא חלק מ-`BookCompositeKey` ומשמש ב-provider lookup, במטמון,
ב-dedup, באינדקס ובסיריאליזציה של טאבים. מיפוי משפחתי היה שובר את זהותם של
ספרים קיימים.

`BookCompositeKey.normalizeFileType` הוא **הנרמול היחיד** במערכת. אין נרמול
מקביל בשום שכבה.

### 2. שאלה סמנטית, לא רשימת סיומות

אף שכבה אינה מחזיקה רשימת סיומות משלה. במקום `if (ext == 'docx' || …)` היא
שואלת את `DocumentFormat`:

```dart
format.isTextual            // יש ממנו טקסט לקריאה, ל-TOC ולאינדוקס
format.requiresConversion   // קריאה כטקסט אינה מספיקה
format.canStoreLinesInDb    // השורות יכולות לשבת ב-DB (רק TXT)
format.isProductionSupported
book is ConvertibleDocumentBook
```

`isTextual` הוא predicate **אחד** לשלוש שאלות שהמפרט ביקש להפריד
(`canBuildToc`, `canIndexText`, וטקסטואליות): שלושתן זהות תמיד — PDF הוא
היחיד ששולל — ושלושה שמות לאותו ערך-אמת נוטים להתפצל.

### 3. נקודת dispatch אחת

`lib/utils/file/document_converter.dart` הוא המקום היחיד שבו פורמט מתורגם
למנוע. הסורק, ה-generator, ה-providers, האינדוקס וה-UI מגיעים אליו ואינם
מכירים אף ממיר בשם.

### 4. מקורות יחידים

| רכיב | מקור |
|---|---|
| נרמול `fileType` | `BookCompositeKey.normalizeFileType` |
| רשימת הסיומות | `kProductionBookFormats` |
| מיפוי פורמט → מנוע | `document_converter.dart` |
| escape של HTML (טקסט ומאפיינים) | `utils/text/html_escape.dart` |
| חוזה ה-markup (`<img>`, הערת שוליים, טבלה) | `utils/text/otzaria_markup.dart` |
| עיצוב inline (קו תחתי, קו חוצה, צבע, מרקר) | `utils/text/inline_style.dart` |
| עיצוב מספרי רשימה | `utils/text/numeral_formats.dart` |
| סוגי תמונה ותקרות הטמעה | `utils/file/embedded_media.dart` |
| מגבלות פריסת ZIP | `utils/file/zip_limits.dart` |
| אייקון ספר לפי פורמט | `utils/ui/book_format_icon.dart` |
| מכולת CFB לבדיקות | `tool/src/document_fixtures/cfb_builder.dart` |
| מסמך Word בינארי לבדיקות | `tool/src/document_fixtures/word_binary_builder.dart` |
| חבילת OOXML לבדיקות | `tool/src/document_fixtures/ooxml_builder.dart` |

## גרסת ממיר — הכלל החשוב ביותר לתחזוקה

> **כל שינוי שמשפיע על פלט הממיר מחייב העלאה של קבוע הגרסה שלו.**

הגרסה היא חלק ממפתח-התוקף של מטמון ההמרות (`cache.db`), ולכן תיקון באג בלי
העלאת גרסה משאיר כל ספר שנפתח פעם אחת עם הפלט **הבאגי** — לצמיתות.

הצימוד נאכף ב-`test/utils/file/converter_versions_test.dart`: הוא מקבע
טביעת אצבע של פלט מסמך-דגימה לצד מספר הגרסה, ונכשל אם עודכן רק אחד מהם.
גרסת ממיר ה-XML **נגזרת** מגרסת מנוע ה-OOXML, שהוא זה שמייצר את הפלט שלה.

## חוזה הכשל

היררכיה מוקלדת ב-`document_conversion_exceptions.dart`, כדי שהקורא יבחין בין
המקרים בלי לנתח מחרוזות:

| חריגה | מתי |
|---|---|
| `UnsupportedDocumentFormatException` | אין מנוע לפורמט |
| `CorruptedDocumentException` | המכולה נקראה אך מבנה המסמך שבור |
| `EncryptedDocumentException` | המסמך מוגן בסיסמה |
| `DocumentConversionFailedException` | כשל שאינו נופל לאף קטגוריה |

שני כללים נגזרים:

1. **לעולם אין ליפול מכשל המרה לקריאת הקובץ כטקסט.** פירוש בייטי ZIP או OLE
   כ-Windows-1255 מייצר ג'יבריש עברי שנראה כספר תקין לגמרי — הוא נשמר
   במטמון, נכנס לאינדקס, ומסמן הערות אישיות כחסרות.
2. **מסמך ריק אינו כשל.** ממיר שהצליח על מסמך ריק מחזיר כותרת בלבד; רק גוף
   שאינו קריא זורק.

קובץ פגום בסריקת תיקייה נרשם ללוג (נתיב, פורמט מוצהר, פורמט שזוהה, גרסת
ממיר, שגיאה) והסריקה ממשיכה לקובץ הבא.

## זיהוי לפי תוכן

הסיומת היא מסלול מהיר, אך שתי סיומות אינן מספיקות ומחייבות בדיקת תוכן
(`DocumentFormat.needsContentSniffing`):

- **‎.wbk‎** — גיבוי של Word, שיכול להיות חבילת OOXML או קובץ בינארי ישן.
- **‎.xml‎** — סיומת גנרית. בלי השער, כל קובץ הגדרות בתיקייה שנסרקת היה
  נאסף כ"ספר" ונכשל בפתיחה.

מעבר לכך, זיהוי-התוכן גובר על הסיומת כשהיא מובילה למנוע הלא-נכון. הוא אינו
מפרק את הסיומת בתוך אותה משפחת מנועים: `docm` שתוכנו OOXML נשאר `docm`.

## סטיות מכוונות מהמפרט

| נושא | ההחלטה |
|---|---|
| `canBuildToc`/`canIndexText` כ-properties נפרדים | אוחדו ל-`isTextual` — ראו עיקרון 2 |
| `DocumentConversionResult` עם warnings | לא מומש: אף ממיר אינו מייצר אזהרות, ומחלקה שאיש אינו יוצר היא קוד מת שמשדר יכולת שאינה קיימת |
| Benchmarking לכל הממירים | לא מומש: קיים בנצ'מרק ל-OOXML בלבד, ואין baseline מספרי לשאר |
| rename של `docx_to_otzaria.dart` / `docx_cache.dart` / `DocxBook` | לא בוצע: השמות היסטוריים אך נדרשים — טאבים והיסטוריה שמורים מכילים `"type": "DocxBook"`, ורשומות המטמון ממופות לפי שם הטבלה. rename מחייב migration ולכן אינו "בחינם" |
| `md`/`markdown` | לא היו במפרט (נוספו לקוד אחריו); נכללו ב-`DocumentFormat` כדי שה-registry יישאר מקור יחיד |

## פערים ידועים

| פער | חומרה | הערה |
|---|---|---|
| תמונות צפות ב-‎.doc‎ בינארי | בינונית | רק תמונות inline מחולצות; מעוגנות דורשות `PlcSpaMom` + `OfficeArtContent` |
| בונה ה-CFB לבדיקות חסום ב-‎~64KB‎ | בינונית | סקטור FAT יחיד, בלי DIFAT. חריגה **זורקת** ולא נחתכת בשקט, אך מסלולי ריבוי-סקטורי-FAT אינם מכוסים ב-fixtures — רק מול ‎.doc‎ אמיתיים |
| מספור רשימות ב-‎.doc‎ בינארי | בינונית | טבלאות `LST`/`LVL` אינן מפוענחות. תוכן הפריט נשמר; רק התווית חסרה |
| קובץ פגום ב-`FileSyncService` | בינונית | `DatabaseLibraryProvider` ממיר בזמן סריקה ותופס את הכשל; `FileSyncService` אינו ממיר, ולכן הכשל מתגלה רק בפתיחה. התנהגות שקדמה לעבודה הזו |
| מאפייני תא ב-‎.doc‎ בינארי | נמוכה | `<th>`, מיזוגים, רקע ויישור אנכי — מבנה ה-TAP אינו נקרא. הטבלה עצמה נבנית |
| תיבות טקסט ב-‎.doc‎ בינארי | נמוכה | עץ ה-OfficeArt נקרא לתמונות בלבד |
| תמונת רקע לתיבה ב-RTF | נמוכה | `\shptxt` נקרא; מאפייני המילוי של השייף אינם |

## אבטחה ומשאבים

- **חבילות ZIP** (`docx`/`docm`/`dotx`/`dotm`/`odt`/`epub`) נבדקות מול מספר
  רשומות, גודל פרוס ויחס דחיסה — ובנוסף מול הגודל **בפועל** אחרי הפריסה,
  שכן ארכיון זדוני יכול לשקר בהצהרתו.
- **אין גישת רשת בהמרה.** יחס שנתיבו מפנה לחבילה עצמה נקרא מתוכה; יחס
  חיצוני מדולג.
- **מאקרו אינו מורץ.** ‎.docm‎/‎.dotm‎ נקראים כתוכן בלבד.
- **תמונה מוטמעת** חסומה בתקרה לתמונה בודדת ובתקרה מצטברת למסמך; חריגה
  משאירה `<img>` ריק, כדי שמבנה השורות — ועמו מיקומי ההערות והסימניות —
  יישמר.

## מפת הבדיקות

| נושא | קובץ |
|---|---|
| זיהוי פורמט ו-registry | `test/utils/file/document_format_test.dart` |
| עקביות ה-registry מול הצרכנים | `test/utils/file/format_registry_consistency_test.dart` |
| Golden regression ל-Word (17 תרחישים) | `test/utils/file/docx_golden_test.dart` |
| שקילות בין פורמטי OOXML | `test/utils/file/ooxml_formats_pipeline_test.dart` |
| ODT | `test/utils/file/odt_to_otzaria_test.dart` |
| RTF | `test/utils/file/rtf_to_otzaria_test.dart` |
| Word שנשמר כ-XML | `test/utils/file/word_xml_to_otzaria_test.dart` |
| מכולת CFB | `test/utils/file/cfb_reader_test.dart` |
| Word בינארי | `test/utils/file/legacy_word_to_otzaria_test.dart`, `…legacy_word_properties_test.dart`, `…legacy_word_pictures_test.dart` |
| קלט פגום/קטוע/זדוני (28 בדיקות) | `test/utils/file/malformed_document_hardening_test.dart` |
| מגבלות ZIP | `test/utils/file/zip_limits_test.dart` |
| צימוד פלט↔גרסה | `test/utils/file/converter_versions_test.dart` |
| קריאת ספר file-backed | `test/utils/file/read_file_backed_book_text_test.dart` |
| עמידות סריקה לקובץ פגום | `test/migration/generator_corrupted_file_test.dart` |
| אינטגרציה: סריקה → DB → פתיחה → זיהוי שינוי | `test/migration/sync/file_sync_document_formats_test.dart` |
| מחולל קורפוס ה-fixtures | `test/tool/document_fixtures_generator_test.dart` |

## קורפוס קבצי הבדיקה

```bash
dart run tool/generate_document_fixtures.dart <תיקיית-יעד>
```

מייצר קבצים בכל הפורמטים, כולל מקרי-קצה (פגום, מוצפן, מזויף, WBK משני
הסוגים). המחולל בונה מבנים בינאריים **אמיתיים** — קובץ שרק נראה כמו OLE
אינו בודק דבר. `test/tool/document_fixtures_generator_test.dart` מריץ אותו
ומאמת שכל פורמט נפתח ושכל מקרה-קצה זורק את החריגה המדויקת.
