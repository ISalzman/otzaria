// a widget that takes an html strings array, finds all the headings, and displays it in a listview. on pressed the scrollcontroller scrolls to the index of the heading.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'dart:io';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/models/links.dart';

class LinksViewer extends StatefulWidget {
  final Function(OpenedTab tab) openTabcallback;
  final ItemPositionsListener itemPositionsListener;
  final void Function() closeLeftPanelCallback;
  final void Function() openInSidebarCallback;
  final bool isSplitViewOpen; // האם החלונית פתוחה

  const LinksViewer({
    super.key,
    required this.openTabcallback,
    required this.itemPositionsListener,
    required this.closeLeftPanelCallback,
    required this.openInSidebarCallback,
    required this.isSplitViewOpen,
  });

  /// Returns the visible links for the provided [state].
  ///
  /// This method filters out commentary links and sorts the result by
  /// the book name so that callers such as context menus can easily
  /// display them synchronously.
  static List<Link> getLinks(TextBookLoaded state) {
    // אם יש שורה נבחרת, מציג קישורים עבורה, אחרת עבור השורות הנראות
    final targetIndices = state.selectedIndex != null
        ? [state.selectedIndex!]
        : state.visibleIndices;

    final links = <Link>[];

    for (final index in targetIndices) {
      final indexLinks = state.links
          .where(
            (link) =>
                link.index1 == index + 1 &&
                link.connectionType != 'commentary' &&
                link.connectionType != 'targum',
          )
          .toList();
      links.addAll(indexLinks);
    }

    links.sort(
      (a, b) => a.path2
          .split(Platform.pathSeparator)
          .last
          .compareTo(b.path2.split(Platform.pathSeparator).last),
    );

    return links;
  }

  @override
  State<LinksViewer> createState() => _LinksViewerState();
}

class _LinksViewerState extends State<LinksViewer>
    with AutomaticKeepAliveClientMixin<LinksViewer> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<TextBookBloc, TextBookState>(
      builder: (context, state) {
        if (state is TextBookError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        if (state is! TextBookLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return FutureBuilder(
          future: Future<List<Link>>.value(LinksViewer.getLinks(state)),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final links = snapshot.data!;
              return ListView.builder(
                itemCount: links.length + 1, // +1 עבור הלחצן
                itemBuilder: (context, index) {
                  // הלחצן "פתח/סגור חלונית צד" בתחילת הרשימה
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: widget.openInSidebarCallback,
                        icon: Icon(widget.isSplitViewOpen
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_left),
                        label: Text(widget.isSplitViewOpen
                            ? 'סגור חלונית צד'
                            : 'פתח בחלונית צד'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                    );
                  }

                  // קישורים רגילים
                  final linkIndex = index - 1;
                  return ListTile(
                    key: ValueKey(
                        '${links[linkIndex].path2}_${links[linkIndex].index2}'),
                    title: Text(links[linkIndex].heRef),
                    onTap: () {
                      void open() => widget.openTabcallback(
                            TextBookTab(
                              book: TextBook(
                                  title: utils.getTitleFromPath(
                                      links[linkIndex].path2)),
                              index: links[linkIndex].index2 - 1,
                              openLeftPane:
                                  (Settings.getValue<bool>('key-pin-sidebar') ??
                                          false) ||
                                      (Settings.getValue<bool>(
                                              'key-default-sidebar-open') ??
                                          false),
                            ),
                          );

                      if (MediaQuery.of(context).size.width < 600) {
                        widget.closeLeftPanelCallback();
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => open());
                      } else {
                        open();
                      }
                    },
                  );
                },
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      },
    );
  }

  @override
  get wantKeepAlive => false;
}
