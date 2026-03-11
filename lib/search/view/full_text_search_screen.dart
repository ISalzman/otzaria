import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/search/view/tantivy_full_text_search.dart';
import 'package:flutter/material.dart';

class FullTextSearchScreen extends StatelessWidget {
  final SearchingTab tab;
  const FullTextSearchScreen({super.key, required this.tab});
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: tab.searchBloc,
      child: TantivyFullTextSearch(
        tab: tab,
      ),
    );
  }
}
