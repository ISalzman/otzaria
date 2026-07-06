import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/search/saved_alternatives_store.dart';
import 'package:otzaria/search/search_defaults.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

/// ווידג'ט לניהול אפשרויות חיפוש מתקדמות לכל מילה בנפרד.
class AdvancedSearchControls extends StatefulWidget {
  final SearchingTab tab;
  final bool compactMode;
  final VoidCallback? onEmptySubmit;
  final ValueNotifier<bool>? inputFocusNotifier;

  const AdvancedSearchControls({
    super.key,
    required this.tab,
    this.compactMode = false,
    this.onEmptySubmit,
    this.inputFocusNotifier,
  });

  @override
  State<AdvancedSearchControls> createState() => _AdvancedSearchControlsState();
}

class _AdvancedSearchControlsState extends State<AdvancedSearchControls> {
  final TextEditingController _alternativeWordController =
      TextEditingController();
  final Map<String, TextEditingController> _spacingControllers = {};
  final Map<String, FocusNode> _spacingFocusNodes = {};
  final FocusNode _alternativeWordFocusNode = FocusNode();
  final List<String> _currentAlternatives = [];

  String? _currentWord;
  int? _wordIndex;
  List<String> _words = [];

  @override
  void initState() {
    super.initState();
    widget.tab.queryController.addListener(_onQueryChanged);
    widget.tab.searchFieldFocusNode.addListener(_onFocusChanged);
    widget.tab.useGlobalSearchOptions.addListener(_onGlobalModeChanged);
    _alternativeWordFocusNode.addListener(_updateInputFocusState);
    _analyzeCurrentWord();
  }

