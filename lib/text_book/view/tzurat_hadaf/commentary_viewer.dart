import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/view/tzurat_hadaf/widgets/search_header.dart';

class CommentaryViewer extends StatefulWidget {
  final String? commentatorName;
  final int? selectedIndex;
  final TextBookLoaded textBookState;

  const CommentaryViewer({
    super.key,
    required this.commentatorName,
    required this.selectedIndex,
    required this.textBookState,
  });

  @override
  State<CommentaryViewer> createState() => _CommentaryViewerState();
}

class _CommentaryViewerState extends State<CommentaryViewer> {
  final ItemScrollController _scrollController = ItemScrollController();
  List<Link> _relevantLinks = [];

  // Cache for loaded book contents - עכשיו שומר את כל התוכן של הספר
  final Map<String, List<String>> _loadedBooks = {};

  // התוכן המלא של המפרש הנוכחי
  List<String>? _commentaryContent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCommentary();
  }

  @override
  void didUpdateWidget(CommentaryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commentatorName != widget.commentatorName) {
      _loadCommentary();
    } else if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  /// טעינת המפרש המלא + הקישורים שלו
  Future<void> _loadCommentary() async {
    if (widget.commentatorName == null) {
      setState(() {
        _relevantLinks = [];
        _commentaryContent = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. טעינת הקישורים (לסנכרון בלבד)
      final links = widget.textBookState.links.where((link) {
        return utils.getTitleFromPath(link.path2) == widget.commentatorName;
      }).toList();

      // Sort by index1 to maintain order
      links.sort((a, b) => a.index1.compareTo(b.index1));

      // 2. טעינת התוכן המלא של המפרש
      List<String>? content;

      if (links.isNotEmpty) {
        final bookPath = links.first.path2;

        // בדיקה אם כבר טענו את הספר הזה
        if (_loadedBooks.containsKey(bookPath)) {
          content = _loadedBooks[bookPath];
        } else {
          // טעינת הספר לראשונה
          final book = TextBook(title: utils.getTitleFromPath(bookPath));
          final bookContent = await book.text;
          final lines = bookContent.split('\n');
          _loadedBooks[bookPath] = lines;
          content = lines;
        }
      }

      if (mounted) {
        setState(() {
          _relevantLinks = links;
          _commentaryContent = content;
          _isLoading = false;
        });

        _scrollToSelected();
      }
    } catch (e) {
      debugPrint('Error loading commentary: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _commentaryContent = null;
        });
      }
    }
  }

  /// גלילה לשורה המתאימה במפרש בהתבסס על הקישורים
  void _scrollToSelected() {
    if (widget.selectedIndex == null ||
        _relevantLinks.isEmpty ||
        _commentaryContent == null ||
        !_scrollController.isAttached) {
      return;
    }

    // מציאת הקישור המתאים או הקרוב ביותר
    Link? matchingLink;

    // ניסיון למצוא קישור מדויק
    try {
      matchingLink = _relevantLinks.firstWhere(
        (link) => link.index1 - 1 == widget.selectedIndex,
      );
    } catch (e) {
      // אין קישור מדויק - מחפשים את הקישור הקרוב ביותר
      matchingLink = _findClosestLink(widget.selectedIndex!);
    }

    if (matchingLink == null) {
      return; // אין קישורים בכלל
    }

    // הקישור מצביע על שורה במפרש (index2)
    final targetLineInCommentary = matchingLink.index2 - 1;

    // גלילה לשורה הזו במפרש
    if (targetLineInCommentary >= 0 &&
        targetLineInCommentary < _commentaryContent!.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.isAttached) {
          _scrollController.scrollTo(
            index: targetLineInCommentary,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        }
      });
    }
  }

  /// מציאת הקישור הקרוב ביותר לאינדקס נתון
  /// מעדיף קישור קודם (לפני האינדקס) על פני קישור הבא
  Link? _findClosestLink(int targetIndex) {
    if (_relevantLinks.isEmpty) return null;

    Link? closestBefore;
    Link? closestAfter;
    int minDistanceBefore = double.maxFinite.toInt();
    int minDistanceAfter = double.maxFinite.toInt();

    for (final link in _relevantLinks) {
      final linkIndex = link.index1 - 1;
      final distance = (linkIndex - targetIndex).abs();

      if (linkIndex <= targetIndex) {
        // קישור לפני או שווה לאינדקס הנוכחי
        if (distance < minDistanceBefore) {
          minDistanceBefore = distance;
          closestBefore = link;
        }
      } else {
        // קישור אחרי האינדקס הנוכחי
        if (distance < minDistanceAfter) {
          minDistanceAfter = distance;
          closestAfter = link;
        }
      }
    }

    // מעדיפים קישור קודם (לפני) על פני קישור הבא
    return closestBefore ?? closestAfter;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.commentatorName == null) {
      return const Center(
        child: Text(
          'בחר מפרש',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_isLoading) {
      return Column(
        children: [
          SearchHeader(
            title: widget.commentatorName!,
            titleFontSize: 14,
          ),
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_commentaryContent == null || _commentaryContent!.isEmpty) {
      return Column(
        children: [
          SearchHeader(
            title: widget.commentatorName!,
            titleFontSize: 14,
          ),
          const Expanded(
            child: Center(child: Text('אין תוכן להצגה')),
          ),
        ],
      );
    }

    return Column(
      children: [
        SearchHeader(
          title: widget.commentatorName!,
          titleFontSize: 14,
        ),
        Expanded(
          child: ScrollablePositionedList.builder(
            itemScrollController: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: _commentaryContent!.length,
            itemBuilder: (context, index) {
              final content = _commentaryContent![index];

              // בדיקה אם השורה הזו במפרש מקושרת לטקסט המרכזי
              final correspondingLink = _relevantLinks.firstWhere(
                (link) => link.index2 - 1 == index,
                orElse: () => Link(
                  heRef: '',
                  index1: -1,
                  path2: '',
                  index2: index + 1,
                  connectionType: '',
                ),
              );

              final lineIndexInMainText = correspondingLink.index1 - 1;
              final hasLink = correspondingLink.index1 != -1;

              // הדגשה רק אם יש קישור והשורה בטקסט המרכזי נבחרה
              final isSelected = hasLink &&
                  widget.selectedIndex != null &&
                  lineIndexInMainText == widget.selectedIndex;

              final isHighlighted = hasLink &&
                  widget.textBookState.highlightedLine == lineIndexInMainText;

              return BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, settingsState) {
                  String displayText = content;
                  if (settingsState.replaceHolyNames) {
                    displayText = utils.replaceHolyNames(displayText);
                  }
                  if (widget.textBookState.removeNikud) {
                    displayText = utils.removeVolwels(displayText);
                  }

                  final backgroundColor = () {
                    if (isHighlighted) {
                      return Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.4);
                    }
                    if (isSelected) {
                      return Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(40);
                    }
                    return null;
                  }();

                  return GestureDetector(
                    onTap: hasLink
                        ? () {
                            // גלילה לשורה המתאימה בטקסט המרכזי
                            widget.textBookState.scrollController.scrollTo(
                              index: lineIndexInMainText,
                              alignment: 0.05,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                            );
                            context
                                .read<TextBookBloc>()
                                .add(UpdateSelectedIndex(lineIndexInMainText));
                            context
                                .read<TextBookBloc>()
                                .add(HighlightLine(lineIndexInMainText));
                          }
                        : null, // אם אין קישור, לא עושים כלום
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 2.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: backgroundColor != null
                          ? BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: HtmlWidget(
                        '<div style="text-align: justify; direction: rtl;">$displayText</div>',
                        textStyle: TextStyle(
                          fontSize: widget.textBookState.fontSize * 0.8,
                          fontFamily: settingsState.commentatorsFontFamily,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
