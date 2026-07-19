import 'package:flutter/material.dart';

/// מקטע תווית־וערך אחיד לדיאלוגי מידע.
class DetailsInfoSection extends StatelessWidget {
  const DetailsInfoSection({
    super.key,
    required this.title,
    required this.value,
    this.valueDirection,
  });

  /// התווית המודגשת שמופיעה לפני הערך.
  final String title;

  /// הערך המלא שניתן לבחירה ולהעתקה.
  final String value;

  /// כיוון הערך, כאשר הוא שונה מכיוון הממשק.
  final TextDirection? valueDirection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 14),
            textDirection: valueDirection,
          ),
        ],
      ),
    );
  }
}
