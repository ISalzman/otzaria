import 'package:equatable/equatable.dart';

/// מקור הכותרת
enum HeadingSource {
  /// כותרת שהוגדרה ידנית על ידי המשתמש
  manual,

  /// כותרת שזוהתה אוטומטית מטקסט מודגש
  automatic,

  /// כותרת ממטא-דאטה של הספר
  metadata
}

/// מייצג כותרת בספר
class Heading extends Equatable {
  /// טקסט הכותרת
  final String text;

  /// רמת הכותרת (1-6, כאשר 1 היא הגבוהה ביותר)
  final int level;

  /// מיקום הכותרת בטקסט (offset)
  final int position;

  /// מקור הכותרת
  final HeadingSource source;

  /// מזהה ייחודי (אופציונלי, לשימוש עם מסד נתונים)
  final int? id;

  /// תאריך יצירה
  final DateTime? createdAt;

  const Heading({
    required this.text,
    required this.level,
    required this.position,
    required this.source,
    this.id,
    this.createdAt,
  });

  @override
  List<Object?> get props => [text, level, position, source, id, createdAt];

  /// יוצר עותק של הכותרת עם שינויים
  Heading copyWith({
    String? text,
    int? level,
    int? position,
    HeadingSource? source,
    int? id,
    DateTime? createdAt,
  }) {
    return Heading(
      text: text ?? this.text,
      level: level ?? this.level,
      position: position ?? this.position,
      source: source ?? this.source,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// ממיר לJSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'level': level,
      'position': position,
      'source': source.name,
      'id': id,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// יוצר מ-JSON
  factory Heading.fromJson(Map<String, dynamic> json) {
    return Heading(
      text: json['text'] as String,
      level: json['level'] as int,
      position: json['position'] as int,
      source: HeadingSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => HeadingSource.automatic,
      ),
      id: json['id'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
