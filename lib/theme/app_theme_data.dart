import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_colors.dart';
import 'package:otzaria/theme/app_theme.dart';

// ── AppThemeData ──────────────────────────────────────────────────────────────
// Factory ליצירת ThemeData לאפליקציה
// ─────────────────────────────────────────────────────────────────────────────

class AppThemeData {
  AppThemeData._();

  // ── Light Theme ──

  static ThemeData light(ColorScheme colorScheme, {bool compactMenus = false}) {
    return ThemeData(
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 18.0, fontFamily: 'candara'),
      ),
    ).copyWith(
      dialogTheme: DialogThemeData(
        barrierColor: AppColors.dialogBarrier,
        backgroundColor: colorScheme.surface,
      ),
      extensions: [AppMenuMetrics.create(compactMenus: compactMenus)],
    );
  }

  // ── Dark Theme ──

  static ThemeData dark(Color darkSeedColor, {bool compactMenus = false}) {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: AppColors.darkScaffold,
      canvasColor: AppColors.darkScaffold,
      cardColor: AppColors.darkCard,
      colorScheme: ColorScheme.dark(
        surface: AppColors.darkScaffold,
        surfaceContainer: AppColors.darkCard,
        onSurface: AppColors.darkOnSurface,
        primary: darkSeedColor,
        onPrimary: Colors.white,
        secondary: darkSeedColor.withValues(alpha: 0.7),
        onSecondary: Colors.white,
        outline: AppColors.darkOutline,
      ),
      textTheme: ThemeData.dark()
          .textTheme
          .apply(
            fontFamily: 'Roboto',
            bodyColor: AppColors.darkOnSurface,
            displayColor: AppColors.darkOnSurface,
          )
          .copyWith(
            bodyMedium: const TextStyle(
              fontSize: 18.0,
              fontFamily: 'candara',
              color: AppColors.darkOnSurface,
            ),
          ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: AppTokens.elevation2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          side: const BorderSide(
            color: AppColors.darkOutline,
            width: 1,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkAppBar,
        foregroundColor: AppColors.darkOnSurface,
      ),
      dialogTheme: const DialogThemeData(
        barrierColor: AppColors.dialogBarrier,
        backgroundColor: AppColors.darkAppBar,
      ),
      extensions: [AppMenuMetrics.create(compactMenus: compactMenus)],
    );
  }
}

/// עזרי דחיסות ותזוזות עבור תפריטים
class AppMenuMetrics extends ThemeExtension<AppMenuMetrics> {
  final bool compactMenus;
  final double itemHeight;
  final EdgeInsets itemPadding;
  final EdgeInsets menuPadding;
  final VisualDensity visualDensity;
  final double dividerHeight;
  final double fontSize;
  final double iconSize;
  final double menuBorderRadius;
  final double itemBorderRadius;
  final double menuMinWidth;
  final FontWeight itemFontWeight;

  const AppMenuMetrics({
    required this.compactMenus,
    required this.itemHeight,
    required this.itemPadding,
    required this.menuPadding,
    required this.visualDensity,
    required this.dividerHeight,
    required this.fontSize,
    required this.iconSize,
    required this.menuBorderRadius,
    required this.itemBorderRadius,
    required this.menuMinWidth,
    required this.itemFontWeight,
  });

  factory AppMenuMetrics.create({required bool compactMenus}) {
    return AppMenuMetrics(
      compactMenus: compactMenus,
      itemHeight: 36,
      itemPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 0,
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      visualDensity: VisualDensity.standard,
      dividerHeight: 8,
      fontSize: 14,
      iconSize: 18,
      menuBorderRadius: 8,
      itemBorderRadius: 4,
      menuMinWidth: 150,
      itemFontWeight: FontWeight.w400,
    );
  }

  @override
  AppMenuMetrics copyWith({
    bool? compactMenus,
    double? itemHeight,
    EdgeInsets? itemPadding,
    EdgeInsets? menuPadding,
    VisualDensity? visualDensity,
    double? dividerHeight,
    double? fontSize,
    double? iconSize,
    double? menuBorderRadius,
    double? itemBorderRadius,
    double? menuMinWidth,
    FontWeight? itemFontWeight,
  }) {
    return AppMenuMetrics(
      compactMenus: compactMenus ?? this.compactMenus,
      itemHeight: itemHeight ?? this.itemHeight,
      itemPadding: itemPadding ?? this.itemPadding,
      menuPadding: menuPadding ?? this.menuPadding,
      visualDensity: visualDensity ?? this.visualDensity,
      dividerHeight: dividerHeight ?? this.dividerHeight,
      fontSize: fontSize ?? this.fontSize,
      iconSize: iconSize ?? this.iconSize,
      menuBorderRadius: menuBorderRadius ?? this.menuBorderRadius,
      itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
      menuMinWidth: menuMinWidth ?? this.menuMinWidth,
      itemFontWeight: itemFontWeight ?? this.itemFontWeight,
    );
  }

  @override
  AppMenuMetrics lerp(ThemeExtension<AppMenuMetrics>? other, double t) {
    if (other is! AppMenuMetrics) return this;

    return AppMenuMetrics(
      compactMenus: t < 0.5 ? compactMenus : other.compactMenus,
      itemHeight: lerpDouble(itemHeight, other.itemHeight, t) ?? itemHeight,
      itemPadding:
          EdgeInsets.lerp(itemPadding, other.itemPadding, t) ?? itemPadding,
      menuPadding:
          EdgeInsets.lerp(menuPadding, other.menuPadding, t) ?? menuPadding,
      visualDensity: t < 0.5 ? visualDensity : other.visualDensity,
      dividerHeight:
          lerpDouble(dividerHeight, other.dividerHeight, t) ?? dividerHeight,
      fontSize: lerpDouble(fontSize, other.fontSize, t) ?? fontSize,
      iconSize: lerpDouble(iconSize, other.iconSize, t) ?? iconSize,
      menuBorderRadius:
          lerpDouble(menuBorderRadius, other.menuBorderRadius, t) ??
              menuBorderRadius,
      itemBorderRadius:
          lerpDouble(itemBorderRadius, other.itemBorderRadius, t) ??
              itemBorderRadius,
      menuMinWidth:
          lerpDouble(menuMinWidth, other.menuMinWidth, t) ?? menuMinWidth,
      itemFontWeight: t < 0.5 ? itemFontWeight : other.itemFontWeight,
    );
  }
}
