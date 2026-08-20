// מחולל קורפוס הזהב של זיהוי הקידודים.
//
// הקורפוס אינו נשמר ב-git אלא נבנה מחדש בכל ריצה, ולכן ההצפנה נעשית דרך
// היפוך טבלאות הפענוח של המוצר — טבלה שנייה הייתה נסחפת בשקט מזו שבייצור,
// והקורפוס כולו היה מאבד את ערכו. נכונות הטבלאות עצמן ננעצת מול התקנים
// ב-`test/utils/file/text_encoding_tables_test.dart`.
//
// הרצה עצמאית (כתיבת הקורפוס לתיקייה לעיון):
//   dart run tool/generate_text_encoding_fixtures.dart <dir>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:otzaria/utils/file/text_encoding.dart';

/// טווחי ה-confidence שהמימוש מתחייב אליהם (§32).
enum ConfidenceBand {
  /// BOM שמצעו נאמת, או קובץ ריק.
  certain(1.0, 1.0),

  /// UTF-8 שעבר אימות קפדני ותוכנו נראה טקסט. תוכן שאינו טקסט יורד משם עד
  /// 0.30, ואז מקומו ב-[low].
  utf8Strict(0.99, 1.0),

  /// היוריסטיקת UTF-16/UTF-32 בלי BOM, עם די יחידות. הרצפה 0.80 היא הבסיס
  /// והתקרה 0.98 היא המקסימום — ודאות של BOM אינה מושגת בהיוריסטיקה.
  unicodeHeuristic(0.80, 0.98),

  /// קידוד שזוהה אך המצע פגום: זנב קטוע או יחידות פסולות.
  truncatedTail(0.70, 0.75),

  /// קידוד עברי מדור קודם עם עדות משמעותית.
  legacyStrong(0.70, 0.90),

  /// אין די עדות — יש להציע למשתמש לבחור קידוד.
  low(0.0, 0.5999);

  const ConfidenceBand(this.min, this.max);

  final double min;
  final double max;
}

/// קובץ בקורפוס והציפייה ממנו.
class EncodingFixture {
  const EncodingFixture({
    required this.file,
    required this.purpose,
    required this.band,
    this.expectedEncoding,
    this.expectedText,
    this.hadBom = false,
    this.forbidReplacementChar = false,
  });

  final String file;
  final String purpose;
  final ConfidenceBand band;

  /// `null` = לקלט הזה אין קידוד "נכון", ונבדקת רק רמת הוודאות.
  final TextEncoding? expectedEncoding;

  /// `null` = הטקסט אינו חלק מהחוזה (קלט בינארי או פגום).
  final String? expectedText;

  final bool hadBom;

  /// הפלט אסור שיכיל `U+FFFD` — פענוח שנכשל לא יוסתר בתווי החלפה (§37).
  final bool forbidReplacementChar;

  Map<String, Object?> toJson() => {
    'file': file,
    'purpose': purpose,
    'expectedEncoding': expectedEncoding?.name,
    'expectedText': expectedText,
    'confidenceBand': band.name,
    'confidenceMin': band.min,
    'confidenceMax': band.max,
    'hadBom': hadBom,
    'forbidReplacementChar': forbidReplacementChar,
  };
}

// ===========================================================================
// תוכני הבסיס
// ===========================================================================

/// טקסט מלא — עברית, ניקוד, גרשיים, שקל, ASCII ומספרים. נכנס רק לקידודי
/// Unicode; קידודי העברית הישנים אינם מכילים את כל התווים האלה.
const String unicodeSample =
    '<h1>עריכת ספר באוצריא</h1>\n'
    'שלום עולם! Hello World! 12345\n'
    'טקסט עברי לבדיקת קידודים: אבגדהוזחטיכךלמםנןסעפףצץקרשת.\n'
    'עם ניקוד: בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ.\n'
    'גרש: ר׳ עקיבא, גרשיים: רמב״ם. סימן שקל: 100 ₪.\n'
    'שורה קצרה.\n'
    'זוהי שורה ארוכה שנועדה לבדוק את התנהגות מנוע הזיהוי על פסקאות ארוכות '
    'עם תווים מעורבים באנגלית, עברית, מספרים וסימני פיסוק.\n';

