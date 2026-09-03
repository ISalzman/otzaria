import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_display/text_display_exports.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

TextDisplayPolicy _legacy({
  bool defaultRemoveNikud = false,
  bool removeNikudFromTanach = false,
  bool defaultRemovePunctuation = false,
  bool showTeamim = true,
  bool replaceHolyNames = true,
  HolyNameStyle holyNameStyle = HolyNameStyle.kufKuf,
}) => TextDisplayPolicy.fromLegacy(
  defaultRemoveNikud: defaultRemoveNikud,
  removeNikudFromTanach: removeNikudFromTanach,
  defaultRemovePunctuation: defaultRemovePunctuation,
  showTeamim: showTeamim,
  replaceHolyNames: replaceHolyNames,
  holyNameStyle: holyNameStyle,
);

void main() {
  group('TextDisplayPolicy.fromLegacy — טבלת האמת של הניקוד', () {
    test('הצג תמיד: תנ"ך ומפרשיו מנוקדים', () {
      final p = _legacy();
      expect(
        p.resolve(TextDisplaySlot.root, isTanach: true).removeNikud,
        isFalse,
      );
      expect(
        p
            .resolve(TextDisplaySlot.commentaryDisplay, isTanach: true)
            .removeNikud,
        isFalse,
      );
      expect(p.defaultRemoveNikud, isFalse);
    });

    test('הצג בתנ"ך בלבד: התנ"ך מנוקד, מפרשיו לא, ספר רגיל לא', () {
      final p = _legacy(defaultRemoveNikud: true, removeNikudFromTanach: false);
      expect(
        p.resolve(TextDisplaySlot.root, isTanach: true).removeNikud,
        isFalse,
      );
      expect(
        p
            .resolve(TextDisplaySlot.commentaryDisplay, isTanach: true)
            .removeNikud,
        isTrue,
      );
      expect(p.resolve(TextDisplaySlot.root).removeNikud, isTrue);
      expect(p.defaultRemoveNikud, isTrue);
      expect(p.removeNikudFromTanach, isFalse);
    });

    test('אל תציג: הכול בלי ניקוד', () {
      final p = _legacy(defaultRemoveNikud: true, removeNikudFromTanach: true);
      expect(
        p.resolve(TextDisplaySlot.root, isTanach: true).removeNikud,
        isTrue,
      );
      expect(p.removeNikudFromTanach, isTrue);
      expect(p.tanach.isEmpty, isTrue);
    });

    test('פיסוק: מוסר בכל ספר חוץ מהתנ"ך, וכן במפרשי התנ"ך', () {
      final p = _legacy(defaultRemovePunctuation: true);
      expect(p.resolve(TextDisplaySlot.root).removePunctuation, isTrue);
      expect(
        p.resolve(TextDisplaySlot.root, isTanach: true).removePunctuation,
        isFalse,
      );
      expect(
        p
            .resolve(TextDisplaySlot.commentaryDisplay, isTanach: true)
            .removePunctuation,
        isTrue,
      );
      expect(p.defaultRemovePunctuation, isTrue);
    });

    test('טעמים: showTeamim=false ⇒ hide; true ⇒ followNikud', () {
      expect(_legacy(showTeamim: false).showTeamim, isFalse);
      expect(
        _legacy(showTeamim: true).resolve(TextDisplaySlot.root).teamim,
        TeamimVisibility.followNikud,
      );
      expect(_legacy(showTeamim: true).showTeamim, isTrue);
    });

    test('שם הוי"ה', () {
      expect(_legacy(replaceHolyNames: false).replaceHolyNames, isFalse);
      final heh = _legacy(holyNameStyle: HolyNameStyle.hehApostrophe);
      expect(heh.replaceHolyNames, isTrue);
      expect(heh.holyNameStyle, HolyNameStyle.hehApostrophe);
    });
  });

  group('עדכוני legacy הם הפיכים ומנקים החרגות', () {
    test('כיבוי הסרת ניקוד מנקה את החרגת התנ"ך', () {
      final p = _legacy(
        defaultRemoveNikud: true,
        removeNikudFromTanach: false,
      ).withLegacyDefaultRemoveNikud(false);
      expect(p.tanach.isEmpty, isTrue);
      expect(p.defaultRemoveNikud, isFalse);
    });

    test('מעבר בין שלושת מצבי הניקוד שקול לבנייה מחדש', () {
      var p = _legacy();
      p = p
          .withLegacyDefaultRemoveNikud(true)
          .withLegacyNikudFromTanach(removeFromTanach: false);
      expect(
        p,
        _legacy(defaultRemoveNikud: true, removeNikudFromTanach: false),
      );
      p = p.withLegacyNikudFromTanach(removeFromTanach: true);
      expect(
        p,
        _legacy(defaultRemoveNikud: true, removeNikudFromTanach: true),
      );
    });

    test('כיבוי פיסוק מנקה את טלאי התנ"ך אך משאיר טלאי ניקוד', () {
      final p = _legacy(
        defaultRemoveNikud: true,
        defaultRemovePunctuation: true,
      ).withLegacyPunctuation(false);
      expect(p.tanach.patchFor(TextDisplaySlot.root).punctuation, isNull);
      expect(
        p.tanach.patchFor(TextDisplaySlot.root).nikud,
        MarkVisibility.show,
      );
    });
  });

  group('JSON', () {
    test('הלוך ושוב', () {
      final p = _legacy(
        defaultRemoveNikud: true,
        defaultRemovePunctuation: true,
        showTeamim: false,
        replaceHolyNames: false,
      );
      expect(TextDisplayPolicy.fromJson(p.toJson()), p);
    });

    test('JSON חלקי/פגום נטען כשכבות ריקות', () {
      final p = TextDisplayPolicy.fromJson({'general': 5});
      expect(p, TextDisplayPolicy.empty);
    });
  });
}
