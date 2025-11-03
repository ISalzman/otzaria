import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart' as ctx;
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/view/commentary_list_base.dart';
import 'package:otzaria/widgets/progressive_scrolling.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/personal_notes/personal_notes_system.dart';
import 'package:otzaria/core/scaffold_messenger.dart';

class CombinedView extends StatefulWidget {
  CombinedView({
    super.key,
    required this.data,
    required this.openBookCallback,
    required this.openLeftPaneTab,
    required this.textSize,
    required this.showCommentaryAsExpansionTiles,
    required this.tab,
  });

  final List<String> data;
  final Function(OpenedTab) openBookCallback;
  final void Function(int) openLeftPaneTab;
  final double textSize;
  final bool showCommentaryAsExpansionTiles;
  final TextBookTab tab;

  @override
  State<CombinedView> createState() => _CombinedViewState();
}

class _CombinedViewState extends State<CombinedView> {
  final GlobalKey<SelectionAreaState> _selectionKey =
      GlobalKey<SelectionAreaState>();

  // שמירת reference ל-BLoC לשימוש ב-listeners
  late final TextBookBloc _textBookBloc;

  @override
  void initState() {
    super.initState();
    // שמירת ה-BLoC מראש
    _textBookBloc = context.read<TextBookBloc>();

    // האזנה לשינויים במיקומי הפריטים כדי לאפס את הבחירה בגלילה
    widget.tab.positionsListener.itemPositions.addListener(_onScroll);
    // עדכון האינדקס ב-tab בזמן אמת
    widget.tab.positionsListener.itemPositions.addListener(_updateTabIndex);
  }

  @override
  void dispose() {
    widget.tab.positionsListener.itemPositions.removeListener(_onScroll);
    widget.tab.positionsListener.itemPositions.removeListener(_updateTabIndex);
    super.dispose();
  }

