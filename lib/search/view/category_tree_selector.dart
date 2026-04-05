import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/search/utils/search_catalogue_order_helper.dart';
import 'package:otzaria/widgets/custom_ui_components.dart';

/// וידג'ט לבחירת קטגוריות לחיפוש עם עץ היררכי מתקפל
/// מאפשר בחירת קטגוריות ותת-קטגוריות לפני ביצוע חיפוש
class CategoryTreeSelector extends StatefulWidget {
  /// הקטגוריות שנבחרו - רשימת נתיבים (facets)
  final Set<String> selectedFacets;

  /// קריאה חוזרת כשהבחירה משתנה
  final ValueChanged<Set<String>> onSelectionChanged;

  const CategoryTreeSelector({
    super.key,
    required this.selectedFacets,
    required this.onSelectionChanged,
  });

  @override
  State<CategoryTreeSelector> createState() => _CategoryTreeSelectorState();
}

class _CategoryTreeSelectorState extends State<CategoryTreeSelector> {
  final Map<String, bool> _expansionState = {};

  // מאוחסן בבנייה כדי להיות זמין בפונקציות ה-toggle
  Library? _library;

  bool get _isAllSelected => widget.selectedFacets.contains('/');

  // --- לוגיקת בחירה ---

  void _toggleAll(bool select) {
    if (select) {
      widget.onSelectionChanged({'/'}); // הכל נבחר
    } else {
      widget.onSelectionChanged({}); // שום דבר לא נבחר
    }
  }

  void _toggleCategory(Category category, bool select) {
    if (_library == null) return;
    final newSelection = Set<String>.from(widget.selectedFacets);

    if (select) {
      // בחירה: הסר הורים שמכסים אותה, הסר ילדים כפולים, הוסף
      newSelection.remove('/');
      for (final facet in newSelection.toList()) {
        if (category.path.startsWith('$facet/')) {
          newSelection.remove(facet);
        }
      }
      _removeDescendants(category, newSelection);
      newSelection.add(category.path);
      // דחיסה: אם כל אחי הקטגוריה נבחרו - אחד להורה
      widget.onSelectionChanged(_consolidate(newSelection, _library!));
    } else {
      // ביטול בחירה:
      if (newSelection.contains(category.path)) {
        // נבחרה ישירות - פשוט הסר
        newSelection.remove(category.path);
      } else {
        // מכוסה ע"י הורה (כולל "/") - "פוצץ" את ההורה
        _explodeExcluding(category, newSelection, _library!);
      }
      widget.onSelectionChanged(newSelection);
    }
  }

  /// דחיסת הבחירה - אם כל ילדי הורה נבחרו, אחד אותם להורה (רקורסיבי עד שורש)
  Set<String> _consolidate(Set<String> selection, Library library) {
    if (selection.contains('/')) return selection;
    final result = Set<String>.from(selection);
    final allCovered = library.subCategories.isNotEmpty &&
        library.subCategories.every((cat) => _doConsolidate(cat, result));
    if (allCovered) {
      result.clear();
      result.add('/');
    }
    return result;
  }

  /// מנסה לדחוס קטגוריה ומחזיר true אם היא מכוסה לחלוטין
  bool _doConsolidate(Category category, Set<String> selection) {
    if (selection.contains(category.path)) return true;
    for (final facet in selection) {
      if (category.path.startsWith('$facet/')) return true;
    }
    if (category.subCategories.isEmpty) return false;
    final allChildrenCovered =
        category.subCategories.every((c) => _doConsolidate(c, selection));
    if (allChildrenCovered) {
      for (final child in category.subCategories) {
        selection.remove(child.path);
        _removeAllDescendants(child, selection);
      }
      selection.add(category.path);
      return true;
    }
    return false;
  }

  void _removeAllDescendants(Category category, Set<String> selection) {
    for (final sub in category.subCategories) {
      selection.remove(sub.path);
      _removeAllDescendants(sub, selection);
    }
  }

  /// "פיצוץ" הורה: הסר את ה-facet המכסה והוסף את כל האחים,
  /// תוך ירידה רקורסיבית לאורך הנתיב לקטגוריה המובלטת.
  ///
  /// [excluded] - הקטגוריה שרוצים לבטל
  /// [selection] - הבחירה הנוכחית (תשתנה in-place)
  /// [parent] - ה-Category הנוכחית שמעובדת (מתחיל מ-Library)
  void _explodeExcluding(
    Category excluded,
    Set<String> selection,
    Category parent,
  ) {
    // מצא את ה-facet המכסה ברמה הנוכחית
    final coveringFacet = parent is Library ? '/' : parent.path;

    // הסר את ה-facet המכסה
    selection.remove(coveringFacet);

    // עבור על כל ילדי ההורה
    for (final child in parent.subCategories) {
      if (child.path == excluded.path) {
        // זה הילד שרוצים להוציא - דלג עליו
        continue;
      }
      if (excluded.path.startsWith('${child.path}/')) {
        // ילד זה הוא עצמו הורה של excluded - רדת רקורסיבית
        _explodeExcluding(excluded, selection, child);
      } else {
        // ילד רגיל - הוסף אותו
        selection.add(child.path);
      }
    }
  }

