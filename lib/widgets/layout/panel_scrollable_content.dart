// lib/widgets/layout/panel_scrollable_content.dart
//
// [PanelScrollableContent] — אזור תוכן גלילה עם Scrollbar מצמוד לקצה.
//
// פטרן משותף לדיאלוגים ופאנלים:
//  • Scrollbar מתפרס עד לגבול ה-widget (הקורא לא מוסיף padding אופקי כלפי חוץ)
//  • crossAxisMargin: 2 — זהה ל-adaptive_side_pane, מרחק מקסימלי מהתוכן
//  • [padding] מוחל בתוך ה-SingleChildScrollView — כולל המרווח לצד הגלילה
//
// **שימוש:**
// ```dart
// // ה-Container/Padding החיצוני ללא padding אופקי:
// Expanded(
//   child: PanelScrollableContent(
//     padding: const EdgeInsets.symmetric(horizontal: 16),
//     child: MyContent(),
//   ),
// )
// ```

import 'package:flutter/material.dart';

class PanelScrollableContent extends StatefulWidget {
  /// תוכן הגלילה.
  final Widget child;

  /// padding שיוחל בתוך ה-SingleChildScrollView.
  /// ברירת מחדל: 16px אופקי — שמרחק זה הוא גם המרווח שמפריד בין הגלילה לתוכן.
  final EdgeInsetsGeometry padding;

  const PanelScrollableContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<PanelScrollableContent> createState() => _PanelScrollableContentState();
}

class _PanelScrollableContentState extends State<PanelScrollableContent> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // crossAxisMargin:2 — זהה ל-adaptive_side_pane; צמוד לגבול עם רווח קל.
    return ScrollbarTheme(
      data: const ScrollbarThemeData(crossAxisMargin: 2),
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