/// אותיות עבריות ו-ASCII בלבד — הצירוף היחיד שכל שלושת הקידודים הישנים
/// מקודדים, ולכן גם זה שאין דרך להכריע בין Windows-1255 ל-ISO-8859-8 עליו.
const String legacyLettersSample =
    '<h1>מסכת ברכות</h1>\n'
    'מאימתי קורין את שמע בערבית, משעה שהכהנים נכנסים לאכול בתרומתן.\n'
    'עד סוף האשמורה הראשונה, דברי רבי אליעזר. Hello World 12345\n'
    'וחכמים אומרים עד חצות, רבן גמליאל אומר עד שיעלה עמוד השחר.\n'
    'שורה קצרה. ועוד שורה, עם פסיק; ונקודתיים: וסוגריים (כאלה).\n';

/// עברית מנוקדת עם גרש, גרשיים, שקל ומרכאות טיפוגרפיות — כל אלה קיימים
/// ב-Windows-1255 ובו בלבד, וזו העדות שמפרידה אותו מ-ISO-8859-8 ומ-CP862.
const String windows1255Sample =
    'בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ.\n'
    'וְהָאָרֶץ הָיְתָה תֹהוּ וָבֹהוּ, וְחֹשֶׁךְ עַל פְּנֵי תְהוֹם.\n'
    'ר׳ עקיבא אומר, וכן כתב הרמב״ם ז״ל בהלכות תשובה.\n'
    'מחיר הספר: 100 ₪, והמדובר ב“מהדורה חדשה” — כולל מפתחות…\n';

/// עברית עם קו תחתי כפול (`U+2017`), התו היחיד שקיים ב-ISO-8859-8 ואינו
/// קיים ב-Windows-1255 — בלעדיו שני הקידודים אינם ניתנים להפרדה.
const String iso88598Sample =
    'כתב יד עתיק‗ עם קו תחתי כפול‗ בסוף השורה.\n'
    'מאימתי קורין את שמע בערבית, משעה שהכהנים נכנסים לאכול בתרומתן.\n'
    'עד סוף האשמורה הראשונה, דברי רבי אליעזר‗ וחכמים אומרים עד חצות.\n';

/// עברית של DOS. מסגרות ה-CP437 שיושבות ב-0xB0–0xDF הן העדות ל-CP862:
/// ב-Windows-1255 וב-ISO-8859-8 רוב הבתים האלה אינם מוגדרים כלל.
const String cp862Sample =
    '╔══════════════════════════════╗\n'
    '║ ספר הזכרונות - מהדורת דוס    ║\n'
    '╠══════════════════════════════╣\n'
    '║ מאימתי קורין את שמע בערבית   ║\n'
    '║ משעה שהכהנים נכנסים לאכול    ║\n'
    '╚══════════════════════════════╝\n'
    'שורה רגילה אחרי המסגרת, עם ASCII ומספרים 12345.\n';

/// קובץ שנראה UTF-16LE לכל היוריסטיקה מבנית — כל בית אי-זוגי הוא רווח,
/// והאותיות שנבחרו (a–o) גורמות לכל זוג בתים ליפול בתוך טווח הפיסוק הכללי
/// של יוניקוד. זהו בדיוק הקובץ שהמימוש הקודם החזיר עליו ג'יבריש (§53).
const String utf8LooksLikeUtf16Sample =
    'a b c d e f g h i j k l m n o '
    'a b c d e f g h i j k l m n o '
    'a b c d e f g h i j k l m n o '
    'a b c d e f g h i j k l m n o ';

