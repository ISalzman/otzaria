import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/text_book/view/tzurat_hadaf/non_linear_text_widget.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';

// Helper class to pass parameters to the isolate.
class _PageCalculationParams {
  final List<String> content;
  final double fontSize;
  final String? fontFamily;
  final bool showTeamim;
  final bool replaceHolyNames;
  final bool removeNikud;
  final double availableWidth;
  final double availableHeight;
  final TextDirection textDirection;

  _PageCalculationParams({
    required this.content,
    required this.fontSize,
    this.fontFamily,
    required this.showTeamim,
    required this.replaceHolyNames,
    required this.removeNikud,
    required this.availableWidth,
    required this.availableHeight,
    required this.textDirection,
  });
}

// This function will run in a separate isolate.
List<List<int>> _calculatePagesIsolate(_PageCalculationParams params) {
  final textStyle = TextStyle(
    fontSize: params.fontSize,
    fontFamily: params.fontFamily,
    height: 1.5,
    color: Colors.black,
  );

  List<List<int>> pages = [];
  List<int> currentPage = [];
  double currentPageHeight = 0;

  for (int i = 0; i < params.content.length; i++) {
    String data = params.content[i];
    if (!params.showTeamim) {
      data = utils.removeTeamim(data);
    }
    if (params.replaceHolyNames) {
      data = utils.replaceHolyNames(data);
    }
    if (params.removeNikud) {
      data = utils.removeVolwels(data);
    }
    String strippedData = data.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');

    final painter = NonLinearTextPainter(
      text: strippedData,
      style: textStyle,
      textDirection: params.textDirection,
    );
    final lineHeight = painter.calculateHeight(params.availableWidth);

    if (currentPageHeight + lineHeight > params.availableHeight &&
        currentPage.isNotEmpty) {
      pages.add(currentPage);
      currentPage = [];
      currentPageHeight = 0;
    }
    currentPage.add(i);
    currentPageHeight += lineHeight;
  }
  if (currentPage.isNotEmpty) {
    pages.add(currentPage);
  }

  return pages;
}

class PaginatedMainTextViewer extends StatefulWidget {
  final TextBookLoaded textBookState;
  final Function(OpenedTab) openBookCallback;

  const PaginatedMainTextViewer({
    super.key,
    required this.textBookState,
    required this.openBookCallback,
  });

  @override
  _PaginatedMainTextViewerState createState() =>
      _PaginatedMainTextViewerState();
}

class _PaginatedMainTextViewerState extends State<PaginatedMainTextViewer> {
  final PageController _pageController = PageController();
  List<List<int>>? _pages;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePages();
    });
  }

  @override
  void didUpdateWidget(PaginatedMainTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textBookState.content.hashCode !=
            widget.textBookState.content.hashCode ||
        oldWidget.textBookState.fontSize != widget.textBookState.fontSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculatePages();
      });
    }
  }

  Future<void> _calculatePages() async {
    final availableWidth = context.size?.width;
    final availableHeight = context.size?.height;
    if (availableWidth == null ||
        availableWidth == 0 ||
        availableHeight == null ||
        availableHeight == 0) return;

    setState(() {
      _isLoading = true;
    });

    final settingsState = context.read<SettingsBloc>().state;
    final params = _PageCalculationParams(
      content: widget.textBookState.content,
      fontSize: widget.textBookState.fontSize,
      fontFamily: settingsState.fontFamily,
      showTeamim: settingsState.showTeamim,
      replaceHolyNames: settingsState.replaceHolyNames,
      removeNikud: widget.textBookState.removeNikud,
      availableWidth: availableWidth,
      availableHeight: availableHeight,
      textDirection: Directionality.of(context),
    );

    final pages = await compute(_calculatePagesIsolate, params);

    if (mounted) {
      setState(() {
        _pages = pages;
        _isLoading = false;
      });
    }
  }

  String _stripHtmlTags(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pages == null || _pages!.isEmpty) {
      return const Center(child: Text('לא נמצא תוכן להצגה'));
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _pages!.length,
      itemBuilder: (context, pageIndex) {
        final pageLines = _pages![pageIndex];
        // Temporary fix: Use SingleChildScrollView to prevent overflow
        return SingleChildScrollView(
          child: Column(
            children: pageLines.map((lineIndex) {
              return _buildLine(lineIndex);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLine(int index) {
    final state = widget.textBookState;
    final isSelected = state.selectedIndex == index;
    final isHighlighted = state.highlightedLine == index;

    final theme = Theme.of(context);
    final backgroundColor = () {
      if (isHighlighted) {
        return theme.colorScheme.secondaryContainer.withAlpha(100);
      }
      if (isSelected) {
        return theme.colorScheme.primaryContainer.withAlpha(50);
      }
      return null;
    }();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        context.read<TextBookBloc>().add(UpdateSelectedIndex(index));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            String data = state.content[index];

            // Apply text manipulations
            if (!settingsState.showTeamim) {
              data = utils.removeTeamim(data);
            }
            if (settingsState.replaceHolyNames) {
              data = utils.replaceHolyNames(data);
            }
            if (state.removeNikud) {
              data = utils.removeVolwels(data);
            }

            // Highlight search text
            String processedData = utils.highLight(data, state.searchText);
            processedData = utils.formatTextWithParentheses(processedData);

            return NonLinearText(
              text: _stripHtmlTags(processedData),
              style: TextStyle(
                fontSize: state.fontSize,
                fontFamily: settingsState.fontFamily,
                height: 1.5,
                color: Colors.black, // Explicitly set color for diagnosis
              ),
            );
          },
        ),
      ),
    );
  }
}
