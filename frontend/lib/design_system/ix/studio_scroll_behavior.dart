import 'package:flutter/material.dart';

import '../tokens.dart';
import 'studio_pointer.dart';

/// Thin, rounded scroll thumbs — overlay until hover / scroll (macOS-like).
ScrollbarThemeData studioScrollbarTheme(StudioTokens tokens) {
  Color thumbColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.dragged)) {
      return tokens.textSecondary.withValues(alpha: 0.52);
    }
    if (states.contains(WidgetState.hovered)) {
      return tokens.textSecondary.withValues(alpha: 0.38);
    }
    return tokens.textSecondary.withValues(alpha: 0.24);
  }

  double thumbThickness(Set<WidgetState> states) {
    if (states.contains(WidgetState.dragged)) {
      return 4.5;
    }
    if (states.contains(WidgetState.hovered)) {
      return 4;
    }
    return 3;
  }

  return ScrollbarThemeData(
    thickness: WidgetStateProperty.resolveWith(thumbThickness),
    radius: const Radius.circular(999),
    thumbColor: WidgetStateProperty.resolveWith(thumbColor),
    trackColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    trackBorderColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    crossAxisMargin: 2,
    mainAxisMargin: 3,
    minThumbLength: 28,
    interactive: true,
  );
}

ScrollNotificationPredicate studioDefaultScrollNotificationPredicate =
    defaultScrollNotificationPredicate;

/// Prevents [MaterialApp.scrollBehavior] from adding a second thumb.
class _StudioExplicitScrollbarBehavior extends MaterialScrollBehavior {
  const _StudioExplicitScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Shared [Scrollbar] configured from [ThemeData.scrollbarTheme].
Widget buildStudioScrollbar({
  required BuildContext context,
  required Widget child,
  ScrollController? controller,
  bool? thumbVisibility,
  ScrollNotificationPredicate? notificationPredicate,
}) {
  final theme = Theme.of(context).scrollbarTheme;
  return Scrollbar(
    controller: controller,
    thumbVisibility: thumbVisibility ?? false,
    interactive: theme.interactive ?? true,
    notificationPredicate:
        notificationPredicate ?? studioDefaultScrollNotificationPredicate,
    child: child,
  );
}

/// Product-wide scroll behavior: overlay scroll thumbs on tablet/desktop.
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
    return buildStudioScrollbar(
      context: context,
      controller: details.controller,
      child: child,
    );
  }
}

/// Wraps an existing scroll view with a studio [Scrollbar] when appropriate.
class StudioScrollbar extends StatelessWidget {
  const StudioScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.notificationPredicate,
    this.forceVisible,
  });

  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;
  final ScrollNotificationPredicate? notificationPredicate;

  /// When false, never wraps with [Scrollbar] (handset / touch-first layouts).
  final bool? forceVisible;

  @override
  Widget build(BuildContext context) {
    final visible = forceVisible ?? studioScrollbarThumbVisible(context);
    if (!visible) return child;
    return buildStudioScrollbar(
      context: context,
      controller: controller,
      thumbVisibility: thumbVisibility,
      notificationPredicate: notificationPredicate,
      child: ScrollConfiguration(
        behavior: const _StudioExplicitScrollbarBehavior(),
        child: child,
      ),
    );
  }
}
