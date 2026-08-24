import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_seed_colors.dart';
import 'package:otzaria/theme/app_theme_data.dart';

/// ניגודיות WCAG בין שני צבעים (יחס בהירות).
double _contrastRatio(Color a, Color b) {
  double linear(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final la = 0.2126 * linear(a.r) + 0.7152 * linear(a.g) + 0.0722 * linear(a.b);
  final lb = 0.2126 * linear(b.r) + 0.7152 * linear(b.g) + 0.0722 * linear(b.b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('בועות מידע משתמשות בצבעי הנושא ב-$brightness', () {
      final colorScheme = AppThemeData.createColorScheme(
        Colors.deepPurple,
        brightness,
      );
      final theme = brightness == Brightness.light
          ? AppThemeData.light(colorScheme, compactMenuMode: false)
          : AppThemeData.dark(colorScheme, compactMenuMode: false);
      final decoration = theme.tooltipTheme.decoration! as BoxDecoration;

      expect(decoration.color, colorScheme.surfaceContainerHigh);
      expect(theme.tooltipTheme.textStyle?.color, colorScheme.onSurface);
    });
  }

  group('ערכת צבע "לבן"', () {
    test('במצב בהיר רקע מסך העיון לבן מוחלט', () {
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.white,
        Brightness.light,
      );
      expect(cs.surface, Colors.white);
    });

    test('במצב כהה הרקע נשאר כהה', () {
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.white,
        Brightness.dark,
      );
      expect(cs.surface, isNot(Colors.white));
    });

    test('פרגמנט נשאר FFF8F6 — הרקע של "לבן" שונה ממנו', () {
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.parchment,
        Brightness.light,
      );
      expect(cs.surface, const Color(0xFFFFF8F6));
    });

    test('שאר צבעי הבסיס אינם מקבלים surface לבן', () {
      for (final option in AppSeedColors.options) {
        if (option.color.toARGB32() == AppSeedColors.white.toARGB32()) {
          continue;
        }
        final cs = AppThemeData.createColorScheme(
          option.color,
          Brightness.light,
        );
        expect(cs.surface, isNot(Colors.white), reason: option.name);
      }
    });

    test('primaryContainer/onPrimaryContainer תמיד קריאים (ניגודיות WCAG)', () {
      // השורה הנבחרת באיתור, חצי דפדוף תוצאות ואות המפרש הפעילה צובעים
      // רקע ב-primaryContainer וכתב ב-onPrimaryContainer. בערכת "לבן"
      // (ו-monochrome בכלל) primaryContainer כהה במיוחד במצב בהיר, ולכן
      // חייבים לוודא שהזיווג נשאר קריא בכל הצבעים ובשני המצבים.
      for (final option in AppSeedColors.options) {
        for (final brightness in Brightness.values) {
          final cs = AppThemeData.createColorScheme(
            option.color,
            brightness,
          );
          final ratio = _contrastRatio(
            cs.primaryContainer,
            cs.onPrimaryContainer,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${option.name} $brightness: primaryContainer '
                '${cs.primaryContainer} מול onPrimaryContainer '
                '${cs.onPrimaryContainer} — ניגודיות $ratio',
          );
        }
      }
    });

    test('הזיווג primaryContainer/onSurface כהה-על-כהה אסור בערכת "לבן"', () {
      // ערכת "לבן" במצב בהיר נותנת primaryContainer כהה (#3B3B3B) — לכן אסור
      // לצבוע עליו טקסט ב-onSurface (שחור). זה התרחיש שתוקן באיתור ובחצי
      // הדפדוף: הכתב חייב לעבור ל-onPrimaryContainer.
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.white,
        Brightness.light,
      );
      final ratio = _contrastRatio(cs.primaryContainer, cs.onSurface);
      expect(
        ratio,
        lessThan(3.0),
        reason:
            'primaryContainer ${cs.primaryContainer} עם onSurface '
            '${cs.onSurface} חייב להישאר בלתי-קריא כדי למנוע שימוש בטעות',
      );
    });

    test('secondaryContainer עם onSurface/onSurfaceVariant תמיד קריא', () {
      // סריקת כל הצבעים והמצבים מראה ש-secondaryContainer הוא תמיד בהיר
      // במצב בהיר וכהה במצב כהה (בניגוד ל-primaryContainer בערכות monochrome),
      // ולכן כתב עליו ב-onSurface/onSurfaceVariant נשאר קריא בכל הצבעים —
      // אין צורך להמירו ל-onSecondaryContainer.
      for (final option in AppSeedColors.options) {
        for (final brightness in Brightness.values) {
          final cs = AppThemeData.createColorScheme(
            option.color,
            brightness,
          );
          for (final pair in [
            (cs.secondaryContainer, cs.onSurface),
            (cs.secondaryContainer, cs.onSurfaceVariant),
          ]) {
            final ratio = _contrastRatio(pair.$1, pair.$2);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${option.name} $brightness: secondaryContainer '
                  '${pair.$1} מול ${pair.$2} — ניגודיות $ratio',
            );
          }
        }
      }
    });
  });
}
