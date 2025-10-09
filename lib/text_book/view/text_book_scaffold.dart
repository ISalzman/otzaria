import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:otzaria/text_book/view/splited_view/splited_view_screen.dart';

class TextBookScaffold extends StatelessWidget {
  final List<String> content;
  final Function(OpenedTab) openBookCallback;
  final void Function(int) openLeftPaneTab;
  final TextEditingValue searchTextController;
  final TextBookTab tab;
  final int? initialSidebarTabIndex;

  const TextBookScaffold({
    super.key,
    required this.content,
    required this.openBookCallback,
    required this.openLeftPaneTab,
    required this.searchTextController,
    required this.tab,
    this.initialSidebarTabIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TextBookBloc, TextBookState>(
      builder: (context, state) {
        if (state is! TextBookLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasSidebarContent = state.activeCommentators.isNotEmpty ||
            initialSidebarTabIndex != null;
        final isSplit = state.showSplitView && hasSidebarContent;

        if (isSplit) {
          return SplitedViewScreen(
            content: content,
            openBookCallback: openBookCallback,
            searchTextController: searchTextController,
            openLeftPaneTab: openLeftPaneTab,
            tab: tab,
            initialTabIndex: initialSidebarTabIndex,
          );
        } else {
          return BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              return Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: settingsState.paddingSize),
                child: CombinedView(
                  data: content,
                  textSize: state.fontSize,
                  openBookCallback: openBookCallback,
                  openLeftPaneTab: openLeftPaneTab,
                  showCommentaryAsExpansionTiles: true,
                  tab: tab,
                ),
              );
            },
          );
        }
      },
    );
  }
}
