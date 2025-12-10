import 'package:flutter/material.dart';

/// Simple header widget with centered title
class SearchHeader extends StatelessWidget {
  final String title;
  final double titleFontSize;

  const SearchHeader({
    super.key,
    required this.title,
    this.titleFontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(128),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