/// כתבים שאינם עברית או לטינית: הם מנקדים נמוך בסולם ה"טקסט של ספר עברי",
/// אך המימוש הקודם פענח אותם נכון ב-UTF-16 בלי BOM — ואסור לשבור אותם.
const String cyrillicSample =
    'Съешь же ещё этих мягких французских булок, да выпей чаю.\n'
    'Широкая электрификация южных губерний даст мощный толчок.\n'
    'В чащах юга жил бы цитрус? Да, но фальшивый экземпляр!\n';

const String greekSample =
    'Ξεσκεπάζω την ψυχοφθόρα βδελυγμία, και τα λοιπά.\n'
    'Η καλημέρα του ήλιου φέρνει χαρά σε όλους τους ανθρώπους.\n'
    'Τάχιστη αλώπηξ βαφής ψημένη γη, δρασκελίζει υπέρ νωθρού κυνός.\n';

/// טקסט ארוך לבדיקת חלונות הדגימה (ראש, אמצע וזנב) ולמדידת תפוקה.
String largeHebrewBook({int paragraphs = 400}) {
  final buffer = StringBuffer('<h1>ספר הבדיקות הגדול</h1>\n');
  for (var i = 1; i <= paragraphs; i++) {
    buffer
      ..write('<h2>פרק $i</h2>\n')
      ..write(
        'מאימתי קורין את שמע בערבית, משעה שהכהנים נכנסים לאכול בתרומתן. '
        'עד סוף האשמורה הראשונה, דברי רבי אליעזר, וחכמים אומרים עד חצות. '
        'רבן גמליאל אומר עד שיעלה עמוד השחר, ומעשה שבאו בניו מבית המשתה. '
        'סימן $i, עמוד ${i * 3}, שורה ${i * 7}.\n',
      );
  }
  return buffer.toString();
}

// ===========================================================================
// מקודדים
// ===========================================================================

/// טבלת הצפנה שנבנית מהיפוך טבלת הפענוח של המוצר.
Map<int, int> legacyEncoderFor(TextEncoding encoding) {
  final single = Uint8List(1);
  final map = <int, int>{};
  for (var byte = 0; byte < 256; byte++) {
    single[0] = byte;
    final decoded = decodeTextBytesWith(single, encoding);
    final rune = decoded.runes.first;
    if (rune == 0xFFFD) continue; // בית לא מוגדר — אין לו ייצוג הפוך
    map.putIfAbsent(rune, () => byte);
  }
  return map;
}

/// מקודד ל[encoding]. תו שאין לו ייצוג זורק — קורפוס שמאבד תווים בשקט אינו
/// קורפוס.
Uint8List encodeLegacy(String text, TextEncoding encoding) {
  final encoder = legacyEncoderFor(encoding);
  final out = BytesBuilder();
  for (final rune in text.runes) {
    final byte = encoder[rune];
    if (byte == null) {
      throw ArgumentError(
        'התו U+${rune.toRadixString(16).toUpperCase()} אינו קיים ב-'
        '${encoding.label}',
      );
    }
    out.addByte(byte);
  }
  return out.toBytes();
}

Uint8List encodeUtf16(
  String text, {
  required bool littleEndian,
  bool bom = false,
}) {
  final out = BytesBuilder();
  if (bom) out.add(littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]);
  for (final unit in text.codeUnits) {
    out.add(
      littleEndian
          ? [unit & 0xFF, (unit >> 8) & 0xFF]
          : [(unit >> 8) & 0xFF, unit & 0xFF],
    );
  }
  return out.toBytes();
}

Uint8List encodeUtf32(
  String text, {
  required bool littleEndian,
  bool bom = false,
}) {
  final out = BytesBuilder();
  if (bom) {
    out.add(littleEndian ? [0xFF, 0xFE, 0x00, 0x00] : [0x00, 0x00, 0xFE, 0xFF]);
  }
  for (final rune in text.runes) {
    out.add(_utf32Unit(rune, littleEndian));
  }
  return out.toBytes();
}

