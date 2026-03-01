import 'package:flutter/material.dart';

/// Widget that displays an indicator showing whether a book's data comes from
/// the database (DB), from a file (ק), or is a personal book (א).
class DataSourceIndicator extends StatelessWidget {
  final String source; // 'DB', 'ק', or 'א'
  final double size;

  const DataSourceIndicator({
    super.key,
    required this.source,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDb = source == 'DB';
    final isPersonal = source == 'א';

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    String tooltip;

    if (isPersonal) {
      backgroundColor = colorScheme.tertiaryContainer;
      borderColor = colorScheme.tertiary;
      textColor = colorScheme.onTertiaryContainer;
      tooltip = 'ספר אישי - לא יועבר למסד נתונים';
    } else if (isDb) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      textColor = colorScheme.onPrimaryContainer;
      tooltip = 'ספר זה נשמר במסד הנתונים';
    } else {
      backgroundColor = colorScheme.secondaryContainer;
      borderColor = colorScheme.secondary;
      textColor = colorScheme.onSecondaryContainer;
      tooltip = 'ספר זה נשמר כקובץ';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            source,
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// FutureBuilder wrapper for DataSourceIndicator that fetches the source asynchronously
class DataSourceIndicatorAsync extends StatelessWidget {
  final Future<String> sourceFuture;
  final double size;

  const DataSourceIndicatorAsync({
    super.key,
    required this.sourceFuture,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: sourceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.6,
                height: size * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox(width: size, height: size);
        }

        return DataSourceIndicator(
          source: snapshot.data!,
          size: size,
        );
      },
    );
  }
}
