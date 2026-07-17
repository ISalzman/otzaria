import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
