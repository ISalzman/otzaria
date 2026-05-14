import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';

String previewForLabel(String text, {int maxLen = 25}) {
  final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.length <= maxLen) {
    return cleaned;
  }
  return '${cleaned.substring(0, maxLen)}…';
}

void openGlobalSearch(
  BuildContext context,
  String? selectedText, {
  bool insertAdjacent = true,
}) {
  final query = selectedText?.trim() ?? '';
  if (query.isEmpty) {
    UiSnack.show('לא נבחר טקסט לחיפוש');
    return;
  }

  final tab = SearchingTab(SearchingTab.titleForQuery(query), query);
  context.read<HistoryBloc>().add(AddHistory(tab));
  context.read<TabsBloc>().add(AddTab(tab, insertAdjacent: insertAdjacent));
}
