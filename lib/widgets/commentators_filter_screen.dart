import 'package:flutter/material.dart';

import 'package:otzaria/widgets/commentators_filter_header.dart';

class CommentatorsFilterScreen extends StatelessWidget {
  final VoidCallback onBack;
  final Widget child;
  final String title;
  final Color? backgroundColor;

  const CommentatorsFilterScreen({
    super.key,
    required this.onBack,
    required this.child,
    this.title = 'בחירת מפרשים',
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommentatorsFilterHeader(
            onBack: onBack,
            title: title,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
