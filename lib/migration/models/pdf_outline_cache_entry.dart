import 'dart:convert';

/// רשומת cache מתמשך ל-outline של קובץ PDF חיצוני.
class PdfOutlineCacheEntry {
  final String filePath;
  final int fileSize;
  final int lastModified;
  final String outlineJson;
  final int createdAt;
  final int accessedAt;

  const PdfOutlineCacheEntry({
    required this.filePath,
    required this.fileSize,
    required this.lastModified,
    required this.outlineJson,
    required this.createdAt,
    required this.accessedAt,
  });

  factory PdfOutlineCacheEntry.fromMap(Map<String, dynamic> map) {
    return PdfOutlineCacheEntry(
      filePath: map['filePath'] as String,
      fileSize: map['fileSize'] as int? ?? 0,
      lastModified: map['lastModified'] as int? ?? 0,
      outlineJson: map['outlineJson'] as String,
      createdAt: map['createdAt'] as int? ?? 0,
      accessedAt: map['accessedAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileSize': fileSize,
      'lastModified': lastModified,
      'outlineJson': outlineJson,
      'createdAt': createdAt,
      'accessedAt': accessedAt,
    };
  }

  PdfOutlineCacheEntry copyWith({
    String? filePath,
    int? fileSize,
    int? lastModified,
    String? outlineJson,
    int? createdAt,
    int? accessedAt,
  }) {
    return PdfOutlineCacheEntry(
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      lastModified: lastModified ?? this.lastModified,
      outlineJson: outlineJson ?? this.outlineJson,
      createdAt: createdAt ?? this.createdAt,
      accessedAt: accessedAt ?? this.accessedAt,
    );
  }

  /// ממיר את ה-JSON השמור לרשימת outline entries.
  List<(String, String, int)> decodeEntries() =>
      decodeOutlineEntries(outlineJson);

  /// ממיר רשימת outline entries ל-JSON יציב לשמירה ב-DB.
  static String encodeOutlineEntries(List<(String, String, int)> entries) {
    return jsonEncode([
      for (final (normalizedTitle, originalTitle, pageNumber) in entries)
        {
          'n': normalizedTitle,
          'o': originalTitle,
          'p': pageNumber,
        }
    ]);
  }

  /// מפענח outline entries מ-JSON שמור.
  static List<(String, String, int)> decodeOutlineEntries(String outlineJson) {
    final decoded = jsonDecode(outlineJson);
    if (decoded is! List) return const [];

    return [
      for (final item in decoded)
        if (item is Map)
          (
            item['n'] as String? ?? '',
            item['o'] as String? ?? '',
            item['p'] as int? ?? 0,
          ),
    ];
  }

  @override
  String toString() =>
      'PdfOutlineCacheEntry(filePath: $filePath, fileSize: $fileSize, '
      'lastModified: $lastModified, createdAt: $createdAt, accessedAt: $accessedAt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PdfOutlineCacheEntry &&
        other.filePath == filePath &&
        other.fileSize == fileSize &&
        other.lastModified == lastModified &&
        other.outlineJson == outlineJson &&
        other.createdAt == createdAt &&
        other.accessedAt == accessedAt;
  }

  @override
  int get hashCode => Object.hash(
        filePath,
        fileSize,
        lastModified,
        outlineJson,
        createdAt,
        accessedAt,
      );
}
