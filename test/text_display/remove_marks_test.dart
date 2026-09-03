import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_display/text_display_exports.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:otzaria/widgets/smart_text/render_settings.dart';
import 'package:otzaria/widgets/smart_text/text_renderer_service.dart';

/// בראשית א:א עם ניקוד וטעמים; כולל מקף ומתג.
const _pasuk =
    'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָ֑רֶץ׃';
const _withMaqaf = 'עַל־פְּנֵ֥י';

void main() {
  group('removeNikudOnly', () {
    test('מסיר ניקוד ומשאיר טעמים', () {
      final out = removeNikudOnly(_pasuk);
      expect(out, isNot(contains('ְ')));
      expect(out, isNot(contains('ּ')));
      expect(out, isNot(contains('ׁ')));
      // טעמים (טיפחא, מונח, אתנחתא, מרכא) נשארים.
      expect(out, contains('֖'));
      expect(out, contains('֣'));
      expect(out, contains('֑'));
      expect(out, contains('֥'));
      // סוף פסוק ומקף אינם ניקוד.
      expect(out, endsWith('׃'));
      expect(removeNikudOnly(_withMaqaf), contains('־'));
    });
  });

  group('removeMarks', () {
    test('שניהם = removeVolwels', () {
      expect(
        removeMarks(_pasuk, nikud: true, teamim: true),
        removeVolwels(_pasuk),
      );
    });

    test('טעמים בלבד = removeTeamim', () {
      expect(
        removeMarks(_pasuk, nikud: false, teamim: true),
        removeTeamim(_pasuk),
      );
    });

    test('ניקוד בלבד = removeNikudOnly', () {
      expect(
        removeMarks(_pasuk, nikud: true, teamim: false),
        removeNikudOnly(_pasuk),
      );
    });

    test('כלום = ללא שינוי', () {
      expect(removeMarks(_pasuk, nikud: false, teamim: false), _pasuk);
    });
  });

  group('TextRendererService.processText עם פרופיל', () {
    setUp(TextRendererService.clearRenderCacheForTesting);

    test('ניקוד מוסתר עם followNikud — גם הטעמים נעלמים', () {
      final settings = RenderSettings.fromProfile(
        const TextDisplayProfile(nikud: MarkVisibility.hide),
        formatParentheses: false,
      );
      final out = TextRendererService.processText(_pasuk, settings);
      expect(out, isNot(contains('֖')));
      expect(out, isNot(contains('ְ')));
    });

    test('ניקוד מוסתר, טעמים מוצגים — הטעמים נשארים', () {
      final settings = RenderSettings.fromProfile(
        const TextDisplayProfile(
          nikud: MarkVisibility.hide,
          teamim: TeamimVisibility.show,
        ),
        formatParentheses: false,
      );
      final out = TextRendererService.processText(_pasuk, settings);
      expect(out, contains('֖'));
      expect(out, isNot(contains('ְ')));
    });

    test('ניקוד מוצג, טעמים מוסתרים — רק הטעמים נעלמים', () {
      final settings = RenderSettings.fromProfile(
        const TextDisplayProfile(teamim: TeamimVisibility.hide),
        formatParentheses: false,
      );
      final out = TextRendererService.processText(_pasuk, settings);
      expect(out, isNot(contains('֖')));
      expect(out, contains('ְ'));
    });

    test('fromProfile ממפה את שם הוי"ה', () {
      final asIs = RenderSettings.fromProfile(
        const TextDisplayProfile(holyName: HolyNameDisplay.asIs),
      );
      expect(asIs.replaceHolyNames, isFalse);
      final heh = RenderSettings.fromProfile(
        const TextDisplayProfile(holyName: HolyNameDisplay.hehApostrophe),
      );
      expect(heh.replaceHolyNames, isTrue);
      expect(heh.holyNameStyle, HolyNameStyle.hehApostrophe);
    });
  });

  group('applyTextDisplayProfile', () {
    test('ברירת המחדל: רק שם הוי"ה מוחלף', () {
      const text = 'וַיְדַבֵּ֣ר יְהוָ֔ה';
      final out = applyTextDisplayProfile(text, TextDisplayProfile.defaults);
      expect(out, contains('יְקוָ֔ק'));
      expect(out, contains('֣'));
    });

    test('הסתרה מלאה: ניקוד, טעמים ופיסוק', () {
      const text = 'בְּרֵאשִׁ֖ית, בָּרָ֣א.';
      final out = applyTextDisplayProfile(
        text,
        const TextDisplayProfile(
          nikud: MarkVisibility.hide,
          punctuation: MarkVisibility.hide,
          holyName: HolyNameDisplay.asIs,
        ),
      );
      expect(out, 'בראשית ברא.');
    });
  });
}
