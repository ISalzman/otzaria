import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/utils/text/html_link_handler.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/simple_inline_html.dart';
import 'package:otzaria/widgets/smart_text/text_renderer_service.dart';

/// ווידג'ט חכם להצגת טקסט עברי
///
/// מרכז את כל הלוגיקה של עיבוד והצגת טקסט במקום אחד:
/// - הסרת ניקוד וטעמים
/// - החלפת שמות קדושים
/// - הדגשת תוצאות חיפוש
/// - עיצוב סוגריים
/// - טיפול בקישורים פנימיים
class SmartTextWidget extends StatelessWidget {
  /// הטקסט הגולמי להצגה (יכול להכיל HTML)
  final String text;

  /// הגדרות הרינדור
  final RenderSettings settings;

  /// callback לפתיחת ספר/טאב
  final Function(OpenedTab)? onOpenBook;

  /// callback ללחיצה על סימון הערה אישית inline.
  /// מקבל את אינדקס השורה (0-based) שעליה ההערה.
  final void Function(int lineIndex)? onNoteTap;

  /// callback ללחיצה על עוגן-מילה (`otzaria://anchor`). מקבל את ה-URL המלא;
  /// מזהה את הקישור ומקפיץ תצוגה מקדימה של המפרש.
  final void Function(String url)? onAnchorTap;

  /// מפתח ייחודי לווידג'ט (לאופטימיזציה)
  final Key? widgetKey;

  /// מצב רינדור של HtmlWidget
  final RenderMode renderMode;

  const SmartTextWidget({
    super.key,
    required this.text,
    required this.settings,
    this.onOpenBook,
    this.onNoteTap,
    this.onAnchorTap,
    this.widgetKey,
    this.renderMode = RenderMode.column,
  });

  @override
  Widget build(BuildContext context) {
    // עיבוד הטקסט דרך השירות המרכזי
    final processedHtml = TextRendererService.processText(text, settings);
    final textStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
      fontWeight: settings.fontWeight,
      height: settings.lineHeight,
    );

    // מסלול מהיר: רוב השורות הן טקסט פשוט (או עם תגי עיצוב בסיסיים) —
    // רינדור ישיר ב-Text.rich חוסך את מלוא עלות הפרסור של HtmlWidget.
    if (renderMode == RenderMode.column) {
      final simpleSpan = SimpleInlineHtml.tryParse(processedHtml, textStyle);
      if (simpleSpan != null) {
        if (simpleSpan.toPlainText().isEmpty) {
          return const SizedBox.shrink();
        }
        // רוחב מלא כמו <div> בלוק ב-HtmlWidget - אחרת מסכים שעוטפים שורה
        // ב-Center (הגבלת רוחב קריאה) ימרכזו שורות קצרות בטעות.
        return SizedBox(
          key: widgetKey,
          width: double.infinity,
          child: Text.rich(
            simpleSpan,
            style: textStyle,
            textAlign:
                settings.justifyText ? TextAlign.justify : TextAlign.right,
          ),
        );
      }
    }

    // עוגן-מילה נפלט כ-<a> לחיץ; fwfh צובע <a> בצבע primary. מחזירים לצבע
    // הטקסט הסביבתי בערך מפורש (inherit לא נתמך בפרסר הצבעים של fwfh).
    final colorScheme = Theme.of(context).colorScheme;
    String toCssHex(Color color) =>
        '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
    final anchorColorCss = toCssHex(
        DefaultTextStyle.of(context).style.color ?? colorScheme.onSurface);
    final anchorActiveColorCss = toCssHex(colorScheme.primary);
    final anchorActiveBgCss = toCssHex(colorScheme.primaryContainer);