List<int> _utf32Unit(int value, bool littleEndian) {
  final bytes = [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
  return littleEndian ? bytes : bytes.reversed.toList();
}

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

Uint8List _concat(List<Uint8List> parts) {
  final out = BytesBuilder();
  for (final part in parts) {
    out.add(part);
  }
  return out.toBytes();
}

// ===========================================================================
// הקורפוס
// ===========================================================================

/// בונה את הקורפוס בתוך [directory] ומחזיר את רשימת הציפיות.
List<EncodingFixture> generateTextEncodingFixtures(Directory directory) {
  directory.createSync(recursive: true);
  final fixtures = <EncodingFixture>[];

  void write(
    String name,
    Uint8List bytes, {
    required String purpose,
    required ConfidenceBand band,
    TextEncoding? encoding,
    String? text,
    bool hadBom = false,
    bool forbidReplacementChar = false,
  }) {
    File(
      '${directory.path}${Platform.pathSeparator}$name',
    ).writeAsBytesSync(bytes);
    fixtures.add(
      EncodingFixture(
        file: name,
        purpose: purpose,
        band: band,
        expectedEncoding: encoding,
        expectedText: text,
        hadBom: hadBom,
        forbidReplacementChar: forbidReplacementChar,
      ),
    );
  }

  // --- UTF-8 ---------------------------------------------------------------
  final utf8Bytes = Uint8List.fromList(utf8.encode(unicodeSample));
  write(
    'utf8_plain.txt',
    utf8Bytes,
    purpose: 'UTF-8 בלי BOM — המסלול הנפוץ',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: unicodeSample,
  );
  write(
    'utf8_bom.txt',
    _concat([
      _bytes([0xEF, 0xBB, 0xBF]),
      utf8Bytes,
    ]),
    purpose: 'UTF-8 עם BOM — ה-BOM מוסר מהטקסט',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf8,
    text: unicodeSample,
    hadBom: true,
  );
  write(
    'utf8_ascii_only.txt',
    Uint8List.fromList(
      utf8.encode('Hello World! 12345\nOnly ASCII here.\nShort line.\n'),
    ),
    purpose: 'ASCII טהור נשאר כמו שהוא',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'Hello World! 12345\nOnly ASCII here.\nShort line.\n',
  );
  write(
    'utf8_hebrew_only.txt',
    Uint8List.fromList(utf8.encode('שלום עולם טקסט בעברית בלבד')),
    purpose: 'עברית UTF-8 בלי ASCII',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'שלום עולם טקסט בעברית בלבד',
  );
  write(
    'utf8_mixed.txt',
    Uint8List.fromList(utf8.encode('Hello שלום 123 World עולם!')),
    purpose: 'עברית ואנגלית מעורבות',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'Hello שלום 123 World עולם!',
  );
  write(
    'utf8_crlf.txt',
    Uint8List.fromList(utf8.encode('שורה ראשונה\r\nשורה שניה\r\nסוף\r')),
    purpose: 'סיומות שורה CRLF ו-CR נשמרות כפי שהן (§65)',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'שורה ראשונה\r\nשורה שניה\r\nסוף\r',
  );
  write(
    'utf8_single_newline.txt',
    Uint8List.fromList(utf8.encode('\n')),
    purpose: 'קובץ של תו אחד',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: '\n',
  );
  write(
    'utf8_short.txt',
    Uint8List.fromList(utf8.encode('שלום')),
    purpose: 'UTF-8 קצר מאוד',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'שלום',
  );
  write(
    'utf8_single_hebrew_char.txt',
    Uint8List.fromList(utf8.encode('א')),
    purpose: 'שני בתים — UTF-8 חוקי מכריע גם בלי עדות סטטיסטית',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'א',
  );
  write(
    'utf8_one_byte.txt',
    _bytes([0x41]),
    purpose: 'בית אחד',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'A',
  );
  write(
    'utf8_two_bytes.txt',
    _bytes([0x41, 0x42]),
    purpose: 'שני בתים',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'AB',
  );
  write(
    'utf8_three_bytes.txt',
    _bytes([0x41, 0x42, 0x43]),
    purpose: 'שלושה בתים',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: 'ABC',
  );
  write(
    'utf8_looks_like_utf16.txt',
    Uint8List.fromList(utf8.encode(utf8LooksLikeUtf16Sample)),
    purpose:
        'UTF-8 חוקי שהיוריסטיקת UTF-16 של המימוש הקודם חטפה — רגרסיה של §53',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: utf8LooksLikeUtf16Sample,
    forbidReplacementChar: true,
  );
  write(
    'utf8_truncated_tail.txt',
    _concat([
      Uint8List.fromList(utf8.encode('שלום עולם ')),
      _bytes([0xD7]),
    ]),
    purpose: 'UTF-8 שרצף הבתים האחרון בו קטוע — הזנב נחתך ולא מוחלף ב-U+FFFD',
    band: ConfidenceBand.truncatedTail,
    encoding: TextEncoding.utf8,
    text: 'שלום עולם ',
    forbidReplacementChar: true,
  );
  write(
    'utf8_invalid_middle.txt',
    _concat([
      Uint8List.fromList(utf8.encode('Hello ')),
      _bytes([0xFF, 0xFE]),
      Uint8List.fromList(utf8.encode(' World')),
    ]),
    purpose:
        'בתים שאינם UTF-8 באמצע קובץ ASCII — שני בתים גבוהים אינם עדות '
        'לאף קידוד עברי, ולכן אין הכרעה ודאית',
    band: ConfidenceBand.low,
  );
  write(
    'utf8_bom_invalid_payload.txt',
    _concat([
      _bytes([0xEF, 0xBB, 0xBF]),
      Uint8List.fromList(utf8.encode('Hello ')),
      _bytes([0x80, 0x81]),
      Uint8List.fromList(utf8.encode(' Invalid')),
    ]),
    purpose:
        'BOM של UTF-8 עם מצע פגום: הזיהוי ממשיך למצע, בוודאות נמוכה, '
        'בלי תווי החלפה שקטים (§54)',
    band: ConfidenceBand.low,
    hadBom: true,
    forbidReplacementChar: true,
  );

  // --- UTF-16 --------------------------------------------------------------
  write(
    'utf16le_bom.txt',
    encodeUtf16(unicodeSample, littleEndian: true, bom: true),
    purpose: 'UTF-16LE עם BOM',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf16LE,
    text: unicodeSample,
    hadBom: true,
  );
  write(
    'utf16be_bom.txt',
    encodeUtf16(unicodeSample, littleEndian: false, bom: true),
    purpose: 'UTF-16BE עם BOM',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf16BE,
    text: unicodeSample,
    hadBom: true,
  );
  write(
    'utf16le_no_bom.txt',
    encodeUtf16(unicodeSample, littleEndian: true),
    purpose: 'UTF-16LE בלי BOM — היוריסטיקה',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf16LE,
    text: unicodeSample,
  );
  write(
    'utf16be_no_bom.txt',
    encodeUtf16(unicodeSample, littleEndian: false),
    purpose: 'UTF-16BE בלי BOM — היוריסטיקה',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf16BE,
    text: unicodeSample,
  );
  write(
    'utf16le_crlf.txt',
    encodeUtf16(
      'שורה ראשונה\r\nשורה שניה\r\nסוף\r',
      littleEndian: true,
      bom: true,
    ),
    purpose: 'סיומות שורה ב-UTF-16 (0D 00 0A 00) נשמרות כפי שהן (§65)',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf16LE,
    text: 'שורה ראשונה\r\nשורה שניה\r\nסוף\r',
    hadBom: true,
  );
  write(
    'windows1255_crlf.txt',
    encodeLegacy(
      'שורה ראשונה\r\nשורה שניה\r\nסוף\r',
      TextEncoding.windows1255,
    ),
    purpose: 'סיומות שורה בקידוד עברי מדור קודם נשמרות כפי שהן',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.windows1255,
    text: 'שורה ראשונה\r\nשורה שניה\r\nסוף\r',
  );
  write(
    'utf16le_short.txt',
    encodeUtf16('של', littleEndian: true),
    purpose: 'ארבעה בתים: הטקסט נכון, אך אין די עדות לוודאות (§60)',
    band: ConfidenceBand.low,
    encoding: TextEncoding.utf16LE,
    text: 'של',
  );
  write(
    'utf16be_short.txt',
    encodeUtf16('של', littleEndian: false),
    purpose: 'ארבעה בתים ב-BE',
    band: ConfidenceBand.low,
    encoding: TextEncoding.utf16BE,
    text: 'של',
  );
  write(
    'utf16le_odd_length.txt',
    _concat([
      encodeUtf16('שלום עולם ספר בדיקה', littleEndian: true),
      _bytes([0x05]),
    ]),
    purpose: 'UTF-16LE עם בית עודף — הבית הפגום נחתך',
    band: ConfidenceBand.truncatedTail,
    encoding: TextEncoding.utf16LE,
    text: 'שלום עולם ספר בדיקה',
  );
  write(
    'utf16le_bom_lone_surrogate.txt',
    _concat([
      encodeUtf16('שלום', littleEndian: true, bom: true),
      _bytes([0x00, 0xD8]),
      encodeUtf16(' עולם', littleEndian: true),
    ]),
    purpose: 'BOM של UTF-16LE עם surrogate בודד — פגם מדווח, לא מוסתר',
    band: ConfidenceBand.truncatedTail,
    encoding: TextEncoding.utf16LE,
    hadBom: true,
  );
  write(
    'utf16le_no_bom_cyrillic.txt',
    encodeUtf16(cyrillicSample, littleEndian: true),
    purpose:
        'UTF-16LE בלי BOM בקירילית — כתב שאינו עברית או לטינית מנקד נמוך, '
        'ובלי נתיב הטווחים המוכרים היה יוצא ג׳יבריש',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf16LE,
    text: cyrillicSample,
  );
  write(
    'utf16be_no_bom_greek.txt',
    encodeUtf16(greekSample, littleEndian: false),
    purpose: 'UTF-16BE בלי BOM ביוונית',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf16BE,
    text: greekSample,
  );
  write(
    'utf16le_bom_invalid_beyond_probe.txt',
    _concat([
      encodeUtf16(
        largeHebrewBook(paragraphs: 60),
        littleEndian: true,
        bom: true,
      ),
      _bytes([0x00, 0xD8]),
    ]),
    purpose:
        'BOM של UTF-16LE ו-surrogate בודד מחוץ לחלון הדגימה — אימות המצע '
        'עובר על כל הקובץ, ולכן הפגם מדווח ואינו מוחלף בשקט',
    band: ConfidenceBand.truncatedTail,
    encoding: TextEncoding.utf16LE,
    hadBom: true,
  );
  write(
    'utf8_bom_binary_payload.bin',
    _concat([
      _bytes([0xEF, 0xBB, 0xBF]),
      Uint8List(120),
    ]),
    purpose:
        'BOM של UTF-8 ומצע שעובר אימות אך אינו טקסט — BOM אינו מבטיח ודאות',
    band: ConfidenceBand.low,
    encoding: TextEncoding.utf8,
    hadBom: true,
  );
  write(
    'utf8_invalid_not_truncated_tail.txt',
    _concat([
      Uint8List.fromList(utf8.encode('שלום עולם')),
      _bytes([0xF0, 0x28, 0x29]),
    ]),
    purpose:
        'רצף פגום בסוף הקובץ שאינו קטוע — אסור לחתוך אותו כאילו נגמר הקובץ '
        'ולבלוע את הבתים התקינים שאחריו',
    band: ConfidenceBand.low,
  );
  write(
    'utf16_misleading_nulls.bin',
    _bytes([0x41, 0x00, 0x42, 0x00, 0x43, 0x00, 0x00, 0x00, 0xFF, 0xFE]),
    purpose: 'תבנית בתי-אפס מטעה — בתי אפס לבדם אינם עדות ל-UTF-16 (§17)',
    band: ConfidenceBand.low,
  );

  // --- UTF-32 --------------------------------------------------------------
  write(
    'utf32le_bom.txt',
    encodeUtf32(unicodeSample, littleEndian: true, bom: true),
    purpose: 'UTF-32LE עם BOM — נבדק לפני BOM של UTF-16LE (§10)',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf32LE,
    text: unicodeSample,
    hadBom: true,
  );
  write(
    'utf32be_bom.txt',
    encodeUtf32(unicodeSample, littleEndian: false, bom: true),
    purpose: 'UTF-32BE עם BOM',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf32BE,
    text: unicodeSample,
    hadBom: true,
  );
  write(
    'utf32le_no_bom.txt',
    encodeUtf32(unicodeSample, littleEndian: true),
    purpose: 'UTF-32LE בלי BOM — היוריסטיקה בשער מחמיר (§19)',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf32LE,
    text: unicodeSample,
  );
  write(
    'utf32be_no_bom.txt',
    encodeUtf32(unicodeSample, littleEndian: false),
    purpose: 'UTF-32BE בלי BOM',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf32BE,
    text: unicodeSample,
  );
  write(
    'utf32le_bom_truncated.txt',
    _concat([
      encodeUtf32('שלום עולם', littleEndian: true, bom: true),
      _bytes([0xE9, 0x05]),
    ]),
    purpose: 'UTF-32LE שהיחידה האחרונה בו קטועה',
    band: ConfidenceBand.truncatedTail,
    encoding: TextEncoding.utf32LE,
    text: 'שלום עולם',
    hadBom: true,
  );
  write(
    'utf32_invalid_scalar.bin',
    _bytes([0xFF, 0xFF, 0x11, 0x00, 0x41, 0x00, 0x00, 0x00]),
    purpose: 'נקודת קוד מעל U+10FFFF — אינה UTF-32',
    band: ConfidenceBand.low,
  );
  write(
    'utf32_surrogate_scalar.bin',
    _bytes([0x00, 0xD8, 0x00, 0x00, 0x41, 0x00, 0x00, 0x00]),
    purpose: 'surrogate כנקודת קוד — פסול ב-UTF-32',
    band: ConfidenceBand.low,
  );

  // --- קידודי עברית מדור קודם --------------------------------------------
  write(
    'windows1255_letters.txt',
    encodeLegacy(legacyLettersSample, TextEncoding.windows1255),
    purpose:
        'עברית ללא ניקוד: הטקסט זהה ב-ISO-8859-8, ולכן נבחר Windows-1255 '
        'כברירת מחדל בוודאות בינונית (§29)',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.windows1255,
    text: legacyLettersSample,
    forbidReplacementChar: true,
  );
  write(
    'windows1255_niqqud.txt',
    encodeLegacy(windows1255Sample, TextEncoding.windows1255),
    purpose: 'ניקוד, גרש, גרשיים, שקל ומרכאות — עדות ייחודית ל-Windows-1255',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.windows1255,
    text: windows1255Sample,
    forbidReplacementChar: true,
  );
  write(
    'iso8859_8_letters.txt',
    encodeLegacy(legacyLettersSample, TextEncoding.iso88598),
    purpose:
        'ISO-8859-8 ללא בתים מבדילים — אותם בתים ואותו טקסט כמו Windows-1255',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.windows1255,
    text: legacyLettersSample,
    forbidReplacementChar: true,
  );
  write(
    'iso8859_8_double_low_line.txt',
    encodeLegacy(iso88598Sample, TextEncoding.iso88598),
    purpose: 'הבית 0xDF (U+2017) קיים ב-ISO-8859-8 ואינו קיים ב-Windows-1255',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.iso88598,
    text: iso88598Sample,
    forbidReplacementChar: true,
  );
  write(
    'cp862_letters.txt',
    encodeLegacy(legacyLettersSample, TextEncoding.cp862),
    purpose: 'עברית DOS: ב-Windows-1255 אותם בתים היו סימנים חסרי פשר (§30)',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.cp862,
    text: legacyLettersSample,
    forbidReplacementChar: true,
  );
  write(
    'cp862_box_drawing.txt',
    encodeLegacy(cp862Sample, TextEncoding.cp862),
    purpose: 'מסגרות CP437 סביב עברית — הצורה הנפוצה של קובץ DOS אמיתי',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.cp862,
    text: cp862Sample,
    forbidReplacementChar: true,
  );
  write(
    'unknown_encoding.bin',
    _bytes([
      // בתים שאינם מוגדרים ב-Windows-1255 וב-ISO-8859-8, וב-CP862 הם מסגרות
      // וסימנים בלבד — אף קידוד אינו מסביר אותם כטקסט.
      for (var i = 0; i < 18; i++) ...[
        0xD9,
        0xDA,
        0xDB,
        0xDC,
        0xDD,
        0xDE,
        0xFB,
        0xFC,
      ],
    ]),
    purpose:
        'בתים שאין להם פירוש סביר באף קידוד מוכר — אסור שיקבלו Windows-1255 '
        'בוודאות גבוהה (§59)',
    band: ConfidenceBand.low,
  );

  // --- קלט שאינו טקסט ------------------------------------------------------
  write(
    'empty.txt',
    Uint8List(0),
    purpose: 'קובץ ריק — מדיניות קבועה (§61)',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf8,
    text: '',
  );
  write(
    'only_utf8_bom.txt',
    _bytes([0xEF, 0xBB, 0xBF]),
    purpose: 'קובץ שכולו BOM',
    band: ConfidenceBand.certain,
    encoding: TextEncoding.utf8,
    text: '',
    hadBom: true,
  );
  write(
    'many_nulls.bin',
    Uint8List(100),
    purpose: 'מאה בתי אפס — UTF-8 חוקי מבחינה מבנית, אך אינו טקסט (§36)',
    band: ConfidenceBand.low,
  );
  write(
    'control_characters.bin',
    _bytes([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x0E, 0x0F, 0x10]),
    purpose: 'תווי בקרה בלבד — ASCII חוקי שאינו טקסט',
    band: ConfidenceBand.low,
  );
  write(
    'binary_random.bin',
    _bytes([for (var i = 0; i < 256; i++) i]),
    purpose: 'כל 256 הבתים — קובץ בינארי מובהק',
    band: ConfidenceBand.low,
  );

  // --- קבצים גדולים -------------------------------------------------------
  final bookText = largeHebrewBook();
  write(
    'large_windows1255_book.txt',
    encodeLegacy(bookText, TextEncoding.windows1255),
    purpose: 'ספר שלם ב-ANSI עברית — מפעיל את חלונות הדגימה (§42)',
    band: ConfidenceBand.legacyStrong,
    encoding: TextEncoding.windows1255,
    text: bookText,
    forbidReplacementChar: true,
  );
  write(
    'large_utf16le_no_bom_book.txt',
    encodeUtf16(bookText, littleEndian: true),
    purpose: 'אותו ספר ב-UTF-16LE בלי BOM',
    band: ConfidenceBand.unicodeHeuristic,
    encoding: TextEncoding.utf16LE,
    text: bookText,
  );
  write(
    'large_utf8_book.txt',
    Uint8List.fromList(utf8.encode(bookText)),
    purpose: 'אותו ספר ב-UTF-8 — קו הבסיס לתפוקה',
    band: ConfidenceBand.utf8Strict,
    encoding: TextEncoding.utf8,
    text: bookText,
  );

  File(
    '${directory.path}${Platform.pathSeparator}manifest.json',
  ).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert([
      for (final fixture in fixtures) fixture.toJson(),
    ]),
  );
  return fixtures;
}

void main(List<String> args) {
  final target = Directory(
    args.isEmpty ? 'build/text_encoding_fixtures' : args.first,
  );
  final fixtures = generateTextEncodingFixtures(target);
  stdout.writeln('נוצרו ${fixtures.length} קבצים ב-${target.path}');
}
