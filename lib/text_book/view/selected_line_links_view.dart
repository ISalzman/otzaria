import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/links_screen.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

/// Widget שמציג את הקישורים של השורה הנבחרת בלבד
class SelectedLineLinksView extends StatefulWidget {
  final Function(OpenedTab) openBookCallback;
  final double fontSize;
  final bool
      showVisibleLinksIfNoSelection; // האם להציג קישורים נראים אם אין בחירה

  const SelectedLineLinksView({
    super.key,
    required this.openBookCallback,
    required this.fontSize,
    this.showVisibleLinksIfNoSelection = false,
  });

  @override
  State<SelectedLineLinksView> createState() => _SelectedLineLinksViewState();
}

class _SelectedLineLinksViewState extends State<SelectedLineLinksView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, Future<String>> _contentCache = {};
  final Map<String, bool> _expanded = {};
  bool _searchInContent = false;
  List<Link>? _cachedLinks; // מטמון לקישורים
  String? _lastStateKey; // מפתח למצב הקודם

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// מחזיר את הקישורים עבור השורה הנבחרת או השורות הנראות
  List<Link> _getLinksForSelectedLine(TextBookLoaded state,
      {bool showVisibleIfNoSelection = false}) {
    // תמיד משתמש באותה לוגיקה של LinksViewer.getLinks
    // זה מבטיח עקביות עם הסרגל הצד
    return LinksViewer.getLinks(state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TextBookBloc, TextBookState>(
      builder: (context, state) {
        if (state is! TextBookLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // שדה חיפוש
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'חפש בתוך הקישורים המוצגים...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _searchInContent,
                            onChanged: (value) {
                              setState(() {
                                _searchInContent = value ?? false;
                              });
                            },
                          ),
                          const Text('חפש גם בתוכן הקישורים'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // תוכן הקישורים
            Expanded(
              child: _buildLinksContent(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLinksContent(TextBookLoaded state) {
    // תמיד מציג קישורים באמצעות אותה לוגיקה של הסרגל הצד
    // לא מציג יותר הודעות על בחירת קטע

    // מציג מיד את הקונטיינר ואז טוען את הקישורים
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: FutureBuilder<List<Link>>(
        future: _loadLinksAsync(state),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'שגיאה בטעינת הקישורים: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          final links = snapshot.data ?? [];

          // אם אין קישורים
          if (links.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'לא נמצאו קישורים לקטע הנבחר',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            );
          }

          // מציג את הקישורים
          return ListView.builder(
            itemCount: links.length,
            itemBuilder: (context, index) {
              final link = links[index];

              // בדיקת חיפוש בכותרת ושם הספר (ללא טעינת תוכן)
              if (_searchQuery.isNotEmpty) {
                final title = link.heRef.toLowerCase();
                final bookTitle =
                    utils.getTitleFromPath(link.path2).toLowerCase();
                final query = _searchQuery.toLowerCase();

                final matchesTitle =
                    title.contains(query) || bookTitle.contains(query);

                // אם לא מתאים לכותרת - מסתיר
                if (!matchesTitle) {
                  return const SizedBox.shrink();
                }
              }

              return _buildExpansionTile(link, index);
            },
          );
        },
      ),
    );
  }

  // פונקציה אסינכרונית לטעינת הקישורים
  Future<List<Link>> _loadLinksAsync(TextBookLoaded state) async {
    // יצירת מפתח ייחודי למצב הנוכחי (פשוט יותר)
    final stateKey = '${state.visibleIndices.join(',')}';

    // אם המצב לא השתנה, מחזיר את התוצאה הקודמת
    if (_lastStateKey == stateKey && _cachedLinks != null) {
      return _cachedLinks!;
    }

    // מחכה מעט כדי לתת לווידג'ט להיבנות
    await Future.delayed(const Duration(milliseconds: 10));

    // מחשב את הקישורים באמצעות אותה לוגיקה של הסרגל הצד
    final links = _getLinksForSelectedLine(state,
        showVisibleIfNoSelection: widget.showVisibleLinksIfNoSelection);

    // שומר במטמון
    _cachedLinks = links;
    _lastStateKey = stateKey;

    return links;
  }

  Widget _buildExpansionTile(Link link, int index) {
    final keyStr = '${link.path2}_${link.index2}';
    return ExpansionTile(
      key: PageStorageKey(keyStr),
      maintainState: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(
        link.heRef,
        style: TextStyle(
          fontSize: widget.fontSize * 0.75,
          fontWeight: FontWeight.w600,
          fontFamily: 'FrankRuhlCLM',
        ),
      ),
      subtitle: Text(
        utils.getTitleFromPath(link.path2),
        style: TextStyle(
          fontSize: widget.fontSize * 0.65,
          fontFamily: 'FrankRuhlCLM',
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      onExpansionChanged: (isExpanded) {
        // הקצאת future לפני setState
        _contentCache[keyStr] ??= link.content;
        setState(() {
          _expanded[keyStr] = isExpanded;
        });
      },
      children: [
        if (_expanded[keyStr] == true)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: FutureBuilder<String>(
              future: _contentCache[keyStr],
              builder: (context, snapshot) => _buildLinkContent(link, snapshot),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkContent(Link link, AsyncSnapshot<String> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (snapshot.hasError) {
      return Text(
        'שגיאה בטעינת התוכן: ${snapshot.error}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: widget.fontSize * 0.9,
        ),
      );
    }

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Text(
        'אין תוכן זמין',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: widget.fontSize * 0.9,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        widget.openBookCallback(
          TextBookTab(
            book: TextBook(
              title: utils.getTitleFromPath(link.path2),
            ),
            index: link.index2 - 1,
            openLeftPane: (Settings.getValue<bool>('key-pin-sidebar') ??
                    false) ||
                (Settings.getValue<bool>('key-default-sidebar-open') ?? false),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12.0),
        // הסרת המסגרת והרקע הצבעוני
        child: Text(
          utils.stripHtmlIfNeeded(snapshot.data!),
          style: TextStyle(
            fontSize: widget.fontSize * 0.75,
            height: 1.5,
            fontFamily: 'FrankRuhlCLM',
          ),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