  /// הסר את כל הצאצאים של קטגוריה מהבחירה
  void _removeDescendants(Category category, Set<String> selection) {
    for (final sub in category.subCategories) {
      selection.remove(sub.path);
      _removeDescendants(sub, selection);
    }
  }

  // --- לוגיקת תצוגת מצב ---

  /// מחזיר true/false/null (tristate) לצ'קבוקס
  bool? _getCategoryCheckState(Category category) {
    // "/" נבחר = הכל מסומן
    if (_isAllSelected) return true;

    // נבחרה ישירות
    if (widget.selectedFacets.contains(category.path)) return true;

    // הורה נבחר = מסומן
    for (final facet in widget.selectedFacets) {
      if (facet != '/' && category.path.startsWith('$facet/')) return true;
    }

    // יש צאצא שנבחר = חלקי
    if (_hasSelectedDescendant(category)) return null;

    return false;
  }

  bool _hasSelectedDescendant(Category category) {
    for (final facet in widget.selectedFacets) {
      if (facet.startsWith('${category.path}/')) return true;
    }
    return false;
  }

  // --- בנייה ---

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, libraryState) {
        if (libraryState.library == null) {
          return const SizedBox.shrink();
        }

        _library = libraryState.library!;
        final topCategories = _library!.subCategories.toList()
          ..sort((a, b) => SearchCatalogueOrderHelper.topCategoryOrder(a)
              .compareTo(SearchCatalogueOrderHelper.topCategoryOrder(b)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 4),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final category in topCategories)
                          _buildCategoryNode(context, category, 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hasSelection = widget.selectedFacets.isNotEmpty && !_isAllSelected;

    return Row(
      children: [
        Icon(
          FluentIcons.library_24_regular,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'חיפוש בקטגוריות',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
          textDirection: TextDirection.rtl,
        ),
        const Spacer(),
        if (hasSelection)
          SizedBox(
            height: 30,
            child: NeutralActionButton(
              text: 'איפוס',
              icon: FluentIcons.arrow_reset_24_regular,
              onPressed: () => _toggleAll(true),
            ),
          ),
        Checkbox(
          value: _isAllSelected
              ? true
              : widget.selectedFacets.isEmpty
                  ? false
                  : null,
          tristate: true,
          onChanged: (value) => _toggleAll(value == true),
        ),
        Text(
          'הכל',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _buildCategoryNode(
    BuildContext context,
    Category category,
    int level,
  ) {
    final hasChildren = category.subCategories.isNotEmpty;
    final isExpanded = _expansionState[category.path] ?? false;
    final checkState = _getCategoryCheckState(category);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(
            right: 8.0 + (level * 20.0),
            left: 8.0,
            top: 4.0,
            bottom: 4.0,
          ),
          child: Row(
            children: [
              // צ'קבוקס - תמיד פעיל
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: checkState,
                  tristate: true,
                  onChanged: (value) => _toggleCategory(
                    category,
                    // tristate: null → true → false → true
                    // כשהמצב הנוכחי true/null → ביטול; false → בחירה
                    checkState != false ? false : true,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // אייקון תיקייה (לחיץ להרחבה)
              InkWell(
                onTap: hasChildren
                    ? () => setState(() {
                          _expansionState[category.path] = !isExpanded;
                        })
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  hasChildren
                      ? (isExpanded
                          ? FluentIcons.folder_open_24_regular
                          : FluentIcons.folder_24_regular)
                      : FluentIcons.folder_24_regular,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              // שם הקטגוריה (לחיץ להרחבה)
              Expanded(
                child: InkWell(
                  onTap: hasChildren
                      ? () => setState(() {
                            _expansionState[category.path] = !isExpanded;
                          })
                      : null,
                  child: Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          level == 0 ? FontWeight.w600 : FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // חץ הרחבה
              if (hasChildren)
                InkWell(
                  onTap: () => setState(() {
                    _expansionState[category.path] = !isExpanded;
                  }),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      isExpanded
                          ? FluentIcons.chevron_up_24_regular
                          : FluentIcons.chevron_down_24_regular,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // ילדים
        if (isExpanded && hasChildren)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildSortedChildren(context, category, level + 1),
          ),
      ],
    );
  }

  List<Widget> _buildSortedChildren(
    BuildContext context,
    Category category,
    int level,
  ) {
    final sorted = category.subCategories.toList()
      ..sort((a, b) => SearchCatalogueOrderHelper.normalizeOrder(a.order)
          .compareTo(SearchCatalogueOrderHelper.normalizeOrder(b.order)));

    return [
      for (final sub in sorted) _buildCategoryNode(context, sub, level),
    ];
  }
}
