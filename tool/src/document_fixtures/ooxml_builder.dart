import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// אורז חבילת OOXML של Word (DOCX/DOCM/DOTX/DOTM).
///
/// **מקור יחיד** למחולל הקורפוס ולבדיקות ה-golden. כל החלקים אופציונליים —
/// מסמך מינימלי הוא `document.xml` בלבד, וכל חלק שנוסף מופיע גם ב-rels
/// המתאים לו.
Uint8List buildOoxmlPackage({
  required String document,
  String? styles,
  String? numbering,
  String? footnotes,
  String? rels,
  Map<String, Uint8List> media = const {},
}) {
  final archive = Archive();
  void add(String name, List<int> bytes) =>
      archive.addFile(ArchiveFile(name, bytes.length, bytes));

  add('[Content_Types].xml', utf8.encode(_contentTypes));
  add('_rels/.rels', utf8.encode(_packageRels));
  add('word/document.xml', utf8.encode(document));
  if (styles != null) add('word/styles.xml', utf8.encode(styles));
  if (numbering != null) add('word/numbering.xml', utf8.encode(numbering));
  if (footnotes != null) add('word/footnotes.xml', utf8.encode(footnotes));
  if (rels != null) add('word/_rels/document.xml.rels', utf8.encode(rels));
  media.forEach((name, bytes) => add('word/media/$name', bytes));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
    'content-types">'
    '<Default Extension="rels" ContentType="application/vnd.'
    'openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Default Extension="png" ContentType="image/png"/>'
    '</Types>';

const _packageRels =
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
    'relationships"><Relationship Id="rId1" Type="http://schemas.'
    'openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="word/document.xml"/></Relationships>';
