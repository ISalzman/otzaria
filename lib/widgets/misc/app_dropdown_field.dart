import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/inputs/app_input_tokens.dart';

import 'package:otzaria/widgets/misc/app_popup_menu.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AppSelectionField — שדה-בחירה (trigger לתפריט נפתח)
//
// עיצוב: זהה לשורת הטריגר של DropdownMenu עם חיפוש
// • ללא גבול במצב רגיל
// • גבול עדין בעת hover
// ═══════════════════════════════════════════════════════════════════════════

const double _dropdownFieldRadius = AppInputTokens.compactRadius;
const double _dropdownFieldIdleFillAlpha = AppInputTokens.unfocusedAlpha;
const double _dropdownFieldDisabledFillAlpha = AppInputTokens.disabledAlpha;
const double _dropdownFieldHoverFillAlpha = 0.10;
const double _dropdownFieldBorderWidth = 1.4;
const double _dropdownFieldMinHeight = 40.0;
const EdgeInsets _dropdownFieldContentPadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 5);

Color _dropdownFieldBorderColor(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return theme.brightness == Brightness.light
      ? cs.primary.withValues(alpha: 0.22)
      : cs.primary.withValues(alpha: 0.40);
}

class AppSelectionField extends StatefulWidget {
  final Widget child;
  final InputDecoration? decoration;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool isSelected;
  final FocusNode? focusNode;

  /// `null` = ברירת מחדל (40px/20px), `true` = compact (36px/20px), `false` = רגיל (48px/28px)
  final bool? slim;

  const AppSelectionField({
    super.key,
    required this.child,
    this.decoration,
    this.enabled = true,
    this.onTap,
    this.leading,
    this.isSelected = false,
    this.focusNode,
    this.slim,
  });

  @override
  State<AppSelectionField> createState() => _AppSelectionFieldState();
}

class _AppSelectionFieldState extends State<AppSelectionField> {
  bool _isHovering = false;
  bool _isFocused = false;

  static const Duration _animDuration = Duration(milliseconds: 120);

  double get _effectiveRadius =>
      widget.slim == false ? 28.0 : _dropdownFieldRadius;

  double get _effectiveMinHeight {
    if (widget.slim == false) return 48.0;
    if (widget.slim == true) return 36.0;
    return _dropdownFieldMinHeight;
  }

  BoxDecoration _buildFieldDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = _effectiveRadius;

