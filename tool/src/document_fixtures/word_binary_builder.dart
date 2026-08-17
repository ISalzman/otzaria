import 'dart:typed_data';

import 'cfb_builder.dart';

/// חתיכת טקסט אחת כפי ש-Word שומר אותה ב-piece table.
///
/// [compressed] מדמה קטע שנכנס ל-cp1252 (בית לתו); אחרת הקטע נשמר כ-UTF-16 —
/// וזה המסלול שבו עברית תמיד עוברת, כי אינה נכנסת ל-cp1252.
class WordPiece {
  final String text;
  final bool compressed;

  const WordPiece(this.text, {this.compressed = false});
}

/// בונה מסמך Word בינארי (‎.doc‎ / ‎.dot‎) תקין: מכולת CFB עם זרם
/// `WordDocument` שבראשו FIB, וזרם `1Table` עם CLX ו-piece table אמיתיים.
///
/// **מקור יחיד** למחולל הקורפוס ולבדיקות — ראו [CfbBuilder].
Uint8List buildWordBinary(
  List<WordPiece> pieces, {
  bool template = false,
  bool encrypted = false,
  int wIdent = 0xA5EC,
  int nFib = 193,
  int? ccpTextOverride,
  bool omitClx = false,
  bool omitTableStream = false,
  bool useTable1 = true,
  int? outOfRangePiece,
}) {
  const textBase = 0x800; // אחרי ה-FIB, בגבול נוח

  final body = BytesBuilder();
  final offsets = <int>[];
  final counts = <int>[];
  for (final piece in pieces) {
    offsets.add(textBase + body.length);
    counts.add(piece.text.length);
    body.add(
      piece.compressed
          ? Uint8List.fromList(piece.text.codeUnits)
          : _utf16(piece.text),
    );
  }
  final bodyBytes = body.takeBytes();
  final totalCharacters = counts.fold<int>(0, (a, b) => a + b);

  // מדמה קובץ קטוע: ההיסט הפיזי של החתיכה מפנה מחוץ לזרם `WordDocument`.
  if (outOfRangePiece != null && outOfRangePiece < offsets.length) {
    offsets[outOfRangePiece] = 0x1FFFFF00;
  }

  final clx = _buildClx(pieces, offsets, counts);
  const clxOffset = 64; // ריפוד לפני ה-CLX, כמו בקבצים אמיתיים
  final table = Uint8List(clxOffset + clx.length)
    ..setRange(clxOffset, clxOffset + clx.length, clx);

  final wordDocument = Uint8List(textBase + bodyBytes.length)
    ..setRange(textBase, textBase + bodyBytes.length, bodyBytes);
  _writeFib(
    wordDocument,
    wIdent: wIdent,
    nFib: nFib,
    template: template,
    encrypted: encrypted,
    useTable1: useTable1,
    ccpText: ccpTextOverride ?? totalCharacters,
    fcClx: omitClx ? 0 : clxOffset,
    lcbClx: omitClx ? 0 : clx.length,
  );

  return CfbBuilder({
    'WordDocument': wordDocument,
    if (!omitTableStream) (useTable1 ? '1Table' : '0Table'): table,
  }).build();
}

Uint8List _utf16(String text) {
  final bytes = Uint8List(text.length * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < text.length; i++) {
    view.setUint16(i * 2, text.codeUnitAt(i), Endian.little);
  }
  return bytes;
}

/// CLX = ‏Pcdt עם PlcPcd: ‏(n+1) מיקומי CP ואחריהם n מתארי חתיכה בני 8 בתים.
Uint8List _buildClx(
  List<WordPiece> pieces,
  List<int> offsets,
  List<int> counts,
) {
  final n = pieces.length;
  final plc = Uint8List(4 * (n + 1) + 8 * n);
  final view = ByteData.sublistView(plc);

  var cp = 0;
  for (var i = 0; i < n; i++) {
    view.setUint32(i * 4, cp, Endian.little);
    cp += counts[i];
  }
  view.setUint32(n * 4, cp, Endian.little);

  final pcdBase = (n + 1) * 4;
  for (var i = 0; i < n; i++) {
    // ההיסט של חתיכה דחוסה נשמר כפול, וסיבית 30 מסמנת את הדחיסה.
    final fc = pieces[i].compressed
        ? (offsets[i] * 2) | 0x40000000
        : offsets[i];
    view.setUint32(pcdBase + i * 8 + 2, fc, Endian.little);
  }

  final out = BytesBuilder()..addByte(0x02); // clxt = Pcdt
  final size = Uint8List(4);
  ByteData.sublistView(size).setUint32(0, plc.length, Endian.little);
  return (out
        ..add(size)
        ..add(plc))
      .takeBytes();
}

/// כותב FIB במבנה משתנה-אורך: כל קטע מצהיר על גודלו ממש לפניו.
void _writeFib(
  Uint8List stream, {
  required int wIdent,
  required int nFib,
  required bool template,
  required bool encrypted,
  required bool useTable1,
  required int ccpText,
  required int fcClx,
  required int lcbClx,
}) {
  const csw = 14;
  const cslw = 22;
  const cbRgFcLcb = 93;

  final view = ByteData.sublistView(stream);
  view.setUint16(0x00, wIdent, Endian.little);
  view.setUint16(0x02, nFib, Endian.little);
  view.setUint16(0x06, 0x040D, Endian.little); // lid: עברית

  var flags = 0;
  if (useTable1) flags |= 0x0200; // fWhichTblStm
  if (template) flags |= 0x0001; // fDot
  if (encrypted) flags |= 0x0100; // fEncrypted
  view.setUint16(0x0A, flags, Endian.little);

  view.setUint16(0x20, csw, Endian.little);
  final cslwOffset = 0x22 + csw * 2;
  view.setUint16(cslwOffset, cslw, Endian.little);

  final fibRgLwOffset = cslwOffset + 2;
  view.setUint32(fibRgLwOffset + 3 * 4, ccpText, Endian.little);

  final cbRgFcLcbOffset = fibRgLwOffset + cslw * 4;
  view.setUint16(cbRgFcLcbOffset, cbRgFcLcb, Endian.little);

  // fcClx/lcbClx הם הזוג ה-34 (אינדקס 33) בטבלת המצביעים.
  final clxPair = cbRgFcLcbOffset + 2 + 33 * 8;
  view.setUint32(clxPair, fcClx, Endian.little);
  view.setUint32(clxPair + 4, lcbClx, Endian.little);
}
