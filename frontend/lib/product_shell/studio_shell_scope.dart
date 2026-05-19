import 'package:flutter/widgets.dart';

class StudioShellScope extends InheritedWidget {
  const StudioShellScope({
    super.key,
    required super.child,
    this.onPopProductPane,
    this.onBackToProjectsHome,
  });

  /// Returns true when a previous product-shell pane was restored.
  final bool Function()? onPopProductPane;
  final VoidCallback? onBackToProjectsHome;

  static StudioShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StudioShellScope>();
  }

  @override
  bool updateShouldNotify(StudioShellScope oldWidget) {
    return oldWidget.onPopProductPane != onPopProductPane ||
        oldWidget.onBackToProjectsHome != onBackToProjectsHome;
  }
}
