import 'package:otzaria/models/heading.dart';

/// כותרת שזוהתה או נוצרה בספר - לשמירה
///
/// הערה: בגרסה זו משתמשים ב-JSON לשמירה במקום Isar
/// כדי להימנע מבעיות תאימות עם build_runner
class DetectedHeading {
  int? id;
  int bookId;
  String text;
  int level;
  int position;
  HeadingSource source;
  DateTime createdAt;

  DetectedHeading({
    this.id,
    required this.bookId,
    required this.text,
    required this.level,
    required this.position,
    required this.source,
    required this.createdAt,
  });

  /// ממיר ל-Heading
  Heading toHeading() {
    return Heading(
      id: id,
      text: text,
      level: level,
      position: position,
      source: source,
      createdAt: createdAt,
    );
  }

  /// יוצר מ-Heading
  static DetectedHeading fromHeading(Heading heading, int bookId) {
    return DetectedHeading(
      id: heading.id,
      bookId: bookId,
      text: heading.text,
      level: heading.level,
      position: heading.position,
      source: heading.source,
      createdAt: heading.createdAt ?? DateTime.now(),
    );
  }

  /// ממיר ל-JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'text': text,
      'level': level,
      'position': position,
      'source': source.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// יוצר מ-JSON
  factory DetectedHeading.fromJson(Map<String, dynamic> json) {
    return DetectedHeading(
      id: json['id'] as int?,
      bookId: json['bookId'] as int,
      text: json['text'] as String,
      level: json['level'] as int,
      position: json['position'] as int,
      source: HeadingSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => HeadingSource.automatic,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
