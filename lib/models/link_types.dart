/// Constants for link connection types
class LinkTypes {
  LinkTypes._();

  /// Commentary link type - indicates a commentary relationship
  static const String commentary = 'COMMENTARY';

  /// Targum link type - indicates a translation/targum relationship
  static const String targum = 'TARGUM';

  /// Reference link type - indicates a general reference
  static const String reference = 'REFERENCE';

  /// Checks if a connection type is a commentary or targum
  ///
  /// ההשוואה אינה תלוית רישיות — חלק ממקורות הנתונים עשויים לספק
  /// 'commentary'/'targum' באותיות קטנות (כפי שקורה גם בטסטים).
  static bool isCommentaryOrTargum(String? connectionType) {
    if (connectionType == null) return false;
    final upper = connectionType.toUpperCase();
    return upper == commentary || upper == targum;
  }
}
