import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_seed_colors.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/theme/app_theme_data.dart';

void main() {
  group('AppSurfaces.selectedItem', () {
    late ColorScheme lightScheme;
    late ColorScheme darkScheme;

    setUpAll(() {
      lightScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      darkScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );
    });

    test('מחזיר primaryContainer בשקיפות 30%', () {
      final result = AppSurfaces.selectedItem(lightScheme);
      final expected = lightScheme.primaryContainer.withValues(alpha: 0.3);
      expect(result, expected);
    });

    test('עובד גם עם ערכת צבעים כהה', () {
      final result = AppSurfaces.selectedItem(darkScheme);
      final expected = darkScheme.primaryContainer.withValues(alpha: 0.3);
      expect(result, expected);
    });

    test('צבע שונה מ-primaryContainer המלא', () {
      final selected = AppSurfaces.selectedItem(lightScheme);
      final full = lightScheme.primaryContainer;
      // alpha 30% שונה מ-alpha 100%
      expect(selected.a, isNot(equals(full.a)));
    });

    test('alpha קרוב ל-0.3 (סובלנות לעיגול float)', () {
      final selected = AppSurfaces.selectedItem(lightScheme);
      expect(selected.a, closeTo(0.3, 0.01));
    });
  });

  group('AppSurfaces.paragraphSelectionBackground', () {
    test('ערכת "לבן" במצב בהיר נותנת F8FAFC', () {
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.white,
        Brightness.light,
      );
      expect(
        AppSurfaces.paragraphSelectionBackground(cs),
        const Color(0xFFF8FAFC),
      );
    });

    test('ערכת "לבן" במצב כהה נשארת 8% primary', () {
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.white,
        Brightness.dark,
      );
      expect(
        AppSurfaces.paragraphSelectionBackground(cs),
        cs.primary.withValues(alpha: 0.08),
      );
    });

    test('ערכת ברירת מחדל נותנת 8% primary', () {
      final cs = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      expect(
        AppSurfaces.paragraphSelectionBackground(cs),
        cs.primary.withValues(alpha: 0.08),
      );
    });

    test('פרגמנט נשאר 8% primary — לא F8FAFC', () {
      final cs = AppThemeData.createColorScheme(
        AppSeedColors.parchment,
        Brightness.light,
      );
      expect(
        AppSurfaces.paragraphSelectionBackground(cs),
        isNot(const Color(0xFFF8FAFC)),
      );
    });
  });
}
