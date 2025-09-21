import 'package:flutter/material.dart';

/// Badge widget that indicates a section has been edited
class EditedSectionBadge extends StatelessWidget {
  final String bookId;
  final String sectionId;
  final VoidCallback onEdit;
  final VoidCallback onCompare;
  final VoidCallback onReset;

  const EditedSectionBadge({
    super.key,
    required this.bookId,
    required this.sectionId,
    required this.onEdit,
    required this.onCompare,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOptionsMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: 12,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              'נערך',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('ערוך שוב'),
            onTap: () {
              Navigator.of(context).pop();
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.compare_arrows),
            title: const Text('השווה למקור'),
            onTap: () {
              Navigator.of(context).pop();
              onCompare();
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('איפוס למקור'),
            onTap: () {
              Navigator.of(context).pop();
              _showResetConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('איפוס למקור'),
        content: const Text(
          'האם אתה בטוח שברצונך לאפס את הפסקה למקור?\n'
          'פעולה זו תמחק את כל השינויים שביצעת.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReset();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('איפוס'),
          ),
        ],
      ),
    );
  }
}