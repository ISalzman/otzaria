/// גישה לבוני ה-fixtures הבינאריים מתוך הבדיקות.
///
/// המימוש יושב ב-`tool/src/document_fixtures/` ומשותף למחולל הקורפוס
/// (`tool/generate_document_fixtures.dart`) ולבדיקות. כשהיו שני מימושים,
/// תיקון במבנה עץ הספרייה הוחל רק על אחד מהם והמחולל ייצר קבצים פסולים —
/// ולכן יש כאן re-export ולא העתק.
library;

export '../../../tool/src/document_fixtures/cfb_builder.dart';
export '../../../tool/src/document_fixtures/word_binary_builder.dart';
