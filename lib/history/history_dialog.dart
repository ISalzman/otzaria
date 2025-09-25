import 'package:flutter/material.dart';
import 'package:otzaria/history/history_screen.dart';
import 'package:otzaria/widgets/reusable_items_dialog.dart';

class HistoryDialog extends StatelessWidget {
  const HistoryDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReusableItemsDialog(
      title: 'היסטוריה',
      child: const HistoryView(),
    );
  }
}
