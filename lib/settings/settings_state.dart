import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:otzaria/settings/settings_enums.dart';

class SettingsState extends Equatable {
  final bool isDarkMode;
  final bool followSystemTheme;
  final Color seedColor;
  final Color darkSeedColor;
  final double textMaxWidth; // רוחב מקסימלי לטקסט בפיקסלים (0 = ללא הגבלה)
  final double fontSize;
  final String fontFamily;
  final String commentatorsFontFamily;
  final double commentatorsFontSize;
  final double
      lineHeight; // מרווח בין שורות (1.0 = רגיל, 1.5 = מרווח וחצי, וכו')
  final bool showOtzarHachochma;
  final bool showHebrewBooks;
  final bool showExternalBooks;
  final bool showTeamim;
  final bool useFastSearch;
  final bool replaceHolyNames;
  final bool autoUpdateIndex;
  final NikudDisplayMode nikudDisplayMode;
  final SidebarMode sidebarMode;
  final double sidebarWidth;
  final double facetFilteringWidth;
  final double commentaryPaneWidth;
  final String copyWithHeaders;
  final String copyHeaderFormat;
  final bool isFullscreen;
  final String libraryViewMode;
  final bool libraryShowPreview;
  final Map<String, String> shortcuts;
  final bool enablePerBookSettings;
  final bool isOfflineMode;
  final bool alignTabsToRight;
  final bool enableHtmlLinks;
  final bool personalNotesCollapsedByDefault;
  final bool protectedModeEnabled;

  const SettingsState({
    required this.isDarkMode,
    required this.followSystemTheme,
    required this.seedColor,
    required this.darkSeedColor,
    required this.textMaxWidth,
    required this.fontSize,
    required this.fontFamily,
    required this.commentatorsFontFamily,
    required this.commentatorsFontSize,
    required this.lineHeight,
    required this.showOtzarHachochma,
    required this.showHebrewBooks,
    required this.showExternalBooks,
    required this.showTeamim,
    required this.useFastSearch,
    required this.replaceHolyNames,
    required this.autoUpdateIndex,
    required this.nikudDisplayMode,
    required this.sidebarMode,
    required this.sidebarWidth,
    required this.facetFilteringWidth,
    required this.commentaryPaneWidth,
    required this.copyWithHeaders,
    required this.copyHeaderFormat,
    required this.isFullscreen,
    required this.libraryViewMode,
    required this.libraryShowPreview,
    required this.shortcuts,
    required this.enablePerBookSettings,
    required this.isOfflineMode,
    required this.alignTabsToRight,
    required this.enableHtmlLinks,
    required this.personalNotesCollapsedByDefault,
    required this.protectedModeEnabled,
  });

  factory SettingsState.initial() {
    return const SettingsState(
      isDarkMode: false,
      followSystemTheme: false,
      seedColor: Colors.brown,
      darkSeedColor: Color(0xFFCE93D8), // סגול בהיר למצב כהה
      textMaxWidth:
          -1, // רוחב מקסימלי לטקסט (-1 = רמה 1 = 95% כברירת מחדל, 0 = ללא הגבלה)
      fontSize: 16,
      fontFamily: 'FrankRuhlCLM',
      commentatorsFontFamily: 'NotoRashiHebrew',
      commentatorsFontSize: 22,
      lineHeight: 1.5,
      showOtzarHachochma: false,
      showHebrewBooks: false,
      showExternalBooks: false,
      showTeamim: true,
      useFastSearch: true,
      replaceHolyNames: true,
      autoUpdateIndex: true,
      nikudDisplayMode: NikudDisplayMode.showAll,
      sidebarMode: SidebarMode.hidden,
      sidebarWidth: 300,
      facetFilteringWidth: 235,
      commentaryPaneWidth: 400,
      copyWithHeaders: 'none',
      copyHeaderFormat: 'same_line_after_brackets',
      isFullscreen: false,
      libraryViewMode: 'grid',
      libraryShowPreview: true,
      shortcuts: {},
      enablePerBookSettings: true,
      isOfflineMode: false,
      alignTabsToRight: false,
      enableHtmlLinks: true,
      personalNotesCollapsedByDefault: true,
      protectedModeEnabled: false,
    );
  }

