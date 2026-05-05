import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/search/view/tantivy_search_results.dart';
import 'package:search_engine/search_engine.dart';
import 'package:toggle_switch/toggle_switch.dart';

class SearchModeToggle extends StatelessWidget {
  const SearchModeToggle({super.key, required this.tab});

  final SearchingTab tab;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        int currentIndex;
        switch (state.configuration.searchMode) {
          case SearchMode.advanced:
            currentIndex = 0;
            break;
          case SearchMode.exact:
            currentIndex = 1;
            break;
          case SearchMode.fuzzy:
            currentIndex = 2;
            break;
          case SearchMode.levenshtein:
            currentIndex = 0;
            break;
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ToggleSwitch(
            minWidth: 108,
            minHeight: 45,
            inactiveBgColor: Colors.grey,
            inactiveFgColor: Colors.white,
            initialLabelIndex: currentIndex,
            totalSwitches: 3,
            labels: const [
              'חיפוש מתקדם',
              'חיפוש מדוייק',
              'חיפוש מקורב',
            ],
            radiusStyle: true,
            onToggle: (index) {
              SearchMode newMode;
              switch (index) {
                case 0:
                  newMode = SearchMode.advanced;
                  break;
                case 1:
                  newMode = SearchMode.exact;
                  break;
                case 2:
                  newMode = SearchMode.fuzzy;
                  break;
                default:
                  newMode = SearchMode.advanced;
              }
              context.read<SearchBloc>().add(
                    SetSearchMode(
                      newMode,
                      typoToleranceEnabled:
                          newMode == SearchMode.advanced ? null : false,
                    ),
                  );
              final modeString = switch (newMode) {
                SearchMode.advanced => 'advanced',
                SearchMode.exact => 'exact',
                SearchMode.fuzzy => 'fuzzy',
                SearchMode.levenshtein => 'advanced',
              };
              Settings.setValue<String>('key-last-search-mode', modeString);
              if (newMode != SearchMode.advanced) {
                Settings.setValue<bool>(
                    'key-last-search-typo-tolerance', false);
              }
            },
          ),
        );
      },
    );
  }
}

class FuzzyDistance extends StatefulWidget {
  const FuzzyDistance({super.key, required this.tab});

  final SearchingTab tab;

  @override
  State<FuzzyDistance> createState() => _FuzzyDistanceState();
}

class _FuzzyDistanceState extends State<FuzzyDistance> {
  @override
  void initState() {
    super.initState();
    // מאזין לשינויים במרווחים המותאמים אישית
    widget.tab.spacingValuesChanged.addListener(_onSpacingChanged);
  }

  @override
  void dispose() {
    widget.tab.spacingValuesChanged.removeListener(_onSpacingChanged);
    super.dispose();
  }

  void _onSpacingChanged() {
    setState(() {
      // עדכון התצוגה כשמשתמש משנה מרווחים
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        // בדיקה אם יש מרווחים מותאמים אישית
        final hasCustomSpacing = widget.tab.spacingValues.isNotEmpty;
        final isLevenshtein = state.isTypoToleranceEnabled;
        final isEnabled = !state.fuzzy && !hasCustomSpacing && !isLevenshtein;

        return SizedBox(
          width: 140,
          child: SpinBox(
            enabled: isEnabled,
            decoration: InputDecoration(
              labelText: isLevenshtein
                  ? 'מרווח בין מילים (לא רלוונטי)'
                  : hasCustomSpacing
                      ? 'מרווח בין מילים (מושבת)'
                      : 'מרווח בין מילים',
              labelStyle: TextStyle(
                color: hasCustomSpacing ? Colors.grey : null,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
            ),
            min: 0,
            max: 30,
            value: state.distance.toDouble(),
            onChanged: isEnabled
                ? (value) => context.read<SearchBloc>().add(
                      UpdateDistance(value.toInt()),
                    )
                : null,
          ),
        );
      },
    );
  }
}

class SearchTermsDisplay extends StatefulWidget {
  const SearchTermsDisplay({super.key, required this.tab});

  final SearchingTab tab;

