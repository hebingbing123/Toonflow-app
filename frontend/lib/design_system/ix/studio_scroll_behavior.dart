import 'package:flutter/material.dart';

import 'studio_pointer.dart';

/// Product-wide scroll behavior: visible draggable thumbs on tablet/desktop.
class StudioScrollBehavior extends MaterialScrollBehavior {
  const StudioScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (!studioScrollbarThumbVisible(context)) {
      return child;
    }
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      interactive: true,
      child: child,
    );
  }
}

/// Wraps an existing scroll view with a visible [Scrollbar] when appropriate.
class StudioScrollbar extends StatelessWidget {
  const StudioScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
  });

  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) {
    final visible = thumbVisibility ?? studioScrollbarThumbVisible(context);
    if (!visible) return child;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      interactive: true,
      child: child,
    );
  }
}
