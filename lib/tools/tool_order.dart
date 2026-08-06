/// סדר מזהים חדש לאחר הפלת [sourceId] על קו ההוספה שלפני [targetId]
/// (`placeAfter: false`) או שאחריו (`placeAfter: true`).
///
/// מזהה חסר או הפלה על עצמו מחזירים את הסדר כמות שהוא.
List<String> reorderIdsAroundTarget(
  List<String> ids,
  String sourceId,
  String targetId, {
  required bool placeAfter,
}) {
  final result = List<String>.from(ids);
  if (sourceId == targetId) return result;
  final sourceIndex = result.indexOf(sourceId);
  if (sourceIndex < 0 || !result.contains(targetId)) return result;
  result.removeAt(sourceIndex);
  // מחפשים את היעד *אחרי* הסרת המקור, אחרת האינדקס זז בפריט אחד.
  final targetIndex = result.indexOf(targetId);
  result.insert(placeAfter ? targetIndex + 1 : targetIndex, sourceId);
  return result;
}
