import 'package:flutter/material.dart';
import 'package:updat/updat.dart';
import 'package:updat/updat_window_manager.dart';
import 'hebrew_updat_widgets.dart';

/// דוגמה לשימוש ברכיבי העדכון העבריים
///
/// ניתן לבחור בין הרכיבים הבאים:
///
/// 1. hebrewFlatChip - רכיב לחיצה פשוט בעברית (כמו flatChip המקורי)
/// 2. hebrewFloatingExtendedChipWithSilentDownload - רכיב מורחב עם הורדה שקטה
/// 3. hebrewDefaultDialog - דיאלוג ברירת מחדל בעברית
///
/// דוגמאות שימוש:

class HebrewUpdatExamples {
  /// דוגמה 1: שימוש ב-UpdatWidget עם רכיב לחיצה עברי פשוט
  static Widget simpleHebrewUpdatWidget({
    required String currentVersion,
    required Future<String> Function() getLatestVersion,
    required Future<String> Function(String?) getBinaryUrl,
    required String appName,
  }) {
    return UpdatWidget(
      currentVersion: currentVersion,
      getLatestVersion: getLatestVersion,
      getBinaryUrl: getBinaryUrl,
      appName: appName,
      updateChipBuilder: hebrewFlatChip,
      updateDialogBuilder: hebrewDefaultDialog,
    );
  }

  /// דוגמה 2: שימוש ב-UpdatWindowManager עם רכיב מורחב בעברית
  static Widget hebrewUpdatWindowManager({
    required Widget child,
    required String currentVersion,
    required Future<String> Function() getLatestVersion,
    required Future<String> Function(String?) getBinaryUrl,
    required String appName,
  }) {
    return UpdatWindowManager(
      currentVersion: currentVersion,
      getLatestVersion: getLatestVersion,
      getBinaryUrl: getBinaryUrl,
      appName: appName,
      updateChipBuilder: hebrewFloatingExtendedChipWithSilentDownload,
      updateDialogBuilder: hebrewDefaultDialog,
      child: child,
    );
  }

  /// דוגמה 3: שימוש עם הסתרה אוטומטית של שגיאות
  static Widget Function({
    required BuildContext context,
    required String? latestVersion,
    required String appVersion,
    required UpdatStatus status,
    required void Function() checkForUpdate,
    required void Function() openDialog,
    required void Function() startUpdate,
    required Future<void> Function() launchInstaller,
    required void Function() dismissUpdate,
  }) get hebrewAutoHideErrorChip => hebrewFlatChipAutoHideError;
}

/// פונקציה עזר להסתרת שגיאות אוטומטית
Widget hebrewFlatChipAutoHideError({
  required BuildContext context,
  required String? latestVersion,
  required String appVersion,
  required UpdatStatus status,
  required void Function() checkForUpdate,
  required void Function() openDialog,
  required void Function() startUpdate,
  required Future<void> Function() launchInstaller,
  required void Function() dismissUpdate,
}) {
  if (status == UpdatStatus.error) {
    Future.delayed(const Duration(seconds: 3), dismissUpdate);
  }
  return hebrewFlatChip(
    context: context,
    latestVersion: latestVersion,
    appVersion: appVersion,
    status: status,
    checkForUpdate: checkForUpdate,
    openDialog: openDialog,
    startUpdate: startUpdate,
    launchInstaller: launchInstaller,
    dismissUpdate: dismissUpdate,
  );
}
