import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_seed_colors.dart';
import 'package:otzaria/theme/app_theme_data.dart';

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
  });
}
