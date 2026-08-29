import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_fonts.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/smart_text_widget.dart';

/// שורה מתוך בראשית — עם טעמים, ועם ניקוד בלבד.
const String _withTaamim = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים';
const String _nikudOnly = 'בְּרֵאשִׁית בָּרָא אֱלֹהִים';

void main() {
  group('נפילה לגופן תומך-טעמים ברינדור הטקסט', () {
    testWidgets('גופן ללא טעמים מוחלף בשורה שיש בה טעמים', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text: _withTaamim,
            settings: RenderSettings(
              fontSize: 20,
              fontFamily: 'Rubik',
              removeTeamim: false,
            ),
          ),
        ),
      );

      expect(_renderedFontFamily(tester), AppFonts.defaultFont);
    });

    testWidgets('אותו גופן נשאר כשאין טעמים בשורה', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text: _nikudOnly,
            settings: RenderSettings(
              fontSize: 20,
              fontFamily: 'Rubik',
              removeTeamim: false,
            ),
          ),
        ),
      );

      expect(_renderedFontFamily(tester), 'Rubik');
    });

    // הסרת הטעמים היא הגדרת תצוגה: הטקסט המרונדר נקי מהם, ואין סיבה להחליף.
    testWidgets('הגדרת "הסתר טעמים" משאירה את הגופן הנבחר', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text: _withTaamim,
            settings: RenderSettings(fontSize: 20, fontFamily: 'Rubik'),
          ),
        ),
      );

      expect(_renderedFontFamily(tester), 'Rubik');
    });

    testWidgets('גופן תומך אינו מוחלף', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmartTextWidget(
            text: _withTaamim,
            settings: RenderSettings(
              fontSize: 20,
              fontFamily: 'TaameyDavidCLM',
              removeTeamim: false,
            ),
          ),
        ),
      );

      expect(_renderedFontFamily(tester), 'TaameyDavidCLM');
    });
  });
}

Widget _wrap(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

String? _renderedFontFamily(WidgetTester tester) =>
    tester.widget<RichText>(find.byType(RichText).first).text.style?.fontFamily;
