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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadConfiguration();
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
          });
        }
      } catch (e) {
        // malformed JSON
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
          appBar: AppBar(
            title: Text('צורת הדף: ${state.book.title}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => TzuratHadafDialog(
                      availableCommentators: state.availableCommentators,
                      bookTitle: state.book.title,
                    ),
                  );
                  if (result == true && mounted) {
                    _loadConfiguration();
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Headers Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          _leftCommentator ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          state.book.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          _rightCommentator ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Main Content Row
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Left Commentary
                    Expanded(
                      flex: 1,
                      child: CommentaryViewer(
                        commentatorName: _leftCommentator,
                        selectedIndex: state.selectedIndex,
                        textBookState: state,
                      ),
                    ),
                    // Main Text
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: PaginatedMainTextViewer(
                          textBookState: state,
                          openBookCallback: widget.openBookCallback,
                        ),
                      ),
                    ),
                    // Right Commentary
                    Expanded(
                      flex: 1,
                      child: CommentaryViewer(
                        commentatorName: _rightCommentator,
                        selectedIndex: state.selectedIndex,
                        textBookState: state,
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Commentary
              if (_bottomCommentator != null)
                Expanded(
                  flex: 1,
                  child: CommentaryViewer(
                    commentatorName: _bottomCommentator,
                    selectedIndex: state.selectedIndex,
                    textBookState: state,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
