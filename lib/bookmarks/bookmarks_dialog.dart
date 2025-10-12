import 'package:flutter/material.dart';
import 'package:otzaria/bookmarks/bookmark_screen.dart';
import 'package:otzaria/widgets/reusable_items_dialog.dart';

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
