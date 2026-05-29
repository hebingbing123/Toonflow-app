import 'package:flutter/material.dart';

/// Isolates repaint for animated subtrees (spinners, toasts, tray indicators).
class StudioRepaintBoundary extends StatelessWidget {
  const StudioRepaintBoundary({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}
