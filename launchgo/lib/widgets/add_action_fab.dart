import 'package:flutter/material.dart';
import 'extended_fab.dart';

class AddActionFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String? tooltip;
  final IconData icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AddActionFab({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.icon = Icons.add,
    this.backgroundColor,
    this.foregroundColor,
  });

  // Factory constructors for common use cases
  factory AddActionFab.course({
    required VoidCallback onPressed,
  }) {
    return AddActionFab(
      onPressed: onPressed,
      tooltip: 'Add Task',
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  factory AddActionFab.document({
    required VoidCallback onPressed,
  }) {
    return AddActionFab(
      onPressed: onPressed,
      tooltip: 'New Document',
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  factory AddActionFab.event({
    required VoidCallback onPressed,
  }) {
    return AddActionFab(
      onPressed: onPressed,
      tooltip: 'New Event',
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  factory AddActionFab.assignment({
    required VoidCallback onPressed,
  }) {
    return AddActionFab(
      onPressed: onPressed,
      tooltip: 'Add Assignment',
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );
  }

  factory AddActionFab.custom({
    required VoidCallback onPressed,
    required String tooltip,
    IconData icon = Icons.add,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return AddActionFab(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
      backgroundColor: backgroundColor ?? Colors.blue,
      foregroundColor: foregroundColor ?? Colors.white,
    );
  }

  // Extended FAB factory for consistency with app patterns
  static Widget extended({
    required VoidCallback onPressed,
    required String label,
  }) {
    return ExtendedFAB(
      label: label,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor ?? Colors.blue,
      foregroundColor: foregroundColor ?? Colors.white,
      child: Icon(icon),
    );
  }
}