import 'package:flutter/material.dart';
import 'package:otzaria/widgets/feedback/otzaria_empty_state.dart';

/// מצב ריק סטנדרטי למסכי כלים — תאימות לאחור מעל [OtzariaEmptyState].
class ToolEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const ToolEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return OtzariaEmptyState(
      icon: icon,
      title: message,
      message: subtitle,
    );
  }
}
