import 'dart:typed_data';

import 'sfnt_metadata_reader_stub.dart'
    if (dart.library.io) 'sfnt_metadata_reader_io.dart'
    as impl;

/// קורא מקובץ גופן רק את הטבלאות שנדרשות לזיהוי (cmap/OS-2/head/name/fvar),
/// ומדלג על טבלאות הגליפים — שהן כמעט כל נפח הקובץ.
class SfntMetadataReader {
  SfntMetadataReader._();

  /// מחזיר buffer שבו ההיסטים זהים לקובץ המקורי, אך רק טווחי הטבלאות
  /// הדרושות מלאים בנתונים (השאר אפסים). `null` כשהקובץ אינו קריא או פגום.
  static Uint8List? readSync(String path) => impl.readMetadataSync(path);
}
