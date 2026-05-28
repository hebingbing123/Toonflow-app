// Web implementation of the popstate back-handler.
// This file is selected by the conditional import in build_product_shell.dart
// when dart:html IS available (i.e. Flutter web builds).
//
// Uses dart:html to listen to the browser's popstate event and delegates
// back-navigation to GoRouter when the router stack has a previous entry.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Installs a `popstate` listener on [html.window].
///
/// When the browser fires a `popstate` event (e.g. hardware back button on
/// Android web), the handler checks whether GoRouter can pop. If it can, it
/// calls [GoRouter.pop] and consumes the event. If it cannot, the default
/// browser back-navigation proceeds unmodified.
///
/// Returns the [html.EventListener] subscription object. Pass it to
/// [removePopStateListener] in `dispose` to avoid memory leaks.
Object? installPopStateListener(BuildContext context) {
  void handler(html.Event event) {
    // Guard against unmounted widgets (e.g. called after dispose).
    // BuildContext.mounted is available in Flutter 3.7+.
    if (!context.mounted) return;

    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    }
    // If canPop() is false, the default browser back-navigation proceeds.
  }

  html.window.addEventListener('popstate', handler);
  return handler;
}

/// Removes the `popstate` listener previously returned by
/// [installPopStateListener].
void removePopStateListener(Object? subscription) {
  if (subscription == null) return;
  html.window.removeEventListener('popstate', subscription as html.EventListener);
}
