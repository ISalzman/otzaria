import 'package:flutter/material.dart';
import '../services/overrides_rebase_service.dart';

/// Dialog for resolving rebase conflicts
class ConflictResolutionDialog extends StatefulWidget {
  final RebaseContext context;
  final Function(String resolution) onResolve;

  const ConflictResolutionDialog({
    Key? key,
    required this.context,
    required this.onResolve,
  }) : super(key: key);

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  String _selectedResolution = 'keep_override';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('קונפליקט בעריכה'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'הטקסט המקורי השתנה מאז שערכת אותו. בחר כיצד לפתור את הקונפליקט:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Resolution options
            RadioListTile<String>(
              title: const Text('שמור את העריכה שלי'),
              subtitle: const Text('התעלם מהשינויים במקור'),
              value: 'keep_override',
              groupValue: _selectedResolution,
              onChanged: (value) =>
                  setState(() => _selectedResolution = value!),
            ),
            RadioListTile<String>(
              title: const Text('השתמש בגרסה החדשה'),
              subtitle: const Text('בטל את העריכה שלי'),
              value: 'use_new_source',
              groupValue: _selectedResolution,
              onChanged: (value) =>
                  setState(() => _selectedResolution = value!),
            ),
            RadioListTile<String>(
              title: const Text('שמור בנפרד'),
              subtitle: const Text('שמור את העריכה שלי כגרסה נפרדת'),
              value: 'save_separate',
              groupValue: _selectedResolution,
              onChanged: (value) =>
                  setState(() => _selectedResolution = value!),
            ),

            const SizedBox(height: 16),

            // Three-way diff preview
            Expanded(
              child: Row(
                children: [
                  // Original
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'מקור ישן',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.context.originalContent,
                                style: const TextStyle(fontSize: 12),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Edited
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'העריכה שלי',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.context.overrideContent,
                                style: const TextStyle(fontSize: 12),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  // New source
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'מקור חדש',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.context.newSourceContent,
                                style: const TextStyle(fontSize: 12),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onResolve(_selectedResolution);
            Navigator.of(context).pop();
          },
          child: const Text('פתור קונפליקט'),
        ),
      ],
    );
  }
}

/// Shows a conflict resolution dialog
Future<String?> showConflictResolutionDialog({
  required BuildContext context,
  required RebaseContext rebaseContext,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictResolutionDialog(
      context: rebaseContext,
      onResolve: (resolution) => Navigator.of(context).pop(resolution),
    ),
  );
}