  @override
  State<SearchTermsDisplay> createState() => _SearchTermsDisplayState();
}

class _SearchTermsDisplayState extends State<SearchTermsDisplay> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _attachTabListeners(widget.tab);
  }

  void _attachTabListeners(SearchingTab tab) {
    tab.queryController.addListener(_onTextChanged);
    tab.searchOptionsChanged.addListener(_onSearchOptionsChanged);
    tab.alternativeWordsChanged.addListener(_onAlternativeWordsChanged);
  }

  void _detachTabListeners(SearchingTab tab) {
    tab.queryController.removeListener(_onTextChanged);
    tab.searchOptionsChanged.removeListener(_onSearchOptionsChanged);
    tab.alternativeWordsChanged.removeListener(_onAlternativeWordsChanged);
  }

  @override
  void didUpdateWidget(covariant SearchTermsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tab, widget.tab)) {
      _detachTabListeners(oldWidget.tab);
      _attachTabListeners(widget.tab);
    }
  }

  void _onSearchOptionsChanged() {
    // עדכון התצוגה כשמשתמש משנה אפשרויות
    setState(() {
      // זה יגרום לעדכון של התצוגה
    });
  }

  void _onAlternativeWordsChanged() {
    // עדכון התצוגה כשמשתמש משנה מילים חילופיות
    setState(() {
      // זה יגרום לעדכון של התצוגה
    });
  }

  double _calculateFormattedTextWidth(String text, BuildContext context) {
    if (text.trim().isEmpty) return 0.0;

    // יצירת TextSpan עם הטקסט המעוצב
    final spans = _buildFormattedTextSpans(text, context);

    // שימוש ב-TextPainter למדידת הרוחב האמיתי
    final textPainter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    );

    textPainter.layout(maxWidth: double.infinity);
    return textPainter.size.width;
  }

  // פונקציה להמרת מספרים לתת-כתב Unicode
  String _convertToSubscript(String number) {
    const Map<String, String> subscriptMap = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
    };

    return number.split('').map((char) => subscriptMap[char] ?? char).join();
  }

  List<TextSpan> _buildFormattedTextSpans(String text, BuildContext context) {
    if (text.trim().isEmpty) return [const TextSpan(text: '')];

    final words = text.trim().split(RegExp(r'\s+'));
    final List<TextSpan> spans = [];

    // מיפוי אפשרויות לקיצורים
    const Map<String, String> optionAbbreviations = {
      'קידומות': 'ק',
      'סיומות': 'ס',
      'קידומות דקדוקיות': 'קד',
      'סיומות דקדוקיות': 'סד',
      'כתיב מלא/חסר': 'מח',
      'חלק ממילה': 'ש',
    };

    // אפשרויות שמופיעות אחרי המילה (סיומות)
    const Set<String> suffixOptions = {'סיומות', 'סיומות דקדוקיות'};

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final wordKey = '${word}_$i';

      // בדיקה אם יש אפשרויות למילה הזו
      final wordOptions = widget.tab.searchOptions[wordKey];
      final selectedOptions = wordOptions?.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList() ??
          [];

      // בדיקה אם יש מילים חילופיות למילה הזו
      final alternativeWords = widget.tab.alternativeWords[i] ?? [];

      // הפרדה בין קידומות לסיומות
      final prefixes = selectedOptions
          .where((opt) => !suffixOptions.contains(opt))
          .map((opt) => optionAbbreviations[opt] ?? opt)
          .toList();

      final suffixes = selectedOptions
          .where((opt) => suffixOptions.contains(opt))
          .map((opt) => optionAbbreviations[opt] ?? opt)
          .toList();

      // הוספת קידומות לפני המילה
      if (prefixes.isNotEmpty) {
        spans.add(
          TextSpan(
            text: '(${prefixes.join(',')})',
            style: TextStyle(
              fontSize: 10, // גופן קטן יותר לקיצורים
              fontWeight: FontWeight.normal,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
        spans.add(const TextSpan(text: ' '));
      }

      // הוספת המילה המודגשת
      spans.add(
        TextSpan(
          text: word,
          style: const TextStyle(
            fontSize: 16, // גופן גדול יותר למילים
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );

      // הוספת מילים חילופיות אם יש
      if (alternativeWords.isNotEmpty) {
        for (final altWord in alternativeWords) {
          // הוספת "או" בצבע הסיומות
          spans.add(const TextSpan(text: ' '));
          spans.add(
            TextSpan(
              text: 'או',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).primaryColor,
              ),
            ),
          );
          spans.add(const TextSpan(text: ' '));

          // הוספת המילה החילופית המודגשת
          spans.add(
            TextSpan(
              text: altWord,
              style: const TextStyle(
                fontSize: 16, // גופן גדול יותר למילים
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          );
        }
      }

      // הוספת סיומות אחרי המילה (והמילים החילופיות)
      if (suffixes.isNotEmpty) {
        spans.add(const TextSpan(text: ' '));
        spans.add(
          TextSpan(
            text: '(${suffixes.join(',')})',
            style: TextStyle(
              fontSize: 10, // גופן קטן יותר לקיצורים
              fontWeight: FontWeight.normal,
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
      }

      // הוספת + בין המילים (לא אחרי המילה האחרונה)
      if (i < words.length - 1) {
        // בדיקה אם יש מרווח מוגדר בין המילים
        final spacingKey = '$i-${i + 1}';
        final spacingValue = widget.tab.spacingValues[spacingKey];

        if (spacingValue != null && spacingValue.isNotEmpty) {
          // הצגת + עם המרווח מתחת
          spans.add(const TextSpan(text: ' '));

          // הוספת + עם המספר כתת-כתב
          spans.add(
            const TextSpan(
              text: '+',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          );
          // הוספת המספר כתת-כתב עם Unicode subscript characters
          final subscriptValue = _convertToSubscript(spacingValue);
          spans.add(
            TextSpan(
              text: subscriptValue,
              style: TextStyle(
                fontSize: 14, // גופן מעט יותר גדול למספר המרווח
                fontWeight: FontWeight.normal,
                color: Theme.of(context).primaryColor,
              ),
            ),
          );

          spans.add(const TextSpan(text: ' '));
        } else {
          // + רגיל ללא מרווח
          spans.add(
            const TextSpan(
              text: ' + ',
              style: TextStyle(
                fontSize: 16, // גופן גדול יותר ל-+
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          );
        }
      }
    }

    return spans;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _detachTabListeners(widget.tab);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // עדכון התצוגה כשהטקסט משתנה
    });
  }

  String _getDisplayText(String originalQuery) {
    // כרגע נציג את הטקסט המקורי
    // בעתיד נוסיף לוגיקה להצגת החלופות
    // למשל: "מאימתי או מתי ו קורין או קוראין"
    return originalQuery;
  }

  Widget _buildFormattedText(String text, BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final spans = _buildFormattedTextSpans(text, context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        // נציג את הטקסט מה-state של החיפוש (לא מה-controller שמשתנה)
        final displayText = _getDisplayText(state.searchQuery);

        if (displayText.isEmpty) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double formattedTextWidth = _calculateFormattedTextWidth(
              displayText,
              context,
            );

            // תצוגה פשוטה ללא מסגרת - ללא width קבוע כדי לאפשר מרכוז
            return formattedTextWidth <= (constraints.maxWidth - 20)
                ? _buildFormattedText(displayText, context)
                : SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, _) {
                        // וידוא שה-ScrollController מחובר לפני הצגת Scrollbar
                        return Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 3.0,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: _buildFormattedText(displayText, context),
                          ),
                        );
                      },
                    ),
                  );
          },
        );
      },
    );
  }
}

class OrderOfResults extends StatelessWidget {
  const OrderOfResults({super.key, required this.widget});

  final TantivySearchResults widget;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        return SizedBox(
          width: 183,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: AppDropdownField<ResultsOrder>(
              value: state.sortBy,
              decoration: const InputDecoration(
                labelText: 'מיון',
                border: OutlineInputBorder(),
              ),
              entries: const [
                AppMenuEntry(
                  value: ResultsOrder.relevance,
                  label: 'לפי רלוונטיות',
                ),
                AppMenuEntry(
                  value: ResultsOrder.catalogue,
                  label: 'לפי סדר קטלוגי',
                ),
              ],
              onSelected: (value) {
                if (value != null) {
                  context.read<SearchBloc>().add(UpdateSortOrder(value));
                }
              },
            ),
          ),
        );
      },
    );
  }
}
