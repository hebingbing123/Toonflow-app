import 'package:flutter/widgets.dart';

import '../shell/navigation_controller.dart';

/// Product-shell pane history shared across [HomePage] route instances.
///
/// Without this, `go('/projects/…')` mounts a new [HomePage] with a fresh
/// [ShellNavigationController], so title-bar ←/→ history from the shell home
/// route is lost.
class StudioShellNavigationScope extends InheritedNotifier<ShellNavigationController> {
  const StudioShellNavigationScope({
    super.key,
    required ShellNavigationController navigation,
    required super.child,
  }) : super(notifier: navigation);

  static ShellNavigationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StudioShellNavigationScope>()
        ?.notifier;
  }
}
