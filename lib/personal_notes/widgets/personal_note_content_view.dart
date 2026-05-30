import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:otzaria/personal_notes/models/personal_note.dart';

/// מציגה את תוכן ההערה האישית — כולל עיצוב (Quill Delta) אם קיים.
///
/// ה-widget מנהל בעצמו את מחזור החיים של ה-[quill.QuillController],
/// ה-[FocusNode] וה-[ScrollController]: הם נוצרים פעם אחת ב-[initState],
/// נבנים מחדש רק כשתוכן ההערה משתנה, ומשוחררים ב-[dispose]. זה קריטי כאשר
/// ה-widget מוצג ברשימה/רשת של הערות — אחרת כל בנייה הייתה יוצרת controllers
/// חדשים ללא שחרור (דליפת משאבים ו-jank בגלילה).
class PersonalNoteContentView extends StatefulWidget {
  final PersonalNote note;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final bool allowSelection;
  final void Function(String url)? onLinkTap;

  const PersonalNoteContentView({
    super.key,
    required this.note,
    this.textStyle,
    this.textAlign = TextAlign.justify,
    this.allowSelection = true,
    this.onLinkTap,
  });

  @override
  State<PersonalNoteContentView> createState() =>
      _PersonalNoteContentViewState();
}

class _PersonalNoteContentViewState extends State<PersonalNoteContentView> {
  quill.QuillController? _controller;
  FocusNode? _focusNode;
  ScrollController? _scrollController;
  List<({String label, String url})> _links = const [];

  @override
  void initState() {
    super.initState();
    _buildContent();
  }

  @override
  void didUpdateWidget(PersonalNoteContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.content != widget.note.content ||
        oldWidget.note.contentFormat != widget.note.contentFormat) {
      _disposeControllers();
      _buildContent();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  /// מפרסר את תוכן ההערה פעם אחת ובונה את ה-controllers (אם זה Quill Delta).
  /// ה-jsonDecode נעשה פעם אחת ומשמש גם לבניית המסמך וגם לחילוץ הקישורים.
  void _buildContent() {
    final note = widget.note;
    if (note.contentFormat != PersonalNoteContentFormat.quillDelta) {
      _links = const [];
      return;
    }

    List<dynamic>? decoded;
    try {
      decoded = jsonDecode(note.content) as List<dynamic>;
    } catch (_) {
      decoded = null;
    }

    final document = decoded != null
        ? quill.Document.fromJson(decoded)
        : (quill.Document()..insert(0, note.content));

    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    )..readOnly = true;
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _links = decoded != null ? _extractLinks(decoded) : const [];
  }

  void _disposeControllers() {
    _controller?.dispose();
    _focusNode?.dispose();
    _scrollController?.dispose();
    _controller = null;
    _focusNode = null;
    _scrollController = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      final editor = quill.QuillEditor(
        controller: controller,
        focusNode: _focusNode!,
        scrollController: _scrollController!,
        config: const quill.QuillEditorConfig(
          autoFocus: false,
          expands: false,
          padding: EdgeInsets.zero,
          showCursor: false,
          scrollable: false,
        ),
      );

      return Directionality(
        textDirection: TextDirection.rtl,
        child: DefaultTextStyle(
          style: widget.textStyle ?? Theme.of(context).textTheme.bodyMedium!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              editor,
              if (_links.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildLinks(context, _links),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.note.contentPlain,
          style: widget.textStyle,
          textAlign: widget.textAlign,
          textDirection: TextDirection.rtl,
        ),
        if (_links.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildLinks(context, _links),
        ],
      ],
    );
  }

  List<({String label, String url})> _extractLinks(List<dynamic> decoded) {
    final links = <({String label, String url})>[];
    for (final op in decoded) {
      if (op is! Map<String, dynamic>) continue;
      final attributes = op['attributes'];
      final insert = op['insert'];
      if (attributes is Map<String, dynamic> &&
          attributes['link'] is String &&
          insert is String) {
        links.add((label: insert.trim(), url: attributes['link'] as String));
      }
    }
    return links;
  }

  Widget _buildLinks(
      BuildContext context, List<({String label, String url})> links) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links.map((link) {
        final label = link.label.isNotEmpty ? link.label : link.url;
        return ActionChip(
          label: Text(label, overflow: TextOverflow.ellipsis),
          onPressed: widget.onLinkTap == null
              ? null
              : () => widget.onLinkTap!(link.url),
        );
      }).toList(),
    );
  }
}
