import 'package:flutter/material.dart';

import '../design_system/ix/studio_mobile_affordances.dart';
import '../design_system/tokens.dart';
import 'shell_back_handler_stub.dart'
    if (dart.library.html) 'shell_back_handler_web.dart';

/// Whether Android-web shell overrides (scroll, theme, popstate) are active.
///
/// Defaults to [StudioMobileAffordances.supportsAndroidWebBack]. Pass
/// [enableOverrides] in tests to exercise the enabled code path.
@visibleForTesting
bool androidWebShellOverridesEnabled({bool? enableOverrides}) =>
    enableOverrides ?? StudioMobileAffordances.supportsAndroidWebBack;

/// Clamping scroll behavior for Android web (suppresses overscroll glow).
class AndroidWebClampingScrollBehaviour extends ScrollBehavior {
  const AndroidWebClampingScrollBehaviour();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

/// Wraps [child] with clamping scroll physics on Android web only.
Widget wrapAndroidWebScrollBehaviour(
  Widget child, {
  bool? enableOverrides,
}) {
  if (!androidWebShellOverridesEnabled(enableOverrides: enableOverrides)) {
    return child;
  }
  return ScrollConfiguration(
    behavior: const AndroidWebClampingScrollBehaviour(),
    child: child,
  );
}

/// Wraps [child] with ripple/highlight overrides on Android web only.
Widget wrapAndroidWebTheme(
  BuildContext context,
  Widget child, {
  bool? enableOverrides,
}) {
  if (!androidWebShellOverridesEnabled(enableOverrides: enableOverrides)) {
    return child;
  }
  return Theme(
    data: Theme.of(context).copyWith(
      splashFactory: InkRipple.splashFactory,
      highlightColor: StudioPrimitives.transparent,
    ),
    child: child,
  );
}

/// Whether the product shell should install a browser `popstate` listener.
bool get shouldInstallAndroidWebPopStateListener =>
    StudioMobileAffordances.supportsAndroidWebBack;

/// Installs the popstate listener when [shouldInstallAndroidWebPopStateListener].
///
/// Returns `null` when overrides are inactive (including the Flutter test env).
Object? installAndroidWebPopStateListenerIfNeeded(BuildContext context) {
  if (!shouldInstallAndroidWebPopStateListener) {
    return null;
  }
  return installPopStateListener(context);
}

/// Removes a subscription from [installAndroidWebPopStateListenerIfNeeded].
///
/// Safe to call with `null` (no-op via stub on native).
void removeAndroidWebPopStateListener(Object? subscription) {
  removePopStateListener(subscription);
}
