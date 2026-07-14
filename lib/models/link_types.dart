/// קבועים ועזרים לסיווג סוגי קישורים, בהתאם ל-14 הסוגים ב-seforim.db v3.
class LinkTypes {
  LinkTypes._();

  static const String commentary = 'COMMENTARY';
  static const String superCommentary = 'SUPER_COMMENTARY';
  static const String targum = 'TARGUM';
  static const String reference = 'REFERENCE';
  static const String source = 'SOURCE';
  static const String midrash = 'MIDRASH';
  static const String quotation = 'QUOTATION';
  static const String mesoratHashas = 'MESORAT_HASHAS';
  static const String einMishpat = 'EIN_MISHPAT';
  static const String diburHamatchil = 'DIBUR_HAMATCHIL';
  static const String parshanut = 'PARSHANUT';
  static const String mishnahInTalmud = 'MISHNAH_IN_TALMUD';
  static const String related = 'RELATED';
  static const String other = 'OTHER';

  /// סוג תלוי חדש (למשל "עין איה") — נחשב כמפרש, לא כהפניה.
  static const String elucidation = 'ELUCIDATION';

  /// סוגי קישור תלויי-טקסט — טקסטים שתלויים בטקסט הבסיס (פירוש/תרגום/מדרש
  /// וכד׳) ומוצגים בפאנל המפרשים. "עין משפט" הוא כלי הפניה ולכן מוצג בקישורים.
  static const Set<String> dependentTextTypes = {
    commentary,
    superCommentary,
    targum,
    midrash,
    parshanut,
    diburHamatchil,
    elucidation,
  };

  /// האם הקישור הוא תלוי-טקסט (מפרש) — מוצג בפאנל המפרשים ולא כהפניה צדדית.
  ///
  /// ההשוואה אינה תלוית רישיות — חלק ממקורות הנתונים עשויים לספק ערכים
  /// באותיות קטנות (כפי שקורה גם בטסטים).
  static bool isDependentTextLink(String? connectionType) {
    if (connectionType == null) return false;
    return dependentTextTypes.contains(connectionType.toUpperCase());
  }

  /// האם הקישור הוא קשר עיון/הפניה (לא מפרש ולא SOURCE הווירטואלי):
  /// reference, quotation, mesorat hashas, ein mishpat, mishnah in talmud,
  /// related, other.
  static bool isReferenceLikeLink(String? connectionType) {
    if (connectionType == null) return false;
    final upper = connectionType.toUpperCase();
    return upper != source && !dependentTextTypes.contains(upper);
  }

  /// `SOURCE` הוא קשר וירטואלי שנבנה בשאילתת inverse ואינו נשמר כשורת link.
  static bool isVirtualSource(String? connectionType) =>
      connectionType?.toUpperCase() == source;
}
