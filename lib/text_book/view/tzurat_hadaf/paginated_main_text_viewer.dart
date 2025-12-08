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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: widget.textBookState.content.length,
      itemBuilder: (context, index) => _buildLine(index, theme),
    );
  }

  Widget _buildLine(int index, ThemeData theme) {
    final state = widget.textBookState;
    final isSelected = state.selectedIndex == index;
    final isHighlighted = state.highlightedLine == index;
    
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
                color: theme.colorScheme.onSurface,
              ),
            );
          },
        ),
      ),
    );
  }

  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