    if (_isFocused && widget.enabled) {
      return BoxDecoration(
        color: cs.onSurface.withValues(alpha: _dropdownFieldHoverFillAlpha),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: _dropdownFieldBorderColor(context),
          width: _dropdownFieldBorderWidth,
        ),
      );
    }
    if (_isHovering && widget.enabled) {
      return BoxDecoration(
        color: cs.onSurface.withValues(alpha: _dropdownFieldHoverFillAlpha),
        borderRadius: BorderRadius.circular(r),
      );
    }
    return BoxDecoration(
      color: cs.onSurface.withValues(
        alpha: widget.enabled
            ? _dropdownFieldIdleFillAlpha
            : _dropdownFieldDisabledFillAlpha,
      ),
      borderRadius: BorderRadius.circular(r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding =
        widget.decoration?.contentPadding ?? _dropdownFieldContentPadding;

    final content = Padding(
      padding: contentPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 8),
          ],
          Flexible(child: widget.child),
          // ללא חץ — המראה הוויזואלי של הכרטיס מספיק כ-affordance
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: _animDuration,
        curve: Curves.easeOut,
        decoration: _buildFieldDecoration(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            focusNode: widget.focusNode,
            canRequestFocus: widget.enabled,
            onFocusChange: (isFocused) {
              if (_isFocused != isFocused) {
                setState(() => _isFocused = isFocused);
              }
            },
            borderRadius: BorderRadius.circular(_effectiveRadius),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: _effectiveMinHeight),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AppDropdownField — שדה בחירה עם תפריט נפתח
//
// • enableSearch: false → AppSelectionField + popup menu
// • enableSearch: true  → DropdownMenu עם חיפוש + auto-select בפתיחה
//   ההבדל היחיד: האם ניתן להקליד ולסנן
// ═══════════════════════════════════════════════════════════════════════════

class AppDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final InputDecoration? decoration;
  final bool enabled;
  final bool isExpanded;
  final bool enableSearch;
  final Widget Function(BuildContext context, T? value)? selectedBuilder;
  final String Function(T value)? labelBuilder;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.decoration,
    this.enabled = true,
    this.isExpanded = true,
    this.enableSearch = false,
    this.selectedBuilder,
    this.labelBuilder,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final GlobalKey _selectionAnchorKey = GlobalKey();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final MenuController _menuController;
  String _menuVisibleText = '';
  bool _isSyncingControllerText = false;
  bool _restoreTextAfterNavigation = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _selectedLabel);
    _controller.addListener(_handleControllerChanged);
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
    _menuController = MenuController();
    _menuVisibleText = _controller.text;
  }

  @override
  void didUpdateWidget(covariant AppDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.entries != widget.entries) {
      _setControllerText(_selectedLabel);
      _menuVisibleText = _selectedLabel;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_isSyncingControllerText) return;

    if (widget.enableSearch &&
        _restoreTextAfterNavigation &&
        _menuController.isOpen) {
      _restoreTextAfterNavigation = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_menuController.isOpen) return;
        _setControllerText(
          _menuVisibleText,
          selection: TextSelection.collapsed(offset: _menuVisibleText.length),
        );
      });
      return;
    }

    _menuVisibleText = _controller.text;
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      // בחירת כל הטקסט אוטומטית בפתיחה — סעיף 6
      Future.microtask(() {
        if (mounted && _focusNode.hasFocus) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
          _menuVisibleText = _controller.text;
        }
      });
      return;
    }
    if (_controller.text != _selectedLabel) {
      _restoreSelectedText();
    }
  }

  void _restoreSelectedText() {
    final selectedLabel = _selectedLabel;
    _setControllerText(selectedLabel);
    _menuVisibleText = selectedLabel;
  }

  void _setControllerText(
    String text, {
    TextSelection? selection,
  }) {
    _isSyncingControllerText = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: selection ?? TextSelection.collapsed(offset: text.length),
    );
    _isSyncingControllerText = false;
  }

  String get _selectedLabel {
    if (widget.value == null) return '';
    for (final entry in widget.entries) {
      if (entry.value == widget.value) return entry.label;
    }
    if (widget.labelBuilder != null) {
      return widget.labelBuilder!(widget.value as T);
    }
    return '';
  }

  AppMenuEntry<T>? get _selectedEntry {
    if (widget.value == null) return null;
    for (final entry in widget.entries) {
      if (entry.value == widget.value) return entry;
    }
    return null;
  }

  Future<void> _openSelectionMenu() async {
    if (!widget.enabled ||
        widget.onSelected == null ||
        widget.entries.isEmpty) {
      return;
    }
    final anchorContext = _selectionAnchorKey.currentContext;
    if (anchorContext == null) return;

    final selected = await showAnchoredAppMenu<T>(
      context: context,
      anchorContext: anchorContext,
      itemsBuilder: (metrics) => widget.entries
          .map<PopupMenuEntry<T>>(
            (entry) => buildAppPopupMenuItem<T>(
              context,
              entry,
              metrics,
              widget.value,
            ),
          )
          .toList(),
    );

    if (!mounted) return;

    _focusNode.requestFocus();
    if (selected != null) {
      widget.onSelected?.call(selected);
    }
  }

  void _openSearchMenu() {
    if (!_menuController.isOpen) {
      _menuVisibleText = _controller.text;
      _menuController.open();
    }
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  KeyEventResult _handleSearchFieldKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isActivateKey = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;

    if (!_menuController.isOpen &&
        (key == LogicalKeyboardKey.space || isActivateKey)) {
      _openSearchMenu();
      return KeyEventResult.handled;
    }

    if (_menuController.isOpen &&
        (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp)) {
      _menuVisibleText = _controller.text;
      _restoreTextAfterNavigation = true;
      return KeyEventResult.ignored;
    }

    if (_menuController.isOpen && key == LogicalKeyboardKey.escape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _menuController.isOpen) return;
        _restoreSelectedText();
        _focusNode.requestFocus();
      });
    }

    return KeyEventResult.ignored;
  }

  InputDecorationTheme _buildDecorationTheme(
    BuildContext context,
    AppMenuMetrics metrics,
  ) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = _dropdownFieldBorderColor(context);
    final isCompact = metrics.compactMenus;
    final r = AppInputTokens.radius(isCompact);
    final minH = AppInputTokens.height(isCompact);

    return InputDecorationTheme(
      filled: true,
      fillColor: cs.onSurface.withValues(
        alpha: widget.enabled
            ? AppInputTokens.unfocusedAlpha
            : AppInputTokens.disabledAlpha,
      ),
      isDense: true,
      contentPadding: _dropdownFieldContentPadding,
      constraints: BoxConstraints(minHeight: minH),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide(
          color: borderColor,
          width: _dropdownFieldBorderWidth,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: metrics.fontSize,
      ),
    );
  }

  InputDecoration _buildSearchFieldDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFocus = _focusNode.hasFocus;

    // קבלת metrics כדי לדעת אם compact
    final metrics = Theme.of(context).extension<AppMenuMetrics>() ??
        AppMenuMetrics.create(compactMenus: false);
    final isCompact = metrics.compactMenus;

    // גובה, פונט ורדיוס תלויים ב-compact mode - משתמשים ב-AppInputTokens
    final fieldHeight = AppInputTokens.height(isCompact);
    final fieldFontSize = AppInputTokens.fontSize(isCompact);
    final fieldRadius = AppInputTokens.radius(isCompact);
    final iconSize = AppInputTokens.iconSize(isCompact);
    final minWidth = AppInputTokens.prefixMinWidth(isCompact);

    return InputDecoration(
      hintText: widget.decoration?.hintText ?? widget.decoration?.labelText,
      hintStyle: TextStyle(
        fontSize: fieldFontSize,
        color: cs.onSurfaceVariant,
        height: 1.0,
      ),
      filled: true,
      isDense: true,
      fillColor: hasFocus
          ? cs.primary.withValues(alpha: AppInputTokens.focusedAlpha)
          : cs.onSurface.withValues(alpha: AppInputTokens.unfocusedAlpha),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceXS, vertical: 0),
      constraints: BoxConstraints(minHeight: fieldHeight),
      prefixIcon: Icon(
        FluentIcons.search_24_regular,
        size: iconSize,
        color: hasFocus ? cs.primary : cs.onSurfaceVariant,
      ),
      prefixIconConstraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: fieldHeight,
      ),
      suffixIcon: const SizedBox.shrink(),
      suffixIconConstraints: BoxConstraints(
        minWidth: AppInputTokens.suffixMinWidth(isCompact),
        minHeight: fieldHeight,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<AppMenuMetrics>() ??
        AppMenuMetrics.create(compactMenus: false);
    final isCompact = metrics.compactMenus;
    final effectiveEnabled = widget.enabled &&
        widget.onSelected != null &&
        widget.entries.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final width = widget.isExpanded ? double.infinity : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width == double.infinity && constraints.hasBoundedWidth
                ? constraints.maxWidth
                : width;

        // ── מצב ללא חיפוש: AppSelectionField + popup ──────────────────────
        if (!widget.enableSearch) {
          final selectedEntry = _selectedEntry;
          final displayText =
              widget.selectedBuilder?.call(context, widget.value) ??
                  Text(
                    _selectedLabel,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: metrics.fontSize,
                      fontWeight: metrics.itemFontWeight,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  );

          final fieldContent = selectedEntry?.icon == null
              ? displayText
              : Row(
                  children: [
                    Icon(
                      selectedEntry!.icon,
                      size: metrics.iconSize,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: displayText),
                  ],
                );

          return SizedBox(
            width: resolvedWidth,
            child: KeyedSubtree(
              key: _selectionAnchorKey,
              child: AppSelectionField(
                enabled: effectiveEnabled,
                focusNode: _focusNode,
                onTap: _openSelectionMenu,
                decoration: widget.decoration,
                isSelected: widget.value != null,
                slim: isCompact ? true : false,
                child: SizedBox(
                  width: double.infinity,
                  child: fieldContent,
                ),
              ),
            ),
          );
        }

        // ── מצב עם חיפוש: DropdownMenu ────────────────────────────────────
        return SizedBox(
          width: resolvedWidth,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: _handleSearchFieldKeyEvent,
            child: DropdownMenu<T>(
              controller: _controller,
              focusNode: _focusNode,
              menuController: _menuController,
              enabled: effectiveEnabled,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap:
                  true, // auto-select בפתיחה (דרך _handleFocusChanged)
              initialSelection: widget.value,
              menuHeight:
                  (metrics.itemHeight * 8) + metrics.menuPadding.vertical,
              width: resolvedWidth,
              showTrailingIcon: false,
              textStyle: TextStyle(
                fontFamily: 'Roboto',
                fontSize: AppInputTokens.fontSize(metrics.compactMenus),
                fontWeight: metrics.itemFontWeight,
                color: cs.onSurface,
                height: 1.0,
              ),
              inputDecorationTheme: _buildDecorationTheme(context, metrics),
              decorationBuilder: (context, _) =>
                  _buildSearchFieldDecoration(context),
              leadingIcon: null,
              trailingIcon: null,
              selectedTrailingIcon: null,
              dropdownMenuEntries: widget.entries.map((entry) {
                final isSelected = entry.value == widget.value;
                return DropdownMenuEntry<T>(
                  value: entry.value,
                  label: entry.label,
                  labelWidget: buildAppMenuRowContent(
                    context,
                    metrics,
                    label: entry.label,
                    icon: entry.icon,
                    trailing: entry.trailing,
                    isSelected: isSelected,
                    isDestructive: entry.isDestructive,
                    enabled: entry.enabled,
                  ),
                  enabled: entry.enabled,
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    minimumSize: WidgetStatePropertyAll(
                      Size(metrics.menuMinWidth, metrics.itemHeight),
                    ),
                    shape: const WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                  ),
                );
              }).toList(),
              onSelected: (value) {
                if (value == null) {
                  _restoreSelectedText();
                  return;
                }
                final selectedEntry = widget.entries
                    .where((entry) => entry.value == value)
                    .firstOrNull;
                _menuVisibleText = selectedEntry?.label ?? _selectedLabel;
                widget.onSelected?.call(value);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _focusNode.requestFocus();
                });
              },
            ),
          ),
        );
      },
    );
  }
}
