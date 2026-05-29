import 'package:flutter/material.dart';

/// Keeps keyboard focus inside modal surfaces (dialogs / sheets).
class StudioFocusTrap extends StatelessWidget {
  const StudioFocusTrap({
    super.key,
    required this.child,
    this.autofocus = true,
  });

  final Widget child;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: FocusScope(autofocus: autofocus, child: child),
    );
  }
}
