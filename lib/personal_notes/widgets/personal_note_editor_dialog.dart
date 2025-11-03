import 'package:flutter/material.dart';

class PersonalNoteEditorDialog extends StatelessWidget {
  final TextEditingController controller;
  final String title;

  PersonalNoteEditorDialog({
    super.key,
    TextEditingController? controller,
    this.title = 'הערה חדשה',
  }) : controller = controller ?? TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 12,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'כתבו כאן את ההערה האישית',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) {
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: const Text('שמור'),
        ),
      ],
    );
  }
}
