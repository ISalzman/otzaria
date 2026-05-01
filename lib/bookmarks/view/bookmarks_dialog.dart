import 'package:flutter/material.dart';
import 'package:otzaria/bookmarks/view/bookmark_screen.dart';
import 'package:otzaria/widgets/dialogs/reusable_items_dialog.dart';

class BookmarksDialog extends StatelessWidget {
  const BookmarksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ReusableItemsDialog(
      title: 'סימניות',
      child: const BookmarkView(),
    );
  }
}
