import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:search_highlight_text/search_highlight_text.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/models/search_results.dart';
import 'package:otzaria/text_book/models/text_book_searcher.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:otzaria/widgets/search_pane_base.dart';

class _GroupedResultItem {
  final String? header;
  final TextSearchResult? result;
  const _GroupedResultItem.header(this.header) : result = null;
  const _GroupedResultItem.result(this.result) : header = null;
  bool get isHeader => header != null;
}

class TextBookSearchView extends StatefulWidget {
  final String data;
  final ItemScrollController scrollControler;
  final FocusNode focusNode;
  final void Function() closeLeftPaneCallback;

  const TextBookSearchView(
      {super.key,
      required this.data,
      required this.scrollControler,
      required this.focusNode,
      required this.closeLeftPaneCallback,
      required String initialQuery});

  @override
  TextBookSearchViewState createState() => TextBookSearchViewState();
}

class TextBookSearchViewState extends State<TextBookSearchView>
    with AutomaticKeepAliveClientMixin<TextBookSearchView> {
  TextEditingController searchTextController = TextEditingController();
  late final TextBookSearcher markdownTextSearcher;
  List<TextSearchResult> searchResults = [];
  late ItemScrollController scrollControler;

  @override
  void initState() {
    super.initState();
    markdownTextSearcher = TextBookSearcher(widget.data);
    markdownTextSearcher.addListener(_searchResultUpdated);

    searchTextController.text =
        (context.read<TextBookBloc>().state as TextBookLoaded).searchText;

    scrollControler = widget.scrollControler;
    widget.focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInitialSearch();
    });
  }

  void _runInitialSearch() {
    _searchTextUpdated();
  }

  void _searchTextUpdated() {
    markdownTextSearcher.startTextSearch(searchTextController.text);
  }

  void _searchResultUpdated() {
    if (mounted) {
      setState(() {
        searchResults = markdownTextSearcher.searchResults;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final List<_GroupedResultItem> items = [];
    String? lastAddress;
    for (final r in searchResults) {
      if (lastAddress != r.address) {
        items.add(_GroupedResultItem.header(r.address));
        lastAddress = r.address;
      }
      items.add(_GroupedResultItem.result(r));
    }

    return SearchPaneBase(
      searchController: searchTextController,
      focusNode: widget.focusNode,
      progressWidget: null,
      resultCountString: searchResults.isNotEmpty
          ? 'נמצאו ${searchResults.length} תוצאות'
          : null,
      resultsWidget: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item.isHeader) {
            return BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                String text = item.header!;
                if (settingsState.replaceHolyNames) {
                  text = utils.replaceHolyNames(text);
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                );
              },
            );
          } else {
            final result = item.result!;
            return BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                String snippet = result.snippet;
                if (settingsState.replaceHolyNames) {
                  snippet = utils.replaceHolyNames(snippet);
                }

                return ListTile(
                    subtitle:
                        SearchHighlightText(snippet, searchText: result.query),
                    onTap: () {
                      widget.scrollControler.scrollTo(
                        index: result.index,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.ease,
                      );
                      if (Platform.isAndroid) {
                        widget.closeLeftPaneCallback();
                      }
                    });
              },
            );
          }
        },
      ),
      isNoResults: items.isEmpty && searchTextController.text.isNotEmpty,
      onSearchTextChanged: (value) {
        context.read<TextBookBloc>().add(UpdateSearchText(value));
        _searchTextUpdated();
      },
      resetSearchCallback: () {},
      hintText: 'חפש כאן..',
    );
  }

  @override
  bool get wantKeepAlive => true;
}
