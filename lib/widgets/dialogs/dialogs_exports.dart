// lib/widgets/dialogs/dialogs_exports.dart
//
// Barrel export לכל דיאלוגי האפליקציה.
//
// ─── דיאלוגי אישור/ביטול ─────────────────────────────────────────────────────
// [AppDialog.singleAction] / [showSingleActionDialog] → app_dialogs.dart
// [AppDialog.twoActions]   / [showTwoActionsDialog]   → app_dialogs.dart
// [AppDialog.warning]      / [showWarningDialog]      → app_dialogs.dart
// [showDbCopyRequiredDialog]                           → app_dialogs.dart
//   שימוש: דיאלוגים M3 עם ניווט מקלדת והדגשת פוקוס.
//
// [ConfirmationDialog] / [showConfirmationDialog]     → confirmation_dialog.dart
//   wrapper דק מעל AppDialog — תומך ב-[isDangerous].
//
// ─── דיאלוגי קלט ─────────────────────────────────────────────────────────────
// [InputDialog] / [showInputDialog]                   → input_dialog.dart
//
// ─── דיאלוגי הגדרות ──────────────────────────────────────────────────────────
// [GenericSettingsDialog]                             → generic_settings_dialog.dart
//
// ─── דיאלוגי בחירה ───────────────────────────────────────────────────────────
// [SelectionDialog]                                   → selection_dialog.dart
// ─── מיכל כללי ───────────────────────────────────────────────────────────────
// [ReusableItemsDialog]                               → reusable_items_dialog.dart

export 'confirmation_dialog.dart';
export 'app_dialogs.dart';
export 'input_dialog.dart';
export 'selection_dialog.dart';
