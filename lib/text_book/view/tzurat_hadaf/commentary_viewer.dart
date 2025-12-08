import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

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
  String? _fullContent;
  final Map<int, int> _indexToLineMap = {};
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  @override
  void initState() {
    super.initState();
    _loadFullCommentary();
  }

  @override
  void didUpdateWidget(CommentaryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commentatorName != widget.commentatorName) {
      _loadFullCommentary();
    } else if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFullCommentary() async {
    if (widget.commentatorName == null) {
      setState(() {
        _fullContent = null;
        _indexToLineMap.clear();
      });
      return;
    }

    final repo = context.read<TextBookBloc>().repository;
    
    // Build map of main text index to commentary line
    _indexToLineMap.clear();
    print('Building index map for commentator: ${widget.commentatorName}');
    print('Total links: ${widget.textBookState.links.length}');
    
    for (final link in widget.textBookState.links) {
      final linkTitle = utils.getTitleFromPath(link.path2);
      if (linkTitle == widget.commentatorName) {
        _indexToLineMap[link.index1 - 1] = link.index2 - 1;
        print('Mapped main index ${link.index1 - 1} -> commentary line ${link.index2 - 1}');
      }
    }
    
    print('Index map size: ${_indexToLineMap.length}');

    try {
      final book = TextBook(title: widget.commentatorName!);
      final content = await repo.getBookContent(book);
      if (mounted) {
        setState(() {
          _fullContent = content;
        });
        _scrollToSelected();
      }
    } catch (e) {
      print('Error loading commentary: $e');
      if (mounted) {
        setState(() {
          _fullContent = '';
        });
      }
    }
  }

  void _scrollToSelected() {
    print('Commentary [${widget.commentatorName}]: selectedIndex=${widget.selectedIndex}, map size=${_indexToLineMap.length}');
    
    if (widget.selectedIndex == null || !_indexToLineMap.containsKey(widget.selectedIndex)) {
      print('Commentary [${widget.commentatorName}]: No scroll - selectedIndex: ${widget.selectedIndex}, has mapping: ${_indexToLineMap.containsKey(widget.selectedIndex ?? -1)}');
      return;
    }

    final lineIndex = _indexToLineMap[widget.selectedIndex];
    print('Commentary [${widget.commentatorName}]: Scrolling to line $lineIndex for main text index ${widget.selectedIndex}');
    
    if (lineIndex != null && _lineKeys.containsKey(lineIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _lineKeys[lineIndex];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fullContent == null) {
      return Center(
        child: Text(
          widget.commentatorName ?? 'בחר מפרש',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_fullContent!.isEmpty) {
      return const Center(child: Text('התוכן לא נמצא'));
    }

    final lines = _fullContent!.split('\n');
    final selectedLineIndex = widget.selectedIndex != null 
        ? _indexToLineMap[widget.selectedIndex]
        : null;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        _lineKeys[index] = GlobalKey();
        final isSelected = index == selectedLineIndex;
        
        return Container(
          key: _lineKeys[index],
          color: isSelected ? Colors.yellow.withAlpha(100) : null,
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            _stripHtmlTags(lines[index]),
            style: TextStyle(
              fontSize: widget.textBookState.fontSize * 0.8,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
          ),
        );
      },
    );
  }

  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