  // עדכון האינדקס הנוכחי ב-tab
  void _updateTabIndex() {
    final positions = widget.tab.positionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      // שומר את האינדקס של הפריט הראשון הנראה
      widget.tab.index = positions.first.index;
    }
  }

  // פונקציה שתשלח אירוע איפוס ל-selectedIndex אם יש גלילה משמעותית
  void _onScroll() {
    // אנחנו רוצים את הלוגיקה הזו רק בתצוגה המפוצלת (SimpleBookView לשעבר)
    // שבה המפרשים מוצגים בפאנל צד (כלומר: לא ExpansionTiles)
    if (widget.showCommentaryAsExpansionTiles) return;

    final state = _textBookBloc.state;
    if (state is! TextBookLoaded) return;

    final currentSelectedIndex = state.selectedIndex;

    if (currentSelectedIndex != null) {
      // אם האינדקס הנבחר כבר לא נראה (האינדקסים הנראים שונו עקב גלילה)
      final visibleIndices = state.visibleIndices;
      if (!visibleIndices.contains(currentSelectedIndex)) {
        _textBookBloc.add(const UpdateSelectedIndex(null));
      }
    }
  }

  // מעקב אחר בחירת טקסט בלי setState
  // שמירת טקסט נוכחי לבניית הערה חדשה
  String? _selectedText;
  String? _lastSelectedText;
  // מעקב אחר האינדקס הנוכחי שנבחר

  Future<void> _createNoteForLine(int paragraphIndex) async {
    if (paragraphIndex < 0 || paragraphIndex >= widget.data.length) {
      return;
    }

    final controller = TextEditingController(
      text: (_lastSelectedText ?? _selectedText)?.trim() ?? '',
    );

    final noteContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => PersonalNoteEditorDialog(
        title: 'הוסף הערה לקטע זה',
        controller: controller,
      ),
    );

    if (noteContent == null) {
      return;
    }

    final trimmed = noteContent.trim();
    if (trimmed.isEmpty) {
      UiSnack.show('ההערה ריקה, לא נשמרה');
      return;
    }

    if (!mounted) return;

    try {
      context.read<PersonalNotesBloc>().add(AddPersonalNote(
            bookId: widget.tab.book.title,
            lineNumber: paragraphIndex + 1,
            content: trimmed,
          ));
      UiSnack.show('ההערה נשמרה בהצלחה');
      widget.openLeftPaneTab(2);
    } catch (e) {
      UiSnack.showError('שמירת ההערה נכשלה: $e');
    }
  }


  ctx.ContextMenu _buildContextMenuForIndex(
    TextBookLoaded state,
    int index,
  ) {
    return ctx.ContextMenu(
      entries: [
        ctx.MenuItem(
          label: 'הוסף הערה לקטע זה',
          onSelected: () => _createNoteForLine(index),
        ),
        const ctx.MenuDivider(),
        ctx.MenuItem(
          label: 'העתק פסקה',
          onSelected: () => _copyParagraphText(index),
        ),
        ctx.MenuItem(
          label: 'העתק קטע גלוי',
          onSelected: () => _copyVisibleText(state),
        ),
      ],
    );
  }

  Future<void> _copyParagraphText(int index) async {
    if (index < 0 || index >= widget.data.length) return;

    final raw = widget.data[index];
    final plainText = utils.stripHtmlIfNeeded(raw).trim();
    if (plainText.isEmpty) {
      UiSnack.show('הטקסט ריק, אין מה להעתיק');
      return;
    }

    await Clipboard.setData(ClipboardData(text: plainText));
    UiSnack.show('הפסקה הועתקה ללוח');
  }

  Future<void> _copyVisibleText(TextBookLoaded state) async {
    if (state.visibleIndices.isEmpty) {
      UiSnack.show('אין טקסט גלוי להעתקה');
      return;
    }

    final buffer = StringBuffer();
    for (final index in state.visibleIndices) {
      if (index < 0 || index >= widget.data.length) continue;
      final raw = widget.data[index];
      final plain = utils.stripHtmlIfNeeded(raw).trim();
      if (plain.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.writeln(plain);
      }
    }

    if (buffer.isEmpty) {
      UiSnack.show('אין טקסט גלוי להעתקה');
      return;
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    UiSnack.show('הטקסט הגלוי הועתק');
  }

  Widget buildKeyboardListener() {
    return BlocBuilder<TextBookBloc, TextBookState>(
      bloc: context.read<TextBookBloc>(),
      builder: (context, state) {
        if (state is! TextBookLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        return ProgressiveScroll(
          maxSpeed: 10000.0,
          curve: 10.0,
          accelerationFactor: 5,
          scrollController: widget.tab.mainOffsetController,
          child: SelectionArea(
            key: _selectionKey,
            contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            onSelectionChanged: (selection) {
              final text = selection?.plainText ?? '';
              if (text.isEmpty) {
                _selectedText = null;
                // עדכון ה-BLoC שאין טקסט נבחר
                context
                    .read<TextBookBloc>()
                    .add(const UpdateSelectedTextForNote(null, null, null));
              } else {
                _selectedText = text;

                // ניסיון לזהות את האינדקס על בסיס התוכן
                // שמירת הבחירה האחרונה
                _lastSelectedText = text;

                // עדכון ה-BLoC עם הטקסט הנבחר
                context
                    .read<TextBookBloc>()
                    .add(UpdateSelectedTextForNote(text, 0, text.length));
              }
              // בלי setState – כדי לא לרנדר את כל העץ תוך כדי גרירת הבחירה
            },
            // שים לב: אין כאן יותר ContextMenuRegion עוטף את כל הרשימה.
            child: buildOuterList(state),
          ),
        );
      },
    );
  }

  Widget buildOuterList(TextBookLoaded state) {
    return ScrollablePositionedList.builder(
      key: ValueKey('combined-${widget.tab.book.title}'),
      initialScrollIndex: widget.tab.index,
      itemPositionsListener: widget.tab.positionsListener,
      itemScrollController: widget.tab.scrollController,
      scrollOffsetController: widget.tab.mainOffsetController,
      itemCount: widget.data.length,
      itemBuilder: (context, index) {
        ExpansibleController controller = ExpansibleController();
        return buildExpansiomTile(controller, index, state);
      },
    );
  }

  Widget buildExpansiomTile(
    ExpansibleController controller,
    int index,
    TextBookLoaded state,
  ) {
    final isSelected = state.selectedIndex == index;
    final isHighlighted = state.highlightedLine == index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isSelected && !controller.isExpanded) {
        controller.expand();
      } else if (!isSelected && controller.isExpanded) {
        controller.collapse();
      }
    });

    final theme = Theme.of(context);
    final backgroundColor = () {
      if (isHighlighted) {
        return theme.colorScheme.secondaryContainer.withValues(alpha: 0.4);
      }
      if (isSelected) {
        return theme.colorScheme.primary.withValues(alpha: 0.08);
      }
      return null;
    }();

    return ctx.ContextMenuRegion(
      contextMenu: _buildContextMenuForIndex(state, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration:
            backgroundColor != null ? BoxDecoration(color: backgroundColor) : null,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: ExpansionTile(
            shape: const Border(),
            controller: controller,
            key: PageStorageKey(widget.data[index]),
            iconColor: Colors.transparent,
            tilePadding: const EdgeInsets.all(0.0),
            collapsedIconColor: Colors.transparent,
            // הסרת כל הצבעים והאפקטים מה-ExpansionTile - נשתמש רק ב-Container למעלה
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            // ביטול אפקטי hover ו-splash
            visualDensity: VisualDensity.compact,
            // הסרת onExpansionChanged - נטפל בלחיצות ידנית
            title: GestureDetector(
              // רק לחיצה על ה-title תפתח/תסגור את המפרשים
              onTap: () {
                if (controller.isExpanded) {
                  controller.collapse();
                  _textBookBloc.add(const UpdateSelectedIndex(null));
                } else {
                  controller.expand();
                  _textBookBloc.add(UpdateSelectedIndex(index));
                }
              },
              child: Padding(
                // padding קטן לעיצוב
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocBuilder<SettingsBloc, SettingsState>(
                      builder: (context, settingsState) {
                        String data = widget.data[index];
                        if (!settingsState.showTeamim) {
                          data = utils.removeTeamim(data);
                        }
                        if (settingsState.replaceHolyNames) {
                          data = utils.replaceHolyNames(data);
                        }

                        return HtmlWidget(
                          '''
                        <div style="text-align: justify; direction: rtl;">
                          ${() {
                            String processedData = state.removeNikud
                                ? utils.highLight(utils.removeVolwels('$data\n'),
                                    state.searchText)
                                : utils.highLight('$data\n', state.searchText);
                            // החלת עיצוב הסוגריים העגולים
                            return utils.formatTextWithParentheses(processedData);
                          }()}
                        </div>
                        ''',
                          textStyle: TextStyle(
                            fontSize: widget.textSize,
                            fontFamily: settingsState.fontFamily,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            children: [
              if (widget.showCommentaryAsExpansionTiles)
                CommentaryListBase(
                  indexes: [index],
                  fontSize: widget.textSize,
                  openBookCallback: widget.openBookCallback,
                  showSearch: false,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildKeyboardListener();
  }

}
