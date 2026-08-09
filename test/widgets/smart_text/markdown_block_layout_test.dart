import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/smart_text_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

final _horizontalScroll = find.byWidgetPredicate(
  (widget) =>
      widget is SingleChildScrollView &&
      widget.scrollDirection == Axis.horizontal,
);

void main() {
  // רגרסיה: fwfh עוטף <pre> ו-<table> ב-SingleChildScrollView אופקי. תחת RTL
  // הוא מצמיד את התוכן לימין ומאפס את היישור הפנימי — בלוק קוד הופיע מוזח
  // מהשמאל ורוחב הטבלה לא התפרס.
  group('SmartTextWidget — פריסת בלוקי Markdown', () {
    testWidgets('בלוק קוד של Markdown אינו נעטף בגלילה אופקית', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text:
                '<pre dir="ltr" class="md-block">'
                '<code dir="ltr">final value = 1;</code></pre>',
            settings: RenderSettings(fontSize: 20),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_horizontalScroll, findsNothing);
      final code = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((w) => w.text.toPlainText().contains('final value = 1;'));
      expect(code.textDirection, TextDirection.ltr);
      expect(code.textAlign, TextAlign.left);
    });

    testWidgets('טבלת Markdown אינה נעטפת בגלילה אופקית', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text:
                '<table dir="ltr" class="md-block"><tbody><tr>'
                '<td dir="ltr">key</td><td dir="ltr">value</td>'
                '</tr></tbody></table>',
            settings: RenderSettings(fontSize: 20),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_horizontalScroll, findsNothing);
    });

    testWidgets('בלוק קוד בספר רגיל שומר על הגלילה האופקית', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text: '<pre><code>final value = 1;</code></pre>',
            settings: RenderSettings(fontSize: 20),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_horizontalScroll, findsOneWidget);
    });
  });
}