    return HtmlWidget(
      TextRendererService.wrapWithRtlDiv(processedHtml,
          justifyText: settings.justifyText),
      key: widgetKey,
      renderMode: renderMode,
      textStyle: textStyle,
      customStylesBuilder: (dom.Element element) {
        if (element.localName == 'span' &&
            element.classes.contains('footnote-marker-number')) {
          return {
            'font-size': '0.75em',
            'font-style': 'italic',
            'position': 'relative',
            'top': '-0.55em',
          };
        }
        // סמני עוגן-מילה (link_anchor): אות קטנה מורמת (עוגן-נקודה) או קו
        // תחתון על טווח מצוטט (עוגן-טווח), עם וריאנט טיפוגרפי קבוע לכל מפרש
        // (ראו anchorStyleIndexByCommentator). כ-<a> לחיץ — מנטרלים את עיצוב
        // הקישור המובנה (צבע/קו) כדי שהמראה יישאר זהה לסמן הלא-לחיץ.
        if ((element.localName == 'span' || element.localName == 'a') &&
            element.classes.contains('link-anchor')) {
          final style = <String, String>{
            'font-size': '0.7em',
            'position': 'relative',
            'top': '-0.55em',
            'white-space': 'nowrap',
            'color': anchorColorCss,
            'text-decoration': 'none',
            ..._linkAnchorVariantStyle(element),
          };
          // האות שחלונית התצוגה שלה פתוחה — מודגשת (צבע primary + רקע + מודגש).
          if (element.classes.contains('link-anchor-active')) {
            style['color'] = anchorActiveColorCss;
            style['background-color'] = anchorActiveBgCss;
            style['font-weight'] = 'bold';
          }
          return style;
        }
        if (element.localName == 'span' &&
            element.classes.contains('link-anchor-range')) {
          return <String, String>{
            'text-decoration': 'underline',
            ..._linkAnchorVariantStyle(element),
          };
        }
        return null;
      },
      onTapUrl: (onOpenBook != null || onNoteTap != null || onAnchorTap != null)
          ? (url) async {
              // עוגן-מילה — תצוגה מקדימה של המפרש, לפני שאר הקישורים.
              if (url.startsWith('otzaria://anchor') && onAnchorTap != null) {
                onAnchorTap!(url);
                return true;
              }
              // סימון הערה אישית inline — נטפל לפני שאר הקישורים.
              if (url.startsWith('otzaria://note')) {
                final lineIndex =
                    int.tryParse(Uri.parse(url).queryParameters['line'] ?? '');
                if (lineIndex != null) {
                  onNoteTap?.call(lineIndex);
                }
                return true;
              }
              if (onOpenBook == null) return false;
              return await HtmlLinkHandler.handleLink(
                context,
                url,
                (tab) => onOpenBook!(tab),
              );
            }
          : null,
    );
  }
}

/// הווריאנט הטיפוגרפי של סמן/טווח עוגן-מילה לפי מחלקת ה-style שהוקצתה למפרש.
Map<String, String> _linkAnchorVariantStyle(dom.Element element) {
  if (element.classes.contains('link-anchor-0')) {
    return const {'font-weight': 'bold'};
  }
  if (element.classes.contains('link-anchor-1')) {
    return const {'font-style': 'italic'};
  }
  if (element.classes.contains('link-anchor-2')) {
    return const {'font-weight': 'bold', 'font-style': 'italic'};
  }
  if (element.classes.contains('link-anchor-3')) {
    return const {'font-family': 'NotoRashiHebrew'};
  }
  if (element.classes.contains('link-anchor-4')) {
    return const {'font-family': 'NotoRashiHebrew', 'font-weight': 'bold'};
  }
  if (element.classes.contains('link-anchor-5')) {
    return const {'text-decoration': 'underline'};
  }
  return const {};
}

/// גרסה פשוטה יותר של SmartTextWidget שמקבלת פרמטרים בודדים
/// במקום RenderSettings - נוחה למקרים פשוטים
class SimpleSmartText extends StatelessWidget {
  final String text;
  final double fontSize;
  final String? fontFamily;
  final bool removeNikud;
  final bool removeTeamim;
  final bool replaceHolyNames;
  final String searchText;
  final Function(OpenedTab)? onOpenBook;
  final Key? widgetKey;

  const SimpleSmartText({
    super.key,
    required this.text,
    required this.fontSize,
    this.fontFamily,
    this.removeNikud = false,
    this.removeTeamim = true,
    this.replaceHolyNames = false,
    this.searchText = '',
    this.onOpenBook,
    this.widgetKey,
  });

  @override
  Widget build(BuildContext context) {
    return SmartTextWidget(
      text: text,
      settings: RenderSettings(
        fontSize: fontSize,
        fontFamily: fontFamily,
        removeNikud: removeNikud,
        removeTeamim: removeTeamim,
        replaceHolyNames: replaceHolyNames,
        searchText: searchText,
      ),
      onOpenBook: onOpenBook,
      widgetKey: widgetKey,
    );
  }
}
