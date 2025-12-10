import 'package:flutter/material.dart';
import 'package:otzaria/text_book/view/tzurat_hadaf/utils/tzurat_hadaf_settings_manager.dart';

class TzuratHadafDialog extends StatefulWidget {
  final List<String> availableCommentators;
  final String bookTitle;

  const TzuratHadafDialog({
    super.key,
    required this.availableCommentators,
    required this.bookTitle,
  });

  @override
  State<TzuratHadafDialog> createState() => _TzuratHadafDialogState();
}

class _TzuratHadafDialogState extends State<TzuratHadafDialog> {
  String? _leftCommentator;
  String? _rightCommentator;
  String? _bottomCommentator;
  String? _bottomRightCommentator;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  void _loadConfiguration() {
    final config =
        TzuratHadafSettingsManager.loadConfiguration(widget.bookTitle);
    if (config != null) {
      setState(() {
        _leftCommentator = config['left'];
        _rightCommentator = config['right'];
        _bottomCommentator = config['bottom'];
        _bottomRightCommentator = config['bottomRight'];
      });
    }
  }

  void _saveConfiguration() {
    final config = {
      'left': _leftCommentator,
      'right': _rightCommentator,
      'bottom': _bottomCommentator,
      'bottomRight': _bottomRightCommentator,
    };
    TzuratHadafSettingsManager.saveConfiguration(widget.bookTitle, config);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('הגדרת תצורת הדף'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCommentatorSelector('מפרש ימני', _leftCommentator, (value) {
              setState(() => _leftCommentator = value);
            }),
            _buildCommentatorSelector('מפרש שמאלי', _rightCommentator, (value) {
              setState(() => _rightCommentator = value);
            }),
            _buildCommentatorSelector('מפרש תחתון ימני', _bottomCommentator,
                (value) {
              setState(() => _bottomCommentator = value);
            }),
            _buildCommentatorSelector(
                'מפרש תחתון שמאלי', _bottomRightCommentator, (value) {
              setState(() => _bottomRightCommentator = value);
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: () {
            _saveConfiguration();
            Navigator.of(context).pop(true);
          },
          child: const Text('שמור'),
        ),
      ],
    );
  }

  Widget _buildCommentatorSelector(
    String label,
    String? currentValue,
    ValueChanged<String?> onChanged,
  ) {
    // Add "None" option to the list
    final items = [null, ...widget.availableCommentators];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        initialValue: currentValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items.map((String? commentator) {
          return DropdownMenuItem<String>(
            value: commentator,
            child: Text(commentator ?? 'ללא'),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
