import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/utils/link_helpers.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

/// בניית רשימת פריטי תפריט הקשר ל"העתק קישור ישיר".
///
/// מאחד מימוש משוכפל שהיה ב-combined_book_screen.dart וב-simple_text_viewer.dart.
/// משתמש ב-[buildDirectLinkSubmenuEntries] (לוגיקה טהורה) ועוטף ב-
/// [AppContextMenuEntry] עם אייקון אחיד וקריאה ל-[copyLinkToClipboard].
List<AppContextMenuEntry> buildDirectLinkContextMenuEntries({
  required int bookId,
  required int index,
  required String? selectedText,
}) {
  final entries = buildDirectLinkSubmenuEntries(
    bookId: bookId,
    index: index,
    selectedText: selectedText,
  );
  return entries
      .map((e) => AppContextMenuEntry(
            label: e.label,
            icon: FluentIcons.link_24_regular,
            enabled: e.link != null,
            onTap: e.link != null ? () => copyLinkToClipboard(e.link!) : null,
          ))
      .toList();
}