  @override
  void dispose() {
    widget.tab.queryController.removeListener(_onQueryChanged);
    widget.tab.searchFieldFocusNode.removeListener(_onFocusChanged);
    widget.tab.useGlobalSearchOptions.removeListener(_onGlobalModeChanged);
    _alternativeWordFocusNode.removeListener(_updateInputFocusState);
    _alternativeWordController.dispose();
    _alternativeWordFocusNode.dispose();
    for (final controller in _spacingControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _spacingFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onGlobalModeChanged() {
    if (mounted) setState(() {});
  }

  void _onQueryChanged() {
    if (mounted) _analyzeCurrentWord();
  }

  void _onFocusChanged() {
    if (mounted) _analyzeCurrentWord();
  }

  void _updateInputFocusState() {
    if (widget.inputFocusNotifier == null) return;
    final hasSpacingFocus =
        _spacingFocusNodes.values.any((node) => node.hasFocus);
    widget.inputFocusNotifier!.value =
        _alternativeWordFocusNode.hasFocus || hasSpacingFocus;
  }

  void _analyzeCurrentWord() {
    final text = widget.tab.queryController.text;
    final selection = widget.tab.queryController.selection;

    if (text.isEmpty || selection.baseOffset < 0) {
      if (_currentWord != null) {
        setState(() {
          _currentWord = null;
          _wordIndex = null;
          _currentAlternatives.clear();
        });
      }
      return;
    }

    // משתמשים באותה פיצול כמו מנוע החיפוש (`splitQueryWords`),
    // כך שמפתחות `${_currentWord}_$_wordIndex` ואינדקסי `alternativeWords` /
    // `spacingValues` שנשמרים פר-מילה יתאימו לחיפוש בפועל.
    // ללא יישור זה, שאילתות כמו `רמב"ם` מצרות מפתחות שאינם נקראים.
    _words = SearchQueryBuilder.splitQueryWords(text);

    // המיפוי מהסמן למילה — דרך queryWordSpans, שמאתר כל מילת-מנוע
    // בטקסט הגולמי (כולל ׳/״ עבריים בשדה ומקטעים משני-אורך כמו
    // `רמב''ם`, שמקבלים את גבולות המקטע כולו).
    int? foundIndex;
    String? foundWord;

    for (final span in SearchQueryBuilder.queryWordSpans(text)) {
      if (selection.baseOffset >= span.start &&
          selection.baseOffset <= span.end) {
        foundIndex = span.index;
        foundWord = span.word;
        break;
      }
    }

    if (foundIndex != _wordIndex || foundWord != _currentWord) {
      setState(() {
        _wordIndex = foundIndex;
        _currentWord = foundWord;
        _updateLocalStateForWord(foundIndex);
      });
    }
  }

  void _updateLocalStateForWord(int? index) {
    if (index == null) {
      _currentAlternatives.clear();
      return;
    }

    _currentAlternatives.clear();
    final alts = widget.tab.alternativeWords[index];
    if (alts != null) {
      _currentAlternatives.addAll(alts);
    }
    // כשהמתג דלוק — החלופות השמורות של המילה מוצגות ברשימה כרגילות
    if (widget.tab.useSavedAlternatives && index < _words.length) {
      final word = _words[index];
      for (final alt in SavedAlternativesStore.alternativesFor(word)) {
        if (alt != word && !_currentAlternatives.contains(alt)) {
          _currentAlternatives.add(alt);
        }
      }
    }

    final wordsCount = _words.where((w) => w.isNotEmpty).length;
    if (index < wordsCount - 1) {
      final key = '$index-${index + 1}';
      final spacing = widget.tab.spacingValues[key] ?? '';
      _getSpacingController(index, index + 1).text = spacing;
    }
  }

  TextEditingController _getSpacingController(int leftIndex, int rightIndex) {
    final key = '$leftIndex-$rightIndex';
    return _spacingControllers.putIfAbsent(key, () => TextEditingController());
  }

  FocusNode _getSpacingFocusNode(int leftIndex, int rightIndex) {
    final key = '$leftIndex-$rightIndex';
    return _spacingFocusNodes.putIfAbsent(key, () {
      final node = FocusNode();
      node.addListener(_updateInputFocusState);
      return node;
    });
  }

  void _navigateToWord(int newIndex) {
    if (newIndex < 0 || newIndex >= _words.length) return;

    // queryWordSpans מחזיר טווח לכל מילת-מנוע בטקסט הגולמי; מילה
    // שאינה ניתנת לאיתור מדויק (נורמליזציה משנת-אורך) מקבלת את גבולות
    // המקטע שלה — הצבת הסמן באמצע הטווח נכונה בשני המקרים.
    final spans = SearchQueryBuilder.queryWordSpans(
      widget.tab.queryController.text,
    );
    if (newIndex >= spans.length) return;
    final span = spans[newIndex];
    widget.tab.queryController.selection = TextSelection.collapsed(
      offset: span.start + (span.end - span.start) ~/ 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWordSelected = _currentWord != null && _wordIndex != null;
    final useGlobal = widget.tab.useGlobalSearchOptions.value;
    // הצ'קבוקסים פעילים אם במצב גלובלי או אם נבחרה מילה
    final checkboxesEnabled = useGlobal || isWordSelected;
    // ההגדרות הפר-מיליות (מילים חילופיות + מרווח) תמיד פר-מילה
    final perWordInputsEnabled = isWordSelected;

    if (!checkboxesEnabled && !widget.compactMode) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                FluentIcons.cursor_click_24_regular,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'לחץ על מילה בשדה החיפוש כדי להגדיר אפשרויות מתקדמות',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // המתגים ממוקמים לצד שורת הניווט; ברוחב צר יורדים לשורה נפרדת
    final navigationWithToggle = LayoutBuilder(
      builder: (context, constraints) {
        final toggles = Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _buildSavedAlternativesToggle(),
            _buildScopeToggle(),
          ],
        );
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavigationRow(perWordInputsEnabled),
              const SizedBox(height: 4),
              toggles,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildNavigationRow(perWordInputsEnabled)),
            toggles,
          ],
        );
      },
    );

    if (widget.compactMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          navigationWithToggle,
          if (perWordInputsEnabled) ...[
            const SizedBox(height: 16),
            _buildInputColumn(perWordInputsEnabled),
          ],
          const SizedBox(height: 16),
          _buildCheckboxGrid(checkboxesEnabled, compactMode: true),
          _buildSaveDefaultsRow(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              navigationWithToggle,
              const SizedBox(height: 16),
              _buildInputColumn(perWordInputsEnabled),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCheckboxGrid(checkboxesEnabled, compactMode: false),
              _buildSaveDefaultsRow(),
            ],
          ),
        ),
      ],
    );
  }

  /// מתג הרחבת החיפוש בחלופות השמורות — כבוי בכל חיפוש חדש.
  Widget _buildSavedAlternativesToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = widget.tab.useSavedAlternatives;

    return Tooltip(
      message: enabled
          ? 'החיפוש יורחב במילים החילופיות שנשמרו עבור מילות השאילתה'
          : 'הפעל כדי להרחיב את החיפוש במילים החילופיות שנשמרו',
      child: Container(
        decoration: BoxDecoration(
          color: AppSurfaces.togglePill(colorScheme, active: enabled),
          borderRadius: AppTokens.borderRadiusAll,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'חלופות שמורות',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: enabled,
                onChanged: (value) {
                  setState(() {
                    widget.tab.useSavedAlternatives = value;
                    _updateLocalStateForWord(_wordIndex);
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// תפריט נפתח לסימון אילו אפשרויות מופעלות כברירת מחדל בחיפוש חדש,
  /// ולצדו לחצן שמאפס את האפשרויות הנוכחיות לברירת המחדל השמורה.
  Widget _buildSaveDefaultsRow() {
    final defaults = SearchDefaults.loadDefaults();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 4,
        children: [
          MenuAnchor(
            menuChildren: [
              for (final key in SearchQueryBuilder.availableWordOptionKeys)
                CheckboxMenuButton(
                  value: defaults[key] ?? false,
                  closeOnActivate: false,
                  onChanged: (checked) {
                    setState(() {
                      SearchDefaults.saveDefaults(
                          {...defaults, key: checked ?? false});
                      // שינוי ברירת מחדל מוחל מיד גם על הריבוע בחלונית הפתוחה
                      widget.tab.globalSearchOptions[key] = checked ?? false;
                    });
                    widget.tab.searchOptionsChanged.value++;
                  },
                  child: Text(key),
                ),
            ],
            builder: (context, controller, _) => Tooltip(
              message: 'סמן אילו אפשרויות יופעלו אוטומטית בכל חיפוש חדש',
              child: ActionButton.ghost(
                text: 'ברירת מחדל לחיפוש חדש',
                icon: FluentIcons.options_24_regular,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          ),
          Tooltip(
            message: 'החזרת האפשרויות המסומנות למצב ברירת המחדל השמורה',
            child: ActionButton.ghost(
              text: 'חזרה לברירת מחדל',
              icon: FluentIcons.arrow_reset_24_regular,
              onPressed: () {
                setState(() {
                  widget.tab.globalSearchOptions
                    ..clear()
                    ..addAll(SearchDefaults.loadDefaults());
                  widget.tab.searchOptions.clear();
                });
                widget.tab.searchOptionsChanged.value++;
              },
            ),
          ),
        ],
      ),
    );
  }

  /// מתג קומפקטי לבחירת היקף ההגדרות: גלובלי לכל המילים או פר-מילה.
  Widget _buildScopeToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final useGlobal = widget.tab.useGlobalSearchOptions.value;

    return Tooltip(
      message: useGlobal
          ? 'ההגדרות חלות על כל המילים בשאילתה ולא משתנות בעת שינוי המילים'
          : 'ההגדרות נשמרות לכל מילה בנפרד',
      child: Container(
        decoration: BoxDecoration(
          color: AppSurfaces.togglePill(colorScheme, active: useGlobal),
          borderRadius: AppTokens.borderRadiusAll,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'זהה לכל המילים',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: useGlobal
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: useGlobal,
                onChanged: (value) {
                  widget.tab.useGlobalSearchOptions.value = value;
                  widget.tab.searchOptionsChanged.value++;
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow(bool isEnabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: isEnabled && _wordIndex! > 0
              ? () => _navigateToWord(_wordIndex! - 1)
              : null,
          tooltip: 'מילה קודמת',
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isEnabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppTokens.borderRadiusAll,
            ),
            child: Text(
              isEnabled ? _currentWord! : 'בחר מילה',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isEnabled
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(FluentIcons.chevron_right_24_regular),
          onPressed: isEnabled && _wordIndex! < _words.length - 1
              ? () => _navigateToWord(_wordIndex! + 1)
              : null,
          tooltip: 'מילה הבאה',
        ),
      ],
    );
  }

  Widget _buildInputColumn(bool isEnabled) {
    final spacingController = _wordIndex != null
        ? _getSpacingController(_wordIndex!, _wordIndex! + 1)
        : null;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Opacity(
                opacity: isEnabled ? 1.0 : 0.5,
                child: RtlTextField(
                  enabled: isEnabled,
                  controller: spacingController,
                  focusNode: isEnabled && _wordIndex != null
                      ? _getSpacingFocusNode(_wordIndex!, _wordIndex! + 1)
                      : null,
                  decoration: InputDecoration(
                    labelText: 'מרווח למילה הבאה',
                    hintText: '0-30',
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: IconButton(
                      icon:
                          const Icon(FluentIcons.dismiss_24_regular, size: 20),
                      onPressed: isEnabled && _wordIndex != null
                          ? () {
                              final key = '${_wordIndex!}-${_wordIndex! + 1}';
                              widget.tab.spacingValues.remove(key);
                              widget.tab.spacingValuesChanged.value++;
                              _getSpacingController(
                                      _wordIndex!, _wordIndex! + 1)
                                  .clear();
                            }
                          : null,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^([0-9]|[12][0-9]|30)$'),
                    ),
                  ],
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  onChanged: (text) {
                    if (isEnabled &&
                        _wordIndex != null &&
                        text.trim().isNotEmpty) {
                      final key = '${_wordIndex!}-${_wordIndex! + 1}';
                      widget.tab.spacingValues[key] = text.trim();
                      widget.tab.spacingValuesChanged.value++;
                    }
                  },
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty && _wordIndex != null) {
                      final key = '${_wordIndex!}-${_wordIndex! + 1}';
                      widget.tab.spacingValues[key] = text.trim();
                      widget.tab.spacingValuesChanged.value++;
                      widget.onEmptySubmit?.call();
                    } else {
                      widget.onEmptySubmit?.call();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RtlTextField(
                controller: _alternativeWordController,
                focusNode: _alternativeWordFocusNode,
                enabled: isEnabled,
                decoration: InputDecoration(
                  labelText: 'מילה חילופית',
                  hintText: 'הקלד מילה...',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  prefixIcon: IconButton(
                    icon: const Icon(FluentIcons.add_24_regular, size: 20),
                    onPressed: isEnabled ? _addAlternative : null,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.right,
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _addAlternative();
                  } else {
                    widget.onEmptySubmit?.call();
                  }
                },
              ),
            ),
          ],
        ),
        if (_currentAlternatives.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildAlternativeWordsList(),
        ]
      ],
    );
  }

  Widget _buildAlternativeWordsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: AppTokens.borderRadiusAll,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _currentAlternatives.length,
        itemBuilder: (context, index) {
          return ListTile(
            dense: true,
            title: Text(
              _currentAlternatives[index],
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
            trailing: IconButton(
              icon: const Icon(FluentIcons.delete_24_regular, size: 18),
              onPressed: () => _removeAlternative(index),
            ),
          );
        },
      ),
    );
  }

  void _addAlternative() {
    final text = _alternativeWordController.text.trim();
    if (text.isEmpty || _wordIndex == null) return;

    setState(() {
      if (!_currentAlternatives.contains(text)) {
        _currentAlternatives.add(text);
      }
    });

    widget.tab.alternativeWords.putIfAbsent(_wordIndex!, () => []);
    if (!widget.tab.alternativeWords[_wordIndex!]!.contains(text)) {
      widget.tab.alternativeWords[_wordIndex!]!.add(text);
    }
    widget.tab.alternativeWordsChanged.value++;
    // כל חלופה שנוספת נשמרת גם במאגר הגלובלי עבור המילה הנוכחית
    SavedAlternativesStore.addAlternative(_currentWord!, text);
    _alternativeWordController.clear();
  }

  void _removeAlternative(int index) {
    if (_wordIndex == null) return;
    final word = _currentAlternatives[index];

    setState(() {
      _currentAlternatives.removeAt(index);
    });

    widget.tab.alternativeWords[_wordIndex!]?.remove(word);
    if (widget.tab.alternativeWords[_wordIndex!]?.isEmpty ?? false) {
      widget.tab.alternativeWords.remove(_wordIndex!);
    }
    widget.tab.alternativeWordsChanged.value++;
    // הסרה מוחקת את החלופה גם מהמאגר הגלובלי של המילה הנוכחית
    if (_currentWord != null) {
      SavedAlternativesStore.removeAlternative(_currentWord!, word);
    }
  }

  Widget _buildCheckboxGrid(bool isEnabled, {required bool compactMode}) {
    const options = SearchQueryBuilder.availableWordOptionKeys;

    final useGlobal = widget.tab.useGlobalSearchOptions.value;

    Widget buildCheckbox(String option) {
      final colorScheme = Theme.of(context).colorScheme;
      bool isChecked = false;
      if (isEnabled) {
        if (useGlobal) {
          isChecked = widget.tab.globalSearchOptions[option] ?? false;
        } else {
          final key = '${_currentWord}_$_wordIndex';
          isChecked = widget.tab.searchOptions[key]?[option] ?? false;
        }
      }

      return Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: InkWell(
          onTap: isEnabled
              ? () {
                  setState(() {
                    if (useGlobal) {
                      widget.tab.globalSearchOptions[option] = !isChecked;
                    } else {
                      final key = '${_currentWord}_$_wordIndex';
                      widget.tab.searchOptions.putIfAbsent(key, () => {});
                      widget.tab.searchOptions[key]![option] = !isChecked;
                    }
                  });
                  widget.tab.searchOptionsChanged.value++;
                }
              : null,
          borderRadius: AppTokens.borderRadiusAll,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IgnorePointer(
                    child: Checkbox(
                      value: isChecked,
                      onChanged: isEnabled ? (_) {} : null,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: colorScheme.outline),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!compactMode) {
      return Wrap(
        spacing: 16,
        runSpacing: 8,
        children: options
            .map((option) => SizedBox(width: 180, child: buildCheckbox(option)))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = constraints.maxWidth < 600;

        if (useSingleColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: options.map(buildCheckbox).toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: buildCheckbox(options[0])),
                const SizedBox(width: 8),
                Expanded(child: buildCheckbox(options[1])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildCheckbox(options[2])),
                const SizedBox(width: 8),
                Expanded(child: buildCheckbox(options[3])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildCheckbox(options[4])),
                const SizedBox(width: 8),
                Expanded(child: buildCheckbox(options[5])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildCheckbox(options[6])),
              ],
            ),
          ],
        );
      },
    );
  }
}
