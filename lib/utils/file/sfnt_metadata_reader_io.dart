import 'dart:io';
import 'dart:typed_data';

/// הטבלאות שפרסרי הגופנים קוראים. השאר (glyf/CFF/GPOS/hmtx…) אינן משתתפות
/// בזיהוי הגופן ומהוות כמעט את כל נפח הקובץ.
const Set<String> _metadataTags = {'cmap', 'OS/2', 'head', 'name', 'fvar'};

/// רצפת אורך לטבלאות שנקראות בהן שדות בהיסט קבוע — אורך מוצהר קטן מדי
/// (קובץ פגום) היה גורם לשדה להיקרא כאפס במקום כערכו.
const Map<String, int> _minTableLength = {'OS/2': 96, 'head': 64};

Uint8List? readMetadataSync(String path) {
  RandomAccessFile? raf;
  try {
    raf = File(path).openSync();
    final fileLength = raf.lengthSync();
    if (fileLength < 12) return null;

    // (start, end) בהיסטים מוחלטים — הם נשמרים ב-buffer כדי שהפרסרים
    // יוכלו לקרוא בדיוק כמו על הקובץ המלא.
    final starts = <int>[];
    final ends = <int>[];
    void want(int start, int length) {
      if (start < 0 || length <= 0 || start >= fileLength) return;
      starts.add(start);
      ends.add(start + length > fileLength ? fileLength : start + length);
    }

    final header = _readAt(raf, 0, 12);
    if (header == null) return null;

    final bases = <int>[];
    if (_tagAt(header, 0) == 'ttcf') {
      final numFonts = _u32(header, 8);
      if (numFonts <= 0 || numFonts > 0xFFFF) return null;
      final ttcHeaderLength = 12 + numFonts * 4;
      final ttcHeader = _readAt(raf, 0, ttcHeaderLength);
      if (ttcHeader == null) return null;
      want(0, ttcHeaderLength);
      for (var i = 0; i < numFonts; i++) {
        final offset = _u32(ttcHeader, 12 + i * 4);
        if (offset > 0 && offset < fileLength) bases.add(offset);
      }
    } else {
      bases.add(0);
    }

    for (final base in bases) {
      final offsetTable = _readAt(raf, base, 12);
      if (offsetTable == null) continue;
      final numTables = _u16(offsetTable, 4);
      if (numTables <= 0) continue;
      final directoryLength = 12 + numTables * 16;
      final directory = _readAt(raf, base, directoryLength);
      if (directory == null) continue;
      want(base, directoryLength);
      for (var i = 0; i < numTables; i++) {
        final record = 12 + i * 16;
        final tag = _tagAt(directory, record);
        if (!_metadataTags.contains(tag)) continue;
        final declared = _u32(directory, record + 12);
        final floor = _minTableLength[tag] ?? 0;
        want(_u32(directory, record + 8), declared > floor ? declared : floor);
      }
    }

    if (starts.isEmpty) return null;

    var bufferLength = 0;
    for (final end in ends) {
      if (end > bufferLength) bufferLength = end;
    }
    final buffer = Uint8List(bufferLength);
    for (var i = 0; i < starts.length; i++) {
      raf.setPositionSync(starts[i]);
      raf.readIntoSync(buffer, starts[i], ends[i]);
    }
    return buffer;
  } catch (_) {
    return null;
  } finally {
    try {
      raf?.closeSync();
    } catch (_) {}
  }
}

Uint8List? _readAt(RandomAccessFile raf, int offset, int length) {
  if (offset < 0 || length <= 0) return null;
  raf.setPositionSync(offset);
  final bytes = raf.readSync(length);
  return bytes.length == length ? bytes : null;
}

int _u16(Uint8List d, int o) =>
    (o + 2 > d.length) ? -1 : (d[o] << 8) | d[o + 1];

int _u32(Uint8List d, int o) => (o + 4 > d.length)
    ? -1
    : (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3];

String _tagAt(Uint8List d, int o) =>
    (o + 4 > d.length) ? '' : String.fromCharCodes(d.sublist(o, o + 4));
