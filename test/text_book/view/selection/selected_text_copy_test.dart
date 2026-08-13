import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/selection/selected_text_copy.dart';

void main() {
  group('resolveHtmlTextForSelection', () {
    test('מחזיר HTML מקורי כשהבחירה מכסה את כל השורה', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'שלום עולם',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, '<b>שלום</b> עולם');
    });

    test('מחזיר HTML חתוך כשהבחירה היא רק חלק מהשורה', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'שלום',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, '<b>שלום</b>');
    });

    test('שומר עיצוב גם בבחירה שחוצה תגית', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'לום עו',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, '<b>לום</b> עו');
    });

    test('נופל לטקסט פשוט כשהבחירה אינה נמצאת בשורה', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'טקסט משורה אחרת',
        selectedIndex: 0,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, 'טקסט משורה אחרת');
    });

    test('מחזיר fallback לטקסט פשוט כשאין אינדקס תקין', () {
      final resolved = resolveHtmlTextForSelection(
        plainText: 'שלום',
        selectedIndex: null,
        sourceContent: const ['<b>שלום</b> עולם'],
      );

      expect(resolved, 'שלום');
    });
  });
}
