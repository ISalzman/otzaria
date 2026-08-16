import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/tabs/models/combined_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/tools/tool_catalog_entry.dart';

/// אייקון סוג הכרטיסיה — משותף לעמודה האנכית ולחלונית חיפוש הכרטיסיות.
///
/// מחזיר `null` לכרטיסיית טקסט רגילה, שאין לה אייקון ייעודי.
Widget? buildTabTypeIcon(
  BuildContext context,
  OpenedTab tab, {
  double size = 16,
  Color? color,
}) {
  final resolved = color ?? Theme.of(context).colorScheme.onSurface;
  if (tab is PdfBookTab) {
    return Icon(
      FluentIcons.document_pdf_16_regular,
      size: size,
      color: resolved,
    );
  }
  if (tab is SearchingTab) {
    return Icon(FluentIcons.search_24_regular, size: size, color: resolved);
  }
  if (tab is CombinedTab) {
    return Icon(
      FluentIcons.split_horizontal_24_regular,
      size: size,
      color: resolved,
    );
  }
  if (tab is ToolTab) {
    return buildToolTabLeadingIcon(
      tab.toolId,
      color: resolved,
      pluginState: context.read<PluginSystemBloc>().state,
    );
  }
  return null;
}

/// אייקון ברירת מחדל לכרטיסיה שאין לה אייקון סוג משלה.
Widget buildTabFallbackIcon(
  BuildContext context, {
  double size = 16,
  Color? color,
}) => Icon(
  FluentIcons.document_24_regular,
  size: size,
  color: color ?? Theme.of(context).colorScheme.onSurface,
);

/// כותרת כרטיסיה בשורה אחת שמוצגת מההתחלה (RTL: מימין) ונדהית רק בקצה הסוף.
///
/// `TextOverflow.fade` מציג בעברית את *סוף* הכותרת, ולכן ההצמדה נעשית ידנית:
/// OverflowBox ברוחב טבעי מיושר ל-start, ClipRect חותך, ו-ShaderMask מדהה.
Widget buildFadedTabTitle(BuildContext context, String title) {
  final isLtr = Directionality.of(context) == TextDirection.ltr;
  return ClipRect(
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: isLtr ? Alignment.centerLeft : Alignment.centerRight,
        end: isLtr ? Alignment.centerRight : Alignment.centerLeft,
        stops: const [0.0, 0.82, 1.0],
        colors: const [Colors.white, Colors.white, Colors.transparent],
      ).createShader(rect),
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minWidth: 0,
        maxWidth: double.infinity,
        child: Text(title, maxLines: 1, softWrap: false),
      ),
    ),
  );
}

/// רוחבי כותרות שנמדדו. המדידה חוזרת בכל שינוי אילוצים — הנפשת רוחב כרטיסיות
/// או שינוי גודל חלון מייצרים אחרת פריסת טקסט מלאה לכל כרטיסיה בכל פריים.
final Map<(String, TextStyle, TextScaler, TextDirection), double>
_titleWidthCache = {};

/// מעל הסף כל המפה מנוקה: המפתחות מגיעים מכותרות כרטיסיות פתוחות, ולכן
/// המדידות נבנות מחדש מיד ובלי עלות מורגשת.
const int _kTitleWidthCacheLimit = 256;

double _measuredTitleWidth(
  String title,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
) {
  final key = (title, style, scaler, direction);
  final cached = _titleWidthCache[key];
  if (cached != null) return cached;

  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();

  if (_titleWidthCache.length >= _kTitleWidthCacheLimit) {
    _titleWidthCache.clear();
  }
  _titleWidthCache[key] = width;
  return width;
}

/// עוטף כותרת כרטיסיה ב-[Tooltip] רק כשיש בו ערך: הכותרת נחתכה ברוחב הזמין,
/// או שההודעה מוסיפה מידע שאינו מוצג (למשל המיקום הנוכחי בספר).
class TabTitleTooltip extends StatelessWidget {
  /// הטקסט שיוצג ב-tooltip.
  final String message;

  /// הכותרת כפי שהיא מרונדרת בכרטיסיה — נמדדת מול הרוחב הזמין.
  final String title;

  /// כשדולק, ה-tooltip מוצג תמיד (מצב מכווץ: מוצג אייקון בלבד).
  final bool alwaysShow;

  final Widget child;

  const TabTitleTooltip({
    super.key,
    required this.message,
    required this.title,
    required this.child,
    this.alwaysShow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (alwaysShow) return Tooltip(message: message, child: child);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _measuredTitleWidth(
          title,
          DefaultTextStyle.of(context).style,
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
        );
        final truncated = width > constraints.maxWidth + 0.5;
        if (!truncated && message == title) return child;
        return Tooltip(message: message, child: child);
      },
    );
  }
}