  SettingsState copyWith({
    bool? isDarkMode,
    bool? followSystemTheme,
    Color? seedColor,
    Color? darkSeedColor,
    double? textMaxWidth,
    double? fontSize,
    String? fontFamily,
    String? commentatorsFontFamily,
    double? commentatorsFontSize,
    double? lineHeight,
    bool? showOtzarHachochma,
    bool? showHebrewBooks,
    bool? showExternalBooks,
    bool? showTeamim,
    bool? useFastSearch,
    bool? replaceHolyNames,
    bool? autoUpdateIndex,
    NikudDisplayMode? nikudDisplayMode,
    SidebarMode? sidebarMode,
    double? sidebarWidth,
    double? facetFilteringWidth,
    double? commentaryPaneWidth,
    String? copyWithHeaders,
    String? copyHeaderFormat,
    bool? isFullscreen,
    String? libraryViewMode,
    bool? libraryShowPreview,
    Map<String, String>? shortcuts,
    bool? enablePerBookSettings,
    bool? isOfflineMode,
    bool? alignTabsToRight,
    bool? enableHtmlLinks,
    bool? personalNotesCollapsedByDefault,
    bool? protectedModeEnabled,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      seedColor: seedColor ?? this.seedColor,
      darkSeedColor: darkSeedColor ?? this.darkSeedColor,
      textMaxWidth: textMaxWidth ?? this.textMaxWidth,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      commentatorsFontFamily:
          commentatorsFontFamily ?? this.commentatorsFontFamily,
      commentatorsFontSize: commentatorsFontSize ?? this.commentatorsFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      showOtzarHachochma: showOtzarHachochma ?? this.showOtzarHachochma,
      showHebrewBooks: showHebrewBooks ?? this.showHebrewBooks,
      showExternalBooks: showExternalBooks ?? this.showExternalBooks,
      showTeamim: showTeamim ?? this.showTeamim,
      useFastSearch: useFastSearch ?? this.useFastSearch,
      replaceHolyNames: replaceHolyNames ?? this.replaceHolyNames,
      autoUpdateIndex: autoUpdateIndex ?? this.autoUpdateIndex,
      nikudDisplayMode: nikudDisplayMode ?? this.nikudDisplayMode,
      sidebarMode: sidebarMode ?? this.sidebarMode,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      facetFilteringWidth: facetFilteringWidth ?? this.facetFilteringWidth,
      commentaryPaneWidth: commentaryPaneWidth ?? this.commentaryPaneWidth,
      copyWithHeaders: copyWithHeaders ?? this.copyWithHeaders,
      copyHeaderFormat: copyHeaderFormat ?? this.copyHeaderFormat,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      libraryViewMode: libraryViewMode ?? this.libraryViewMode,
      libraryShowPreview: libraryShowPreview ?? this.libraryShowPreview,
      shortcuts: shortcuts ?? this.shortcuts,
      enablePerBookSettings:
          enablePerBookSettings ?? this.enablePerBookSettings,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      alignTabsToRight: alignTabsToRight ?? this.alignTabsToRight,
      enableHtmlLinks: enableHtmlLinks ?? this.enableHtmlLinks,
      personalNotesCollapsedByDefault: personalNotesCollapsedByDefault ??
          this.personalNotesCollapsedByDefault,
      protectedModeEnabled: protectedModeEnabled ?? this.protectedModeEnabled,
    );
  }

  @override
  List<Object?> get props => [
        isDarkMode,
        followSystemTheme,
        seedColor,
        darkSeedColor,
        textMaxWidth,
        fontSize,
        fontFamily,
        commentatorsFontFamily,
        commentatorsFontSize,
        lineHeight,
        showOtzarHachochma,
        showHebrewBooks,
        showExternalBooks,
        showTeamim,
        useFastSearch,
        replaceHolyNames,
        autoUpdateIndex,
        nikudDisplayMode,
        sidebarMode,
        sidebarWidth,
        facetFilteringWidth,
        commentaryPaneWidth,
        copyWithHeaders,
        copyHeaderFormat,
        isFullscreen,
        libraryViewMode,
        libraryShowPreview,
        shortcuts,
        enablePerBookSettings,
        isOfflineMode,
        alignTabsToRight,
        enableHtmlLinks,
        personalNotesCollapsedByDefault,
        protectedModeEnabled,
      ];

  // Getters לתאימות לאחור
  bool get defaultRemoveNikud => nikudDisplayMode != NikudDisplayMode.showAll;
  bool get removeNikudFromTanach =>
      nikudDisplayMode == NikudDisplayMode.hideAll;
  bool get defaultSidebarOpen => sidebarMode != SidebarMode.hidden;
  bool get pinSidebar => sidebarMode == SidebarMode.pinned;
}
