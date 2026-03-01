import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class IndexingWarning extends StatelessWidget {
  final VoidCallback? onDismiss;

  const IndexingWarning({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.warning_24_regular, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'אינדקס החיפוש בתהליך עדכון. יתכן שחלק מהספרים לא יוצגו בתוצאות החיפוש.',
              textAlign: TextAlign.right,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(FluentIcons.dismiss_24_regular),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
