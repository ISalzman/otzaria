import 'package:flutter/widgets.dart';
import 'package:otzaria/text_book/utils/reading_segments.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

ItemPosition? _findPosition(ItemPositionsListener listener, int segmentIndex) {
  for (final position in listener.itemPositions.value) {
    if (position.index == segmentIndex) {
      return position;
    }
  }
  return null;
}

/// גלילה לשורת מקור [lineIndex] תוך תרגום אוטומטי לסגמנט.
///
/// [intraLineFraction] (0..1) הוא מיקום היעד בתוך השורה (למשל מילת חיפוש בתוך
/// פסקה ארוכה). כשהסגמנט כבר גלוי מתבצעת גלילה יחסית אחת ישירות אל היעד — בלי
/// קפיצה לתחילת הסגמנט ואז תיקון — כדי שלא ייראה "זיגזג" כשמתחילים מתחת ליעד.
Future<void> scrollToSourceLine({
  required ItemScrollController scrollController,
  required ScrollOffsetController? scrollOffsetController,
  required ItemPositionsListener? positionsListener,
  required List<ReadingSegment> segments,
  required int lineIndex,
  required double viewportExtent,
  double alignment = 0.05,
  double intraLineFraction = 0,
  Duration duration = const Duration(milliseconds: 250),
  Curve curve = Curves.ease,
}) async {
  if (segments.isEmpty || !scrollController.isAttached) {
    return;
  }

  final safeLineIndex = lineIndex
      .clamp(
        segments.first.startLineIndex,
        segments.last.sourceLineIndices.last,
      )
      .toInt();
  final segmentIndex = segmentIndexForLine(segments, safeLineIndex);
  final segment = segments[segmentIndex];
  final fraction = lineFractionWithinSegment(
    segment,
    safeLineIndex,
    intraLineFraction: intraLineFraction,
  );

  Future<void> scrollToSegment() async {
    if (duration == Duration.zero) {
      scrollController.jumpTo(index: segmentIndex, alignment: alignment);
    } else {
      await scrollController.scrollTo(
        index: segmentIndex,
        alignment: alignment,
        duration: duration,
        curve: curve,
      );
    }
  }

  // ללא דיוק תוך-סגמנט — גלילה רגילה לתחילת הסגמנט.
  if (fraction <= 0 ||
      scrollOffsetController == null ||
      positionsListener == null ||
      viewportExtent <= 0) {
    await scrollToSegment();
    return;
  }

  // משך הגלילה היחסית. `animateScroll` עוטף את `ScrollController.animateTo`,
  // שזורק assert על `Duration.zero`; לכן מצב מיידי מתורגם לדיוק עדין קצר.
  final fineDuration =
      duration == Duration.zero ? const Duration(milliseconds: 120) : duration;

  // הסגמנט כבר גלוי — גלילה יחסית אחת ישירות אל היעד, בלי קפיצה ביניים.
  final visible = _findPosition(positionsListener, segmentIndex);
  if (visible != null) {
    final extent =
        (visible.itemTrailingEdge - visible.itemLeadingEdge) * viewportExtent;
    if (extent.isFinite && extent > 0) {
      final delta = visible.itemLeadingEdge * viewportExtent +
          fraction * extent -
          alignment * viewportExtent;
      await scrollOffsetController.animateScroll(
        offset: delta,
        duration: fineDuration,
        curve: curve,
      );
      return;
    }
  }

  // הסגמנט אינו גלוי — גלילה אליו, מדידה, ואז דיוק עדין אל היעד.
  await scrollToSegment();
  await WidgetsBinding.instance.endOfFrame;
  final measured = _findPosition(positionsListener, segmentIndex);
  if (measured == null) {
    return;
  }
  final extent =
      (measured.itemTrailingEdge - measured.itemLeadingEdge) * viewportExtent;
  if (!extent.isFinite || extent <= 0) {
    return;
  }
  await scrollOffsetController.animateScroll(
    offset: extent * fraction,
    duration: const Duration(milliseconds: 120),
    curve: Curves.easeOut,
  );
}
