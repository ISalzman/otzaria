import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/tzurat_hadaf/tzurat_hadaf_dialog.dart';
import 'package:otzaria/text_book/view/tzurat_hadaf/paginated_main_text_viewer.dart';
import 'package:otzaria/text_book/view/tzurat_hadaf/commentary_viewer.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/models/books.dart';

class TzuratHadafScreen extends StatefulWidget {
  final Function(OpenedTab) openBookCallback;

  const TzuratHadafScreen({super.key, required this.openBookCallback});

  @override
  State<TzuratHadafScreen> createState() => _TzuratHadafScreenState();
}

class _TzuratHadafScreenState extends State<TzuratHadafScreen> {
  String? _leftCommentator;
  String? _rightCommentator;
  String? _bottomCommentator;
  String? _bottomRightCommentator;

  double _leftWidth = 200.0;
  double _rightWidth = 200.0;
  double _bottomHeight = 150.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadConfiguration();
  }

  Map<String, String?> _getDefaultCommentators(TextBook book) {
    final categoryPath = book.category?.path ?? '';

    // שים לב: בגלל RTL, 'right' מוצג בשמאל ו-'left' מוצג בימין
    // תנ"ך - תורה
    if (categoryPath.contains('תנך') && categoryPath.contains('תורה')) {
      final bookTitle = book.title;
      return {
        'right': 'רמבן על $bookTitle', // יוצג בשמאל
        'left': 'רשי על $bookTitle', // יוצג בימין
        'bottom': 'אור החיים על $bookTitle',
      };
    }

    // משנה
    if (categoryPath.contains('משנה')) {
      final bookTitle = book.title;
      return {
        'right': 'תוספות יום טוב על $bookTitle', // יוצג בשמאל
        'left': 'ברטנורא על $bookTitle', // יוצג בימין
        'bottom': 'עיקר תוספות יום טוב על $bookTitle',
      };
    }

    // תלמוד בבלי
    if (categoryPath.contains('תלמוד בבלי')) {
      final bookTitle = book.title;
      return {
        'right': 'תוספות על $bookTitle', // יוצג בשמאל
        'left': 'רשי על $bookTitle', // יוצג בימין
        'bottom': null,
      };
    }

    // תלמוד ירושלמי
    if (categoryPath.contains('תלמוד ירושלמי')) {
      final bookTitle = book.title;
      return {
        'right': 'נועם ירושלמי על $bookTitle', // יוצג בשמאל
        'left': 'פני משה על תלמוד ירושלמי $bookTitle', // יוצג בימין
        'bottom': null,
      };
    }

    // דוגמאות לברירות מחדל נוספות:
    //
    // // תנ"ך - נביאים
    // if (categoryPath.contains('תנ"ך') && categoryPath.contains('נביאים')) {
    //   final bookTitle = book.title;
    //   return {
    //     'right': 'מצודת דוד על $bookTitle',    // יוצג בשמאל
    //     'left': 'רש"י על $bookTitle',          // יוצג בימין
    //     'bottom': 'מלבי"ם על $bookTitle',
    //   };
    // }

    // אם אין ברירת מחדל, החזר ערכים ריקים
    return {
      'right': null,
      'left': null,
      'bottom': null,
      'bottomRight': null,
    };
  }

  void _loadConfiguration() {
    final state = context.read<TextBookBloc>().state;
    if (state is! TextBookLoaded) return;

    final settingsKey = 'tzurat_hadaf_config_${state.book.title}';
    final configString = Settings.getValue<String>(settingsKey);

    if (configString != null) {
      try {
        final config = json.decode(configString) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _leftCommentator = config['left'];
            _rightCommentator = config['right'];
            _bottomCommentator = config['bottom'];
            _bottomRightCommentator = config['bottomRight'];
          });
        }
      } catch (e) {
        // malformed JSON
      }
    } else {
      // אם אין הגדרה שמורה, השתמש בברירות מחדל
      final defaults = _getDefaultCommentators(state.book);
      if (mounted) {
        setState(() {
          _leftCommentator = defaults['left'];
          _rightCommentator = defaults['right'];
          _bottomCommentator = defaults['bottom'];
          _bottomRightCommentator = defaults['bottomRight'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TextBookBloc, TextBookState>(
      builder: (context, state) {
        if (state is! TextBookLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              // Main Content Row
              Expanded(
                child: Row(
                  children: [
                    // Left Commentary
                    if (_leftCommentator != null) ...[
                      SizedBox(
                        width: _leftWidth,
                        child: CommentaryViewer(
                          commentatorName: _leftCommentator,
                          selectedIndex: state.selectedIndex,
                          textBookState: state,
                        ),
                      ),
                      _ResizableDivider(
                        isVertical: true,
                        onDrag: (delta) {
                          setState(() {
                            _leftWidth =
                                (_leftWidth - delta).clamp(100.0, 500.0);
                          });
                        },
                      ),
                    ],
                    // Main Text
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
                          children: [
                            PaginatedMainTextViewer(
                              textBookState: state,
                              openBookCallback: widget.openBookCallback,
                              scrollController: state.scrollController,
                            ),
                            // Settings button
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(230),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.settings, size: 18),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final result = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => TzuratHadafDialog(
                                        availableCommentators:
                                            state.availableCommentators,
                                        bookTitle: state.book.title,
                                      ),
                                    );
                                    if (result == true && mounted) {
                                      _loadConfiguration();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Commentary
                    if (_rightCommentator != null) ...[
                      _ResizableDivider(
                        isVertical: true,
                        onDrag: (delta) {
                          setState(() {
                            _rightWidth =
                                (_rightWidth + delta).clamp(100.0, 500.0);
                          });
                        },
                      ),
                      SizedBox(
                        width: _rightWidth,
                        child: CommentaryViewer(
                          commentatorName: _rightCommentator,
                          selectedIndex: state.selectedIndex,
                          textBookState: state,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Bottom Commentary
              if (_bottomCommentator != null || _bottomRightCommentator != null) ...[
                _ResizableDivider(
                  isVertical: false,
                  onDrag: (delta) {
                    setState(() {
                      _bottomHeight =
                          (_bottomHeight + delta).clamp(100.0, 400.0);
                    });
                  },
                ),
                SizedBox(
                  height: _bottomHeight,
                  child: _bottomRightCommentator != null
                      ? Row(
                          children: [
                            if (_bottomCommentator != null) ...[
                              Expanded(
                                child: CommentaryViewer(
                                  commentatorName: _bottomCommentator,
                                  selectedIndex: state.selectedIndex,
                                  textBookState: state,
                                ),
                              ),
                              _ResizableDivider(
                                isVertical: true,
                                onDrag: (delta) {
                                  // אפשר להוסיף כאן שליטה ברוחב אם רוצים
                                },
                              ),
                            ],
                            Expanded(
                              child: CommentaryViewer(
                                commentatorName: _bottomRightCommentator,
                                selectedIndex: state.selectedIndex,
                                textBookState: state,
                              ),
                            ),
                          ],
                        )
                      : CommentaryViewer(
                          commentatorName: _bottomCommentator,
                          selectedIndex: state.selectedIndex,
                          textBookState: state,
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ResizableDivider extends StatefulWidget {
  final bool isVertical;
  final Function(double) onDrag;

  const _ResizableDivider({
    required this.isVertical,
    required this.onDrag,
  });

  @override
  State<_ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<_ResizableDivider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isVertical
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onPanUpdate: (details) {
          widget.onDrag(
            widget.isVertical ? details.delta.dx : details.delta.dy,
          );
        },
        child: Container(
          width: widget.isVertical ? 8 : null,
          height: widget.isVertical ? null : 8,
          color: _isHovered
              ? Colors.grey.withValues(alpha: 0.3)
              : Colors.transparent,
          child: _isHovered
              ? Center(
                  child: Container(
                    width: widget.isVertical ? 2 : null,
                    height: widget.isVertical ? null : 2,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
